#!/bin/sh
set -e

# PROXY1=web1.example.com,1.1.1.1:80
# PROXY2=web2.example.com,2.2.2.2:80

variable_by_const() {
    CONFIG_DIR='/etc/nginx'
    HTTP_DIR="${CONFIG_DIR}/conf.d"
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
}

nginx_http_proxy() {
    local tmp_domain="$(echo "$1" | awk -F ',' '{print $1}')"
    local tmp_dest="$(echo "$1" | awk -F ',' '{print $2}')"

    cat >${HTTP_DIR}/${tmp_domain}.conf <<EOF
server {
    listen 80;
    server_name ${tmp_domain};
    server_tokens off;
    
    location / {
        proxy_pass http://${tmp_dest};
        proxy_connect_timeout 2s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        error_page 502 = @offline;
    }

    location @offline {
        default_type text/plain;
        return 503 "Service Unavailable";
    }
}
EOF
}

nginx_proxy_config() {
    local tmp_proxy

    cat >${HTTP_DIR}/default.conf <<EOF
server {
    listen 80 default_server;
    server_name _;
    server_tokens off;
    return 444;
}
EOF

    for i in $(seq 1 9); do
        tmp_proxy=$(eval echo '$PROXY'"$i")

        if [ "${tmp_proxy}" ]; then
            nginx_http_proxy "${tmp_proxy}"
        else
            break
        fi
    done
}

main() {
    variable_by_const
    check_and_init
    nginx_proxy_config
}

main
exec "$@"