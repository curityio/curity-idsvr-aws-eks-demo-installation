FROM k8s.gcr.io/ingress-nginx/controller:v1.2.0

USER www-data

# Download the phantom token module from Curity GitHub repo
ADD --chown=www-data:www-data 'https://github.com/curityio/nginx_phantom_token_module/releases/download/1.2.0/alpine.ngx_curity_http_phantom_token_module_1.19.10.so' /usr/lib/nginx/modules/ngx_curity_http_phantom_token_module.so

RUN ln -s /usr/lib/nginx/modules/ngx_curity_http_phantom_token_module.so /etc/nginx/modules/ngx_curity_http_phantom_token_module.so