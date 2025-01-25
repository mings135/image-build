#!/bin/sh
set -e

# PROXY1=http,web.mqgo.top,1.1.1.1:80
# PROXY2=app,app.mqgo.top,2.2.2.2:443
# CERT_SOURCE=certbot
# volume /etc/nginx/certs --> sing-box /root/.local/share/certmagic(default) or certbot /etc/letsencrypt

variable_by_const() {
    CONFIG_DIR='/etc/nginx'
    CONFIG_FILE="${CONFIG_DIR}/nginx.conf"
    HTTP_DIR="${CONFIG_DIR}/conf.d"
    STREAM_DIR="${CONFIG_DIR}/stream-conf.d"
    CRONTAB_DIR="/etc/periodic/daily"
    RECORD_DIR="/tmp"
}

variable_by_env() {
    CERT_SOURCE=${CERT_SOURCE-"sing-box"}
    NGINX_client_max_body_size=${NGINX_client_max_body_size-"50m"}
}

variable_by_auto() {
    # 这里的 tmp_domain 在后面 cat 中 2 次解析后，变成需要值
    local cert_name='${tmp_domain}.crt'
    local key_name='${tmp_domain}.key'
    local cert_prefix='certs/certificates/acme-v02.api.letsencrypt.org-directory/${tmp_domain}'
    
    if [ "${CERT_SOURCE}" = 'certbot' ]; then
        cert_name='fullchain.pem'
        key_name='privkey.pem'
        cert_prefix='certs/live/${tmp_domain}'
    fi

    CERT_CRT_FILE="${cert_prefix}/${cert_name}"
    CERT_KEY_FILE="${cert_prefix}/${key_name}"
}

check_and_init() {
    if grep -q 'ssl_preread_server_name' ${CONFIG_FILE}; then
        echo "Already configured, Skip!"
        exit 0
    fi
    if [ ! "${PROXY1}" ]; then
        echo "ERROR: Proxy env not config!"
        exit 1
    fi
    if [ ! -e ${HTTP_DIR} ]; then
        mkdir -p ${HTTP_DIR}
    fi
    if [ ! -e ${STREAM_DIR} ]; then
        mkdir -p ${STREAM_DIR}
    fi
    if [ -e ${HTTP_DIR}/default.conf ]; then
        rm ${HTTP_DIR}/default.conf
    fi
}

nginx_reload_script() {
    local tmp_domain=$1
    local tmp_cert_file=${CONFIG_DIR}/$(eval echo "${CERT_CRT_FILE}")
    local tmp_record_file=${RECORD_DIR}/${tmp_domain}.md

    cat >${CRONTAB_DIR}/${tmp_domain}.sh <<EOF
#!/bin/sh

CERT_FILE="${tmp_cert_file}"
RECORD_FILE="${tmp_record_file}"
EOF

    cat >>${CRONTAB_DIR}/${tmp_domain}.sh <<"EOF"
if [ ! -e ${CERT_FILE} ]; then
    echo "$(date +"%Y/%m/%d %H:%M"): Not found ${CERT_FILE}" >> /tmp/script.log
    exit 1
fi
new_md5=$(md5sum ${CERT_FILE} | awk '{print $1}')
if [ -e ${RECORD_FILE} ]; then
    old_md5=$(cat ${RECORD_FILE})
    if [ "${old_md5}" != "${new_md5}" ]; then
        nginx -s reload
        echo "$(date +"%Y/%m/%d %H:%M"): reload nginx" >> /tmp/script.log
    fi
else
    echo "${new_md5}" > ${RECORD_FILE}
    echo "$(date +"%Y/%m/%d %H:%M"): create ${RECORD_FILE}" >> /tmp/script.log
fi
EOF
    chmod 755 ${CRONTAB_DIR}/${tmp_domain}.sh
    ${CRONTAB_DIR}/${tmp_domain}.sh
}

nginx_basic_config() {
    cat >${CONFIG_FILE} <<"EOF"
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    client_max_body_size 10m;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $proxy_protocol_addr;
    proxy_set_header X-Forwarded-For $proxy_protocol_addr,$proxy_add_x_forwarded_for;

    include /etc/nginx/conf.d/*.conf;
}


stream {
    map $ssl_preread_server_name $name {
    }

    server {
        listen 443 reuseport;
        proxy_pass $name;
        ssl_preread on;
        proxy_protocol on;
    }

    include /etc/nginx/stream-conf.d/*.conf;
}
EOF
}

nginx_http_config() {
    local tmp_protocol="$(echo "$1" | awk -F ',' '{print $1}')"
    local tmp_domain="$(echo "$1" | awk -F ',' '{print $2}')"
    local tmp_dest="$(echo "$1" | awk -F ',' '{print $3}')"
    local tmp_port=$((10000 + $2))

    cat >${HTTP_DIR}/${tmp_domain}.conf <<EOF
upstream ${tmp_domain} {
    server ${tmp_dest};
}

server {
    listen 127.0.0.1:${tmp_port} ssl proxy_protocol;
    server_name ${tmp_domain};
    http2 on;
    
    ssl_session_timeout 5m;
    ssl_session_cache shared:SSL:50m;
    ssl_certificate $(eval echo "${CERT_CRT_FILE}");
    ssl_certificate_key $(eval echo "${CERT_KEY_FILE}");

    location / {
        proxy_pass ${tmp_protocol}://${tmp_domain};
    }
}
EOF

    cat >${STREAM_DIR}/${tmp_domain}.conf <<EOF
upstream web-${tmp_port} {
    server 127.0.0.1:${tmp_port};
}
EOF

    sed -i "/ssl_preread_server_name/a \        ${tmp_domain}  web-${tmp_port};" ${CONFIG_FILE}

    nginx_reload_script "${tmp_domain}"
}

nginx_default_config(){
    local tmp_domain="$(echo "$1" | awk -F ',' '{print $2}')"
    
    cat >${CONFIG_FILE} <<"EOF"
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;
EOF

    cat >>${CONFIG_FILE} <<EOF

    server {
        listen       443 ssl;
        server_name  ${tmp_domain};

        ssl_session_timeout 5m;
        ssl_session_cache shared:SSL:50m;
        ssl_certificate $(eval echo "${CERT_CRT_FILE}");
        ssl_certificate_key $(eval echo "${CERT_KEY_FILE}");


        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
EOF

     nginx_reload_script "${tmp_domain}"
}

nginx_stream_config() {
    local tmp_domain="$(echo "$1" | awk -F ',' '{print $2}')"
    local tmp_dest="$(echo "$1" | awk -F ',' '{print $3}')"
    local tmp_port=$((10000 + $2))

    cat >${STREAM_DIR}/${tmp_domain}.conf <<EOF
upstream mid-${tmp_port} {
    server 127.0.0.1:${tmp_port};
}

upstream dest-${tmp_port} {
    server ${tmp_dest};
}

server {
    listen 127.0.0.1:${tmp_port} proxy_protocol;
    proxy_pass dest-${tmp_port};
}
EOF

    sed -i "/ssl_preread_server_name/a \        ${tmp_domain}  mid-${tmp_port};" ${CONFIG_FILE}
}

nginx_proxy_config() {
    local tmp_proxy tmp_type

    for i in $(seq 1 9); do
        tmp_proxy=$(eval echo '$PROXY'"$i")
        if [ "${tmp_proxy}" ]; then
            if [[ "${tmp_proxy}" =~ "^default," ]]; then
                nginx_default_config "${tmp_proxy}"
                break
            elif [[ "${tmp_proxy}" =~ "^https?," ]]; then
                nginx_http_config "${tmp_proxy}" $i
            else
                nginx_stream_config "${tmp_proxy}" $i
            fi
        else
            break
        fi
    done
}

nginx_config_opt() {
    sed -i "s/client_max_body_size .*/client_max_body_size ${NGINX_client_max_body_size};/" ${CONFIG_FILE}
}

main() {
    variable_by_const
    variable_by_env
    variable_by_auto
    check_and_init
    nginx_basic_config
    nginx_proxy_config
    nginx_config_opt
}

main
crond # alpine 启动 crontab 功能
exec "$@"
