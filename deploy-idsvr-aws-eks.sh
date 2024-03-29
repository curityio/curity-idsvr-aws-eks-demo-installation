#!/bin/bash
set -eo pipefail

display_help() {
    echo -e "Usage: $(basename "$0") [-h | --help] [-i | --install]  [-d | --delete]  \n" >&2
    echo "** DESCRIPTION **"
    echo -e "This script can be used to deploy Curity Identity Server in AWS Elastic kubernetes cluster. \n"
    echo -e "OPTIONS \n"
    echo " --help                         shows this help message and exit                                                                 "
    echo " --install                      creates an EKS cluster & deploys Curity Identity Server along with other components               "
    echo " --start                        starts up the environment                                                                        "
    echo " --stop                         shuts down the environment                                                                       "
    echo " --load-balancer-public-ip      prints the public IP address of the load balancer                                                "
    echo " --delete                       deletes the EKS cluster & Identity Server deployment                                         "
}


greeting_message() {
  echo "|----------------------------------------------------------------------------|"
  echo "|  AWS Kubernetes Engine based Curity Identity Server Deployment             |"
  echo "|----------------------------------------------------------------------------|"
  echo "|  Following components are going to be deployed :                           |"
  echo "|----------------------------------------------------------------------------|"
  echo "| [1] AWS EKS KUBERNETES CLUSTER                                             |"
  echo "| [2] CURITY IDENTITY SERVER ADMIN NODE                                      |"
  echo "| [3] CURITY IDENTITY SERVER RUNTIME NODE                                    |"
  echo "| [4] NGINX INGRESS CONTROLLER                                               |"
  echo "| [5] NGINX PHANTOM TOKEN PLUGIN                                             |"
  echo "| [6] EXAMPLE NODEJS API                                                     |"
  echo "|----------------------------------------------------------------------------|" 
}


pre_requisites_check() {
  # Check if aws cli, kubectl, eksctl, helm & jq are installed
  if ! [[ $(aws --version) && $(helm version) && $(jq --version) && ($(eksctl version) || $(terraform version)) ]]; then
      echo "Please install aws cli, kubectl, helm, jq, eksctl and/or terraform to continue with the deployment .."
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


read_infra_config_file() {
  echo "Reading the configuration from infrastructure-config/infra-config.json .."
  while read -r NAME; read -r VALUE; do
    if [ -z "$NAME" ]; then break; fi

  export "$NAME"="$VALUE" 

  done <<< "$(jq -rc '.[] | .[] | "\(.Name)\n\(.Value)"' "infrastructure-config/infra-config.json")"
}


is_pki_already_available() {
  echo -e "Verifying whether the certificates are already available .."
  if [[ -f certs/example.eks.ssl.key && -f certs/example.eks.ssl.pem ]] ; then
    echo -e "example.eks.ssl.key & example.eks.ssl.pem certificates already exist.., skipping regeneration of certificates\n"
    true
  else
    echo -e "Generating example.eks.ssl.key,example.eks.ssl.pem certificates using local domain names from infrastructure-config/infra-config.json..\n"
    false
  fi
}


generate_self_signed_certificates() { 
  if ! is_pki_already_available ; then
      bash ./create-self-signed-certs.sh
    echo -e "\n"
  fi
}


fill_templates() {
  envsubst < terraform-config/main.auto.tfvars.template > terraform-config/main.auto.tfvars

  envsubst < idsvr-config/helm-values.yaml.template > idsvr-config/helm-values.yaml
  envsubst < ingress-nginx-config/helm-values.yaml.template > ingress-nginx-config/helm-values.yaml
}


determine_eks_cluster_creation_type() {
    echo -e "\n"
    echo "Choose one of the following options to proceed further :           "
    echo "|-----------------------------------------------------------------|"
    echo "| [1]  EKSCTL     => EKS cluster deployment using eksctl          |"
    echo "| [2]  TERRAFORM  => EKS cluster deployment using terraform       |"
    echo "| [3]  CANCEL                                                     |"
    echo "|-----------------------------------------------------------------|"

    read -rp "What type of deployment [1 or 2] ? : " choiceDeploy
    case "$choiceDeploy" in
      1 ) create_eks_cluster_using_eksctl  ;;
      2 ) create_eks_cluster_using_terraform ;;
      3 ) exit 1 ;;
      * ) echo "Invalid choice"  
          exit 1 ;;
    esac  
  echo -e "\n"

}


create_eks_cluster_using_eksctl() {
    if ! [ -x "$(command -v eksctl version)" ]; then
      echo "** You need to have eksctl cli installed to use that option **"
      determine_eks_cluster_creation_type
    fi
    generate_self_signed_certificates
    envsubst < eksctl-config/cluster-cfg.yaml.template > eksctl-config/cluster-cfg.yaml

    echo -e "Creating EKS cluster for deployment using eksctl..."
    eksctl create cluster -f eksctl-config/cluster-cfg.yaml
    
    echo -e "\n"
    deploy_idsvr
}


create_eks_cluster_using_terraform() {
    if ! [ -x "$(command -v terraform version)" ]; then
      echo "** You need to have terraform installed to use that option **"
      determine_eks_cluster_creation_type
    fi
    generate_self_signed_certificates
    echo -e "Creating EKS cluster for deployment using terraform..."
    fill_templates
      
    cd terraform-config
    terraform init
    terraform validate
    terraform apply -auto-approve
    
    environment_info    
    echo -e "\n"
}


# Imports Self-signed certificates to AWS ACM so that they can be used in the LoadBalancer SSL configuration
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
  echo -e "Deploying Nginx ingress controller & adding phantom token plugin in the k8s cluster ...\n"

  # create secrets for TLS termination
  kubectl create secret tls example-eks-tls --cert=certs/example.eks.ssl.pem --key=certs/example.eks.ssl.key -n "$idsvr_namespace" || true
   
  envsubst < ingress-nginx-config/helm-values.yaml.template > ingress-nginx-config/helm-values.yaml

  # Deploy nginx ingress controller  
  helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --values ingress-nginx-config/helm-values.yaml \
    --set "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"="$cert_arn" \
    --namespace ingress-nginx --create-namespace
  
  echo -e "\n"
  environment_info
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
  deploy_example_api
}


get_load_balancer_public_ip() {
  ALL_LB_DATA=$(aws elb describe-load-balancers)
  aws eks update-kubeconfig --region "$region" --name "$cluster_name"
  LB_DNS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath="{.status.loadBalancer.ingress[0].hostname}") 
  LB_NAME=$(jq -r -n --argjson data "$ALL_LB_DATA" "\$data.LoadBalancerDescriptions[] | select(.DNSName==\"$LB_DNS\") | .LoadBalancerName")

  LB_IP=$(aws ec2 describe-network-interfaces --filters Name=description,Values="ELB $LB_NAME" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
  echo "Public IP address of the LoadBalancer is : $LB_IP"

}


deploy_example_api() {
  echo -e "Deploying example api in the k8s cluster ...\n"
  kubectl create namespace "$api_namespace" || true

 # create secrets for TLS termination at ingress layer
  kubectl create secret tls example-eks-tls --cert=certs/example.eks.ssl.pem --key=certs/example.eks.ssl.key  -n "$api_namespace"

  kubectl apply -f example-api-config/example-api-ingress-nginx.yaml -n "${api_namespace}"
  kubectl apply -f example-api-config/example-api-k8s-deployment.yaml -n "${api_namespace}"
  kubectl apply -f example-api-config/example-api-k8s-service.yaml -n "${api_namespace}"
  
  echo -e "\n"
  deploy_ingress_controller
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
  
  if [[ $REPLY =~ ^[Yy]$ && -f terraform-config/terraform.tfstate ]]
  then
   echo "terraform state file detected, proceeding with terraform cleanup .."

   echo "|-----------------------------------------------------------------|"
   echo "| If an error \"Error: context deadline exceeded\" is thrown        |"
   echo "| then please run the deletion script again                       |"
   echo "|-----------------------------------------------------------------|"

   cd terraform-config
   
   n=0
   until [ "$n" -ge 3 ]
   do
      terraform destroy -auto-approve && break  
      n=$((n+1)) 
      echo "terraform couldn't finish cleanup due to errors, Waiting for 20 seconds and then retrying again"
      sleep 20
      echo "Retry attempt # $n ..."
   done

  elif [[ $REPLY =~ ^[Yy]$ && -f eksctl-config/cluster-cfg.yaml ]]
  then    
    echo "eksctl config file detected, proceeding with eksctl cleanup .."
    helm uninstall curity -n "${idsvr_namespace}" || true
    helm uninstall ingress-nginx -n ingress-nginx || true
    kubectl delete -f example-api-config/example-api-k8s-deployment.yaml -n "${api_namespace}" || true
    sleep 10 # sleep for 10 seconds before deleting acm certificates
    delete_acm_certificate || true
    n=0
    until [ "$n" -ge 3 ]
    do
       eksctl delete cluster -f eksctl-config/cluster-cfg.yaml && break  
       n=$((n+1)) 
       echo "eksctl couldn't finish cleanup due to errors, Waiting for 20 seconds and then retrying again"
       sleep 20
       echo "Retry attempt # $n ..."
    done
    echo -e "\n" 
    exit 1
  else
   echo "Aborting the operation .."
  fi
}


environment_info() {
  echo "Waiting for LoadBalancer's External IP, sleeping for 90 seconds ..."
  sleep 90
  
  get_load_balancer_public_ip
  echo -e "\n"

  if [ -z "$LB_IP" ] || [ "$LB_IP" == "None" ]; 
  then 
    LB_IP="<LoadBalancer-IP>";
    echo "LoadBalancer IP couldn't be found, please run the following command to fetch the IP address manually or copy it from the AWS console."
    echo "./deploy-idsvr-aws-eks.sh --load-balancer-public-ip"
  fi
  
  echo -e "\n"
  
  echo "|--------------------------------------------------------------------------------------------------------------------------------------------------|"
  echo "|                                Environment URLS & Endpoints                                                                                      |"
  echo "|--------------------------------------------------------------------------------------------------------------------------------------------------|"
  echo "|                                                                                                                                                  |"
  echo "| [ADMIN UI]        https://admin.example.eks/admin                                                                                                |"
  echo "| [OIDC METADATA]   https://login.example.eks/~/.well-known/openid-configuration                                                                   |"
  echo "| [EXAMPLE API]     https://api.example.eks/echo                                                                                                   |"                                                                                                  
  echo "|                                                                                                                                                  |"
  echo "|                                                                                                                                                  |"
  echo "| * Curity administrator username is : admin and password is : $idsvr_admin_password                                                                "
  echo "| * Remember to add certs/example.eks.ca.pem to operating system's certificate trust store &                                                       |"
  echo "|   $LB_IP  admin.example.eks login.example.eks api.example.eks entry to /etc/hosts                                                                 "
  echo "|--------------------------------------------------------------------------------------------------------------------------------------------------|" 
}


# ==========
# entrypoint
# ==========

case $1 in
  -i | --install)
    greeting_message
    pre_requisites_check
    read_infra_config_file
    determine_eks_cluster_creation_type
    ;;
  -d | --delete)
    read_infra_config_file
    tear_down_environment
    ;;
  --start)
    read_infra_config_file
    startup_environment
    ;;
  --stop)
    read_infra_config_file
    shutdown_environment
    ;;
  --load-balancer-public-ip)
    read_infra_config_file
    get_load_balancer_public_ip
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