#!/bin/sh
set -e

# PROXY1=http,web.mqgo.top,1.1.1.1:80
# PROXY2=app,app.mqgo.top,2.2.2.2:443

# CERT_SOURCE=sing-box volume(default): ./certs:/root/.local/share/certmagic(sing-box) and ./certs:/etc/nginx/certs(nginx-proxy)
# CERT_SOURCE=certbot(Need EMAIL) volume: ./certs:/etc/letsencrypt


variable_by_const() {
    CONFIG_DIR='/etc/nginx'
    CONFIG_FILE="${CONFIG_DIR}/nginx.conf"
    CERTS_DIR="${CONFIG_DIR}/certs"
    HTTP_DIR="${CONFIG_DIR}/conf.d"
    STREAM_DIR="${CONFIG_DIR}/stream.d"
    NGINX_CRONTAB="/etc/periodic/daily/nginx.sh"
    RECORD_FILE="/tmp/record.log"
    CERTBOT_DIR="/etc/letsencrypt"
    CERTBOT_CRONTAB="/etc/periodic/weekly/certbot.sh"
}

variable_by_env() {
    CERT_SOURCE=${CERT_SOURCE-"sing-box"}
    NGINX_client_max_body_size=${NGINX_client_max_body_size-"50m"}
}

variable_by_auto() {
    # 这里的 tmp_domain 在后面 cat 中 2 次解析后，变成需要值
    local cert_name='${tmp_domain}.crt'
    local key_name='${tmp_domain}.key'
    local cert_prefix="${CERTS_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/\${tmp_domain}"
    
    if [ "${CERT_SOURCE}" = 'certbot' ]; then
        cert_name='fullchain.pem'
        key_name='privkey.pem'
        cert_prefix="${CERTS_DIR}/live/\${tmp_domain}"
    fi

    CERT_CRT_FILE="${cert_prefix}/${cert_name}"
    CERT_KEY_FILE="${cert_prefix}/${key_name}"
}

error_exit() {
    echo "$1"
    echo "60 seconds later exit..."
    sleep 60
    exit 1
}

check_and_init() {
    if [ ! "${PROXY1}" ]; then
        error_exit "ERROR: PROXY1 not config!"
    fi
    if [ "${CERT_SOURCE}" = 'certbot' ] && [ ! "${EMAIL}" ]; then
        error_exit "ERROR: EMAIL not config!"
    fi
    rm -rf ${HTTP_DIR} && mkdir -p ${HTTP_DIR}
    rm -rf ${STREAM_DIR} && mkdir -p ${STREAM_DIR}
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

EOF

    cat >>${CONFIG_FILE} <<EOF
    include ${HTTP_DIR}/*.conf;
}

EOF


    cat >>${CONFIG_FILE} <<"EOF"
stream {
    map $ssl_preread_server_name $name {
    }

    server {
        listen 443 reuseport;
        proxy_pass $name;
        ssl_preread on;
        proxy_protocol on;
    }

EOF

    cat >>${CONFIG_FILE} <<EOF
    include ${STREAM_DIR}/*.conf;
}
EOF
}

nginx_http_config() {
    local tmp_protocol="$(echo "$1" | awk -F ',' '{print $1}')"
    local tmp_domain="$(echo "$1" | awk -F ',' '{print $2}')"
    local tmp_dest="$(echo "$1" | awk -F ',' '{print $3}')"
    local tmp_port=$((10000 + $2))
    # 依赖上面 tmp_domain 变量
    local tmp_crt=$(eval echo "${CERT_CRT_FILE}")
    local tmp_key=$(eval echo "${CERT_KEY_FILE}")

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
    ssl_certificate ${tmp_crt};
    ssl_certificate_key ${tmp_key};

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
    # certbot 自动申请证书
    if [ "${CERT_SOURCE}" = "certbot" ] && [ ! -e "${tmp_crt}" ]; then
        certbot certonly -m ${EMAIL} --agree-tos --standalone -d ${tmp_domain} || error_exit "ERROR: certbot failed"
        echo "Domain ${tmp_domain} certbot success"
    fi
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
            if [[ "${tmp_proxy}" =~ "^https?," ]]; then
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

nginx_crontab_script() {
    cat >${NGINX_CRONTAB} <<EOF
#!/bin/sh
set -e

IS_RELOAD=0
IS_INIT=0
if [ ! -e ${RECORD_FILE} ]; then
    echo "\$(date +"%Y/%m/%d %H:%M"): script init" > ${RECORD_FILE}
    IS_INIT=1
fi
for i in \$(grep '${CERTS_DIR}.*crt;' ${HTTP_DIR}/*.conf | awk '{print \$NF}' | sed 's/;//')
do
    cert_md5=\$(md5sum \${i} | awk '{print \$1}')
    if ! grep -q "\${cert_md5}" ${RECORD_FILE}; then
        IS_RELOAD=1
        echo "\${cert_md5}" >> ${RECORD_FILE}
    fi
done

if [ \${IS_RELOAD} -eq 1 ] && [ \${IS_INIT} -eq 0 ]; then
    nginx -s reload
    echo "\$(date +"%Y/%m/%d %H:%M"): reload nginx" >> ${RECORD_FILE}
fi
EOF
    chmod 755 ${NGINX_CRONTAB}
    ${NGINX_CRONTAB}
}

certbot_crontab_script() {
    cat >${CERTBOT_CRONTAB} <<EOF
#!/bin/sh
set -e

certbot renew --deploy-hook "nginx -s reload && date >> /tmp/certbot-renew.log"
EOF
    chmod 755 ${CERTBOT_CRONTAB}
}

main() {
    variable_by_const
    variable_by_env
    variable_by_auto
    check_and_init
    nginx_basic_config
    nginx_proxy_config
    nginx_config_opt
    nginx_crontab_script
    if [ "${CERT_SOURCE}" = 'certbot' ]; then
        certbot_crontab_script
    fi
}

main
crond # alpine 启动 crontab 功能
exec "$@"
