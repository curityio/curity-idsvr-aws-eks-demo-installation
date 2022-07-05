#!/bin/bash
set -eo pipefail

display_help() {
    echo -e "Usage: $(basename "$0") [-h | --help] [-i | --install]  [-d | --delete]  \n" >&2
    echo "** DESCRIPTION **"
    echo -e "This script can be used to deploy a eks cluster, curity identity server, kong gateway and phantom token plugin. \n"
    echo -e "OPTIONS \n"
    echo " --help      show this help message and exit                                                                  "
    echo " --install   creates a private eks cluster & deploys curity identity server along with other components       "
    echo " --start     start up the environment                                                                         "
    echo " --stop      shuts down the environment                                                                       "
    echo " --delete    deletes the eks k8s cluster & identity server deployment                                         "
}


greeting_message() {
  echo "|----------------------------------------------------------------------------|"
  echo "|  AWS Kubernetes Engine based Curity Identity Server Installation           |"
  echo "|----------------------------------------------------------------------------|"
  echo "|  Following components are going to be installed :                          |"
  echo "|----------------------------------------------------------------------------|"
  echo "| [1] AWS EKS KUBERNETES CLUSTER                                             |"
  echo "| [2] CURITY IDENTITY SERVER ADMIN NODE                                      |"
  echo "| [3] CURITY IDENTITY SERVER RUNTIME NODE                                    |"
  echo "| [4] NGINX INGRESS CONTROLLER                                               |"
  echo "|----------------------------------------------------------------------------|" 
  echo -e "\n"
}


pre_requisites_check() {
  # Check if aws cli, kubectl, eksctl, helm & jq are installed
  if ! [[ $(aws --version) && $(helm version) && $(jq --version) && $(kubectl version) && $(eksctl version) ]]; then
      echo "Please install aws cli, kubectl, eksctl, helm & jq to continue with the deployment .."
      exit 1 
  fi

  # Check for license file
  if [ ! -f 'idsvr-config/license.json' ]; then
    echo "Please copy a license.json file in the idsvr-config directory to continue with the deployment. License could be downloaded from https://developer.curity.io/"
    exit 1
  fi

  # To avoid accidental commit of sensitive data to repositories
  cp ./hooks/pre-commit ./.git/hooks

  echo -e "\n"
}


read_cluster_config_file() {
  echo "Reading the configuration from cluster-config/eks-cluster-config.json .."
  while read -r NAME; read -r VALUE; do
    if [ -z "$NAME" ]; then break; fi

  export "$NAME"="$VALUE" 

  done <<< "$(jq -rc '.[] | .[] | "\(.Name)\n\(.Value)"' "cluster-config/eks-cluster-config.json")"
}


create_eks_cluster() {
  read -p "Do you want to create a new eks cluster for deploying Curity Identity server ? [Y/y N/n] :" -n 1 -r
  echo -e "\n"

  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    generate_self_signed_certificates
    envsubst < cluster-config/cluster-cfg.yaml.template > cluster-config/cluster-cfg.yaml
    eksctl create cluster -f cluster-config/cluster-cfg.yaml
  else
    echo "Not creating a new k8s cluster, assuming that an existing cluster is already available for deployment ..."
  fi
 
  echo -e "\n"
}


is_pki_already_available() {
  echo -e "Verifying whether the certificates are already available .."
  if [[ -f certs/example.eks.ssl.key && -f certs/example.eks.ssl.pem ]] ; then
    echo -e "example.eks.ssl.key & example.eks.ssl.pem certificates already exist.., skipping regeneration of certificates\n"
    true
  else
    echo -e "Generating example.eks.ssl.key,example.eks.ssl.pem certificates using local domain names from cluster-config/eks-cluster-config.json..\n"
    false
  fi
}


generate_self_signed_certificates() { 
  if ! is_pki_already_available ; then
      bash ./create-self-signed-certs.sh
    echo -e "\n"
  fi
}


import_certificate_to_aws_acm() {
  echo "Uploading self signed certs to aws certificate manager .."
  cert_arn=$(aws acm import-certificate --certificate fileb://certs/example.eks.ssl.pem --private-key fileb://certs/example.eks.ssl.key  --certificate-chain fileb://certs/example.eks.ca.pem | jq -r '.CertificateArn')
  export cert_arn=$cert_arn

  echo "Uploaded self-signed certificate to AWS, arn is : $cert_arn"
}


delete_acm_certificate(){
  aws_cert_arn=$(aws acm list-certificates --region "$region"| jq -r '.CertificateSummaryList[] | select(.DomainName=="*.example.eks") | .CertificateArn')
  
  for cert in $aws_cert_arn
  do
    echo "Deleting certificate $cert from the aws certificate manager .."
    aws acm delete-certificate --certificate-arn "$cert" --region "$region" || true
  done
    
}

deploy_ingress_controller() {
  import_certificate_to_aws_acm
  echo -e "Deploying Nginx ingress controller in the k8s cluster ...\n"
  # create secrets for TLS termination
  kubectl create secret tls example-eks-tls --cert=certs/example.eks.ssl.pem --key=certs/example.eks.ssl.key -n "$idsvr_namespace" || true
   
  envsubst < ingress-nginx-config/helm-values.yaml.template > ingress-nginx-config/helm-values.yaml

  # Deploy nginx ingress controller  
  helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --values ingress-nginx-config/helm-values.yaml \
    --namespace ingress-nginx --create-namespace
  echo -e "\n"
}


deploy_idsvr() {
  echo "Fetching Curity Idsvr helm chart ..."
  helm repo add curity https://curityio.github.io/idsvr-helm || true
  helm repo update

  envsubst < idsvr-config/helm-values.yaml.template > idsvr-config/helm-values.yaml

  echo -e "Deploying Curity Identity Server in the k8s cluster ...\n"
  helm install curity curity/idsvr --values idsvr-config/helm-values.yaml --namespace "${idsvr_namespace}" --create-namespace

  kubectl create secret generic idsvr-config --from-file=idsvr-config/idsvr-cluster-config.xml --from-file=idsvr-config/license.json -n "${idsvr_namespace}" || true

  # Copy the deployed artifacts to idsvr-config/template directory for reviewing 
  mkdir -p idsvr-config/templates
  helm template curity curity/idsvr --values idsvr-config/helm-values.yaml > idsvr-config/templates/deployed-idsvr-helm.yaml
  echo -e "\n"
}


get_load_balancer_public_ip() {
  ALL_LB_DATA=$(aws elb describe-load-balancers)
  LB_DNS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath="{.status.loadBalancer.ingress[0].hostname}") 
  LB_NAME=$(jq -r -n --argjson data "$ALL_LB_DATA" "\$data.LoadBalancerDescriptions[] | select(.DNSName==\"$LB_DNS\") | .LoadBalancerName")

  LB_IP=$(aws ec2 describe-network-interfaces --filters Name=description,Values="ELB $LB_NAME" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

}


startup_environment() {
  echo "Starting up the environment .."
  asg_name=$(aws autoscaling describe-auto-scaling-groups --filters Name=tag-key,Values="kubernetes.io/cluster/${cluster_name}" | jq -r '.AutoScalingGroups | .[] | .AutoScalingGroupName')

  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${asg_name}" \
    --min-size "${nodegroup_min_size}" \
    --desired-capacity "${nodegroup_desired_size}" \
    --max-size "${nodegroup_max_size}"
}


shutdown_environment() {
  echo "Shutting down the environment .."
  asg_name=$(aws autoscaling describe-auto-scaling-groups --filters Name=tag-key,Values="kubernetes.io/cluster/${cluster_name}" | jq -r '.AutoScalingGroups | .[] | .AutoScalingGroupName')
  
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${asg_name}" \
    --min-size 0 \
    --desired-capacity 0 \
    --max-size 0
}


tear_down_environment() {
  read -p "Identity server deployment and k8s cluster would be deleted, Are you sure? [Y/y N/n] :" -n 1 -r
  echo -e "\n"

  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    helm uninstall curity -n "${idsvr_namespace}" || true
    helm uninstall ingress-nginx -n ingress-nginx || true
    delete_acm_certificate

    eksctl delete cluster -f cluster-config/cluster-cfg.yaml
    echo -e "\n" 
  else
    echo "Aborting the operation .."
    exit 1
  fi
}



environment_info() {
  echo "Waiting for LoadBalancer's External IP, sleeping for 60 seconds ..."
  sleep 60
  
  get_load_balancer_public_ip

  if [ -z "$LB_IP" ]; then LB_IP="<LoadBalancer-IP>"; fi
  
  echo -e "\n"
  
  echo "|--------------------------------------------------------------------------------------------------------------------------------------------------|"
  echo "|                                Environment URLS & Endpoints                                                                                      |"
  echo "|--------------------------------------------------------------------------------------------------------------------------------------------------|"
  echo "|                                                                                                                                                  |"
  echo "| [ADMIN UI]        https://admin.example.eks/admin                                                                                                |"
  echo "| [OIDC METADATA]   https://login.example.eks/~/.well-known/openid-configuration                                                                   |"                                                                                                  
  echo "|                                                                                                                                                  |"
  echo "|                                                                                                                                                  |"
  echo "| * Curity administrator username is admin and password is $idsvr_admin_password                                                                    "
  echo "| * Remember to add certs/example.eks.ca.pem to operating system's certificate trust store &                                                       |"
  echo "|   $LB_IP  admin.example.eks login.example.eks kong-admin.example.eks api.example.eks entry to /etc/hosts                                          "
  echo "|--------------------------------------------------------------------------------------------------------------------------------------------------|" 
}



# ==========
# entrypoint
# ==========

case $1 in
  -i | --install)
    greeting_message
    pre_requisites_check
    read_cluster_config_file
    create_eks_cluster
    deploy_idsvr
    deploy_ingress_controller
    environment_info
    ;;
  -d | --delete)
    read_cluster_config_file
    tear_down_environment
    ;;
  --start)
    read_cluster_config_file
    startup_environment
    ;;
  --stop)
    read_cluster_config_file
    shutdown_environment
    ;;
  -h | --help)
    display_help
    ;;
  *)
    echo "[ERROR] Unsupported options"
    display_help
    exit 1
    ;;
esac