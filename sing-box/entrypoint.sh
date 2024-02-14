#!/bin/sh
set -e

# server config file path
SERVER_FILE='/etc/sing-box/config.json'
CONFIG_DIR=$(dirname ${SERVER_FILE})
SERVER_TROJAN=${CONFIG_DIR}/trojan.json
SERVER_NAIVE=${CONFIG_DIR}/naive.json
SERVER_VLESS=${CONFIG_DIR}/vless.json
SERVER_TUIC=${CONFIG_DIR}/tuic.json
SERVER_HYSTERIA2=${CONFIG_DIR}/hysteria2.json

# client config file path
CLIENT_FILE=${CONFIG_DIR}/client.json
CLIENT_TROJAN=${CONFIG_DIR}/client-trojan.json
CLIENT_VLESS=${CONFIG_DIR}/client-vless.json
CLIENT_TUIC=${CONFIG_DIR}/client-tuic.json
CLIENT_HYSTERIA2=${CONFIG_DIR}/client-hysteria2.json
CLIENT_ROUTE=${CONFIG_DIR}/client-route.json
# CLIENT_EXPERIMENTAL=${CONFIG_DIR}/client-experimental.json


# ------ server ------
# trojan.json
create_server_trojan() {
    cat >${SERVER_TROJAN} <<"EOF"
{
    "type": "trojan",
    "tag": "trojan-in",
    "listen": "::",
    "listen_port": 443,
    "users": [
        {
            "password": "123"
        }
    ],
    "tls": {
        "enabled": true,
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "acme": {
            "domain": [],
            "email": "123",
            "provider": "letsencrypt"
        }
    }
}
EOF
}

# naive.json
create_server_naive() {
    cat >${SERVER_NAIVE} <<"EOF"
{
    "type": "naive",
    "tag": "naive-in",
    "listen": "::",
    "listen_port": 443,
    "users": [
        {
            "username": "123",
            "password": "123"
        }
    ],
    "tls": {
        "enabled": true,
        "acme": {
            "domain": [],
            "email": "123",
            "provider": "letsencrypt"
        }
    }
}
EOF
}

# vless.json
create_server_vless() {
    cat >${SERVER_VLESS} <<"EOF"
{
    "type": "vless",
    "tag": "vless-in",
    "listen": "::",
    "listen_port": 443,
    "users": [
        {
            "uuid": "123",
            "flow": "xtls-rprx-vision"
        }
    ],
    "tls": {
        "enabled": true,
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "acme": {
            "domain": [],
            "email": "123",
            "provider": "letsencrypt"
        }
    }
}
EOF
}

# tuic.json
create_server_tuic() {
    cat >${SERVER_TUIC} <<"EOF"
{
    "type": "tuic",
    "tag": "tuic-in",
    "listen": "::",
    "listen_port": 443,
    "users": [
        {
            "uuid": "123",
            "password": "123"
        }
    ],
    "congestion_control": "bbr",
    "tls": {
        "enabled": true,
        "alpn": [
            "h3"
        ],
        "acme": {
            "domain": [],
            "email": "123",
            "provider": "letsencrypt"
        }
    }
}
EOF
}

# hysteria2.json
create_server_hysteria2() {
    cat >${SERVER_HYSTERIA2} <<"EOF"
{
    "type": "hysteria2",
    "tag": "hysteria2-in",
    "listen": "::",
    "listen_port": 443,
    "up_mbps": 100,
    "down_mbps": 100,
    "users": [
        {
            "password": "123"
        }
    ],
    "tls": {
        "enabled": true,
        "alpn": [
            "h3"
        ],
        "acme": {
            "domain": [],
            "email": "123",
            "provider": "letsencrypt"
        }
    }
}
EOF
}

# config.json
create_server_config() {
    cat >${SERVER_FILE} <<"EOF"
{
    "log": {
        "level": "warn",
        "timestamp": true
    },
    "inbounds": []
}
EOF
}

# generate config.json content
generate_server_config() {
    mkdir -p ${CONFIG_DIR}
    # 创建修改 trojan 配置
    create_server_trojan
    tmp_var=${PORT_TROJAN} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TROJAN}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TROJAN}
    if [ ${TROJAN_FALLBACK_PORT} -ne 0 ]; then
        tmp_var=${TROJAN_FALLBACK_SERVER} yq -ioj '.fallback.server = strenv(tmp_var)' ${SERVER_TROJAN}
        tmp_var=${TROJAN_FALLBACK_PORT} yq -ioj '.fallback.server_port = env(tmp_var)' ${SERVER_TROJAN}
        yq -ioj 'del(.tls.alpn[] | select(. == "h2"))' ${SERVER_TROJAN}
    fi
    # 创建修改 naive 配置
    create_server_naive
    tmp_var=${PORT_NAIVE} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_NAIVE}
    tmp_var=${USERNAME} yq -ioj '.users[0].username = strenv(tmp_var)' ${SERVER_NAIVE}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_NAIVE}
    # 创建修改 vless 配置
    create_server_vless
    tmp_var=${PORT_VLESS} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_VLESS}
    tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${SERVER_VLESS}
    # 创建修改 tuic config
    create_server_tuic
    tmp_var=${PORT_TUIC} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TUIC}
    tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${SERVER_TUIC}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TUIC}
    # 创建修改 hysteria2 config
    create_server_hysteria2
    tmp_var=${PORT_HYSTERIA2} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_HYSTERIA2}
    tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${SERVER_HYSTERIA2}
    tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${SERVER_HYSTERIA2}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_HYSTERIA2}
    # 创建修改 config 配置
    create_server_config
    tmp_var=${LOG_LEVEL} yq -ioj '.log.level = strenv(tmp_var)' ${SERVER_FILE}
    # add trojan config
    if [ ${PORT_TROJAN} -ne 0 ]; then
        tmp_var=${SERVER_TROJAN} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi
    # add naive config
    if [ ${PORT_NAIVE} -ne 0 ]; then
        tmp_var=${SERVER_NAIVE} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi
    # add vless config
    if [ ${PORT_VLESS} -ne 0 ]; then
        tmp_var=${SERVER_VLESS} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi
    # add tuic config
    if [ ${PORT_TUIC} -ne 0 ]; then
        tmp_var=${SERVER_TUIC} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi
    # add hysteria2 config
    if [ ${PORT_HYSTERIA2} -ne 0 ]; then
        tmp_var=${SERVER_HYSTERIA2} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi
    # modify config about tls
    for i in $(echo "${DOMAIN}" | awk -F ',' '{for(i=1;i<=NF;i++) print $i}'); do
        tmp_var=${i} yq -ioj '.inbounds[].tls.acme.domain += strenv(tmp_var)' ${SERVER_FILE}
    done
    tmp_var=${EMAIL} yq -ioj '.inbounds[].tls.acme.email = strenv(tmp_var)' ${SERVER_FILE}
    # Delete temporary files
    rm -f ${SERVER_TROJAN} ${SERVER_NAIVE} ${SERVER_VLESS} ${SERVER_TUIC} ${SERVER_HYSTERIA2}
}

# ------ client ------
create_client_trojan() {
    cat >${CLIENT_TROJAN} <<"EOF"
{
    "type": "trojan",
    "tag": "trojan-out",
    "server": "",
    "server_port": 443,
    "password": "123",
    "tls": {
        "enabled": true,
        "utls": {
            "enabled": true,
            "fingerprint": "chrome"
        }
    }
}
EOF
}

create_client_vless() {
    cat >${CLIENT_VLESS} <<"EOF"
{
    "type": "vless",
    "tag": "vless-out",
    "server": "",
    "server_port": 443,
    "uuid": "123",
    "flow": "xtls-rprx-vision",
    "tls": {
        "enabled": true,
        "utls": {
            "enabled": true,
            "fingerprint": "chrome"
        }
    }
}
EOF
}

create_client_tuic() {
    cat >${CLIENT_TUIC} <<"EOF"
{
    "type": "tuic",
    "tag": "tuic-out",
    "server": "",
    "server_port": 443,
    "uuid": "123",
    "password": "123",
    "congestion_control": "bbr",
    "tls": {
        "enabled": true,
        "alpn": [
            "h3"
        ]
    }
}
EOF
}

create_client_hysteria2() {
    cat >${CLIENT_HYSTERIA2} <<"EOF"
{
    "type": "hysteria2",
    "tag": "hysteria2-out",
    "server": "",
    "server_port": 443,
    "up_mbps": 100,
    "down_mbps": 100,
    "password": "123",
    "tls": {
        "enabled": true,
        "alpn": [
            "h3"
        ]
    }
}
EOF
}

create_client_config() {
    cat >${CLIENT_FILE} <<"EOF"
{
    "log": {
        "level": "warn",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "tun0",
            "inet4_address": "172.19.0.1/30",
            "inet6_address": "fdfe:dcba:9876::1/126",
            "mtu": 9000,
            "auto_route": true,
            "strict_route": true,
            "stack": "system",
            "sniff": true,
            "sniff_override_destination": false
        }
    ],
    "outbounds": [
        {
            "type": "selector",
            "tag": "proxy",
            "outbounds": [
                "auto"
            ],
            "default": "auto",
            "interrupt_exist_connections": false
        },
        {
            "type": "urltest",
            "tag": "auto",
            "outbounds": [],
            "interrupt_exist_connections": false
        },
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        },
        {
            "type": "dns",
            "tag": "dns"
        }
    ],
    "dns": {
        "servers": [
            {
                "tag": "google",
                "address": "tls://8.8.8.8",
                "strategy": "ipv4_only",
                "detour": "proxy"
            },
            {
                "tag": "aliyun",
                "address": "223.5.5.5",
                "strategy": "ipv4_only",
                "detour": "direct"
            },
            {
                "tag": "remote",
                "address": "fakeip",
                "strategy": "ipv4_only"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "aliyun"
            },
            {
                "query_type": [
                    "A",
                    "AAAA"
                ],
                "server": "remote"
            }
        ],
        "fakeip": {
            "enabled": true,
            "inet4_range": "198.18.0.0/15",
            "inet6_range": "fc00::/18"
        },
        "independent_cache": true
    }
}
EOF
}

create_client_route() {
    cat >${CLIENT_ROUTE} <<"EOF"
{
    "rules": [
        {
            "type": "logical",
            "mode": "or",
            "rules": [
                {
                    "protocol": "dns"
                },
                {
                    "port": 53
                }
            ],
            "outbound": "dns"
        },
        {
            "geoip": "private",
            "outbound": "direct"
        },
        {
            "type": "logical",
            "mode": "or",
            "rules": [
                {
                    "port": 853
                },
                {
                    "network": "udp",
                    "port": 443
                },
                {
                    "protocol": "stun"
                }
            ],
            "outbound": "block"
        },
        {
            "type": "logical",
            "mode": "and",
            "rules": [
                {
                    "geosite": "geolocation-!cn",
                    "invert": true
                },
                {
                    "geosite": [
                        "cn",
                        "category-companies@cn"
                    ],
                    "geoip": "cn"
                }
            ],
            "outbound": "direct"
        }
    ],
    "final": "proxy",
    "auto_detect_interface": true
}
EOF
}

create_client_route_v18() {
    cat >${CLIENT_ROUTE} <<"EOF"
{
    "rule_set": [
        {
            "type": "remote",
            "tag": "geoip-cn",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs"
        },
        {
            "type": "remote",
            "tag": "geosite-cn",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs"
        },
        {
            "type": "remote",
            "tag": "geosite-geolocation-!cn",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs"
        }
    ],
    "rules": [
        {
            "type": "logical",
            "mode": "or",
            "rules": [
                {
                    "protocol": "dns"
                },
                {
                    "port": 53
                }
            ],
            "outbound": "dns"
        },
        {
            "ip_is_private": true,
            "outbound": "direct"
        },
        {
            "type": "logical",
            "mode": "or",
            "rules": [
                {
                    "port": 853
                },
                {
                    "network": "udp",
                    "port": 443
                },
                {
                    "protocol": "stun"
                }
            ],
            "outbound": "block"
        },
        {
            "type": "logical",
            "mode": "and",
            "rules": [
                {
                    "rule_set": "geosite-geolocation-!cn",
                    "invert": true
                },
                {
                    "rule_set": [
                        "geoip-cn",
                        "geosite-cn"
                    ]
                }
            ],
            "outbound": "direct"
        }
    ],
    "final": "proxy",
    "auto_detect_interface": true
}
EOF
}

generate_client_config() {
    local first_domain="$(echo "${DOMAIN}" | awk -F ',' '{print $1}')"
    local trojan_tag="Trojan-${NODE_TAG}"
    local vless_tag="Vless-${NODE_TAG}"
    local tuic_tag="Tuic-${NODE_TAG}"
    local hysteria2_tag="Hysteria2-${NODE_TAG}"
    # 创建修改 client trojan 配置
    create_client_trojan
    tmp_var=${trojan_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TROJAN}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TROJAN}
    tmp_var=${PORT_TROJAN} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TROJAN}
    tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TROJAN}
    # 创建修改 client vless 配置
    create_client_vless
    tmp_var=${vless_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_VLESS}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_VLESS}
    tmp_var=${PORT_VLESS} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_VLESS}
    tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_VLESS}
    # 创建修改 client tuic 配置
    create_client_tuic
    tmp_var=${tuic_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TUIC}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TUIC}
    tmp_var=${PORT_TUIC} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TUIC}
    tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_TUIC}
    tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TUIC}
    # 创建修改 client hysteria2 配置
    create_client_hysteria2
    tmp_var=${hysteria2_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_HYSTERIA2}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_HYSTERIA2}
    tmp_var=${PORT_HYSTERIA2} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_HYSTERIA2}
    tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${CLIENT_HYSTERIA2}
    tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${CLIENT_HYSTERIA2}
    tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_HYSTERIA2}
    # 创建修改 client 配置
    create_client_config
    tmp_var=${LOG_LEVEL} yq -ioj '.log.level = strenv(tmp_var)' ${CLIENT_FILE}
    local proxy_index=$(yq -roj '.outbounds[] | select(.tag == "proxy") | key' ${CLIENT_FILE})
    local auto_index=$(yq -roj '.outbounds[] | select(.tag == "auto") | key' ${CLIENT_FILE})
    # 创建修改 client route 配置
    if [ $(echo "${VERSION} >= 1.8" | bc) -eq 1 ]; then
        create_client_route_v18
    else
        create_client_route
    fi
    # add client trojan config
    if [ ${PORT_TROJAN} -ne 0 ]; then
        tmp_var=${CLIENT_TROJAN} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client vless config
    if [ ${PORT_VLESS} -ne 0 ]; then
        tmp_var=${CLIENT_VLESS} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client tuic config
    if [ ${PORT_TUIC} -ne 0 ]; then
        tmp_var=${CLIENT_TUIC} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client hysteria2 config
    if [ ${PORT_HYSTERIA2} -ne 0 ]; then
        tmp_var=${CLIENT_HYSTERIA2} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client route config
    tmp_var=${CLIENT_ROUTE} yq -ioj '.route = load(strenv(tmp_var))' ${CLIENT_FILE}
    # add client clash_api config
    if [ ${CLIENT_CLASH_PORT} -ne 0 ]; then
        tmp_var="127.0.0.1:${CLIENT_CLASH_PORT}" yq -ioj '.experimental.clash_api.external_controller = strenv(tmp_var)' ${CLIENT_FILE}
        tmp_var=${CLIENT_CLASH_UI} yq -ioj '.experimental.clash_api.external_ui = strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client cache_file config
    if [ $(echo "${VERSION} >= 1.8" | bc) -eq 1 ]; then
        tmp_var="true" yq -ioj '.experimental.cache_file.enabled = env(tmp_var)' ${CLIENT_FILE}
        tmp_var="cache.db" yq -ioj '.experimental.cache_file.path = strenv(tmp_var)' ${CLIENT_FILE}
        tmp_var="true" yq -ioj '.experimental.cache_file.store_fakeip = env(tmp_var)' ${CLIENT_FILE}
    fi
    # Delete temporary files
    rm -f ${CLIENT_TROJAN} ${CLIENT_VLESS} ${CLIENT_TUIC} ${CLIENT_HYSTERIA2} ${CLIENT_ROUTE}
}


# ------ init ------
init_variables() {
    # 获取变量, 否则自动生成
    USERNAME="${USERNAME:-$(pwgen 4 1 -s -0)}"
    PASSWORD="${PASSWORD:-$(pwgen 16 1 -s)}"
    UUID="${UUID:-$(sing-box generate uuid)}"
    LOG_LEVEL="${LOG_LEVEL:-warn}"
    NODE_TAG="${NODE_TAG:-$(pwgen 4 1 -s -0 -A)}"
    VERSION=$(sing-box version | grep 'version' | grep -oE '[0-9]+\.[0-9]+')
    # 获取变量, 否则默认为 0, 表示不开启
    PORT_TROJAN="${PORT_TROJAN:-0}"
    PORT_NAIVE="${PORT_NAIVE:-0}"
    PORT_VLESS="${PORT_VLESS:-0}"
    PORT_TUIC="${PORT_TUIC:-0}"
    PORT_HYSTERIA2="${PORT_HYSTERIA2:-0}"
    # 额外配置
    TROJAN_FALLBACK_SERVER="${TROJAN_FALLBACK_SERVER:-127.0.0.1}"
    TROJAN_FALLBACK_PORT="${TROJAN_FALLBACK_PORT:-0}"
    HYSTERIA_UP_SPEED="${HYSTERIA_UP_SPEED:-100}"
    HYSTERIA_DOWN_SPEED="${HYSTERIA_DOWN_SPEED:-100}"
    # 客户端配置
    CLIENT_CLASH_PORT="${CLIENT_CLASH_PORT:-0}"
    CLIENT_CLASH_UI="${CLIENT_CLASH_UI:-ui}"
    # 检查
    CHECK_DNS="${CHECK_DNS:-1}"

    # 必须配置 domain 和 email
    if [ ! "${DOMAIN}" ] || [ ! "${EMAIL}" ]; then
        echo "DOMAIN and EMAIL environment variables must be set"
        exit 1
    fi
    # 检查 PORT
    if ! echo "${PORT_TROJAN}${PORT_NAIVE}${PORT_VLESS}${PORT_TUIC}${PORT_HYSTERIA2}" | grep -Eqi '^[[:digit:]]*$'; then
        echo "PORT must be a number"
        exit 1
    fi
    # 如果未设置 PORT，默认开启 trojan，端口 443
    port_sum=$((PORT_TROJAN + PORT_NAIVE + PORT_VLESS + PORT_TUIC + PORT_HYSTERIA2))
    if [ ${port_sum} -eq 0 ]; then
        PORT_TROJAN=443
    fi
}

check_domain() {
    local ipv4_address ipv6_address
    local first_domain="$(echo "${DOMAIN}" | awk -F ',' '{print $1}')"
    while true; do
        ipv4_address=$(curl -fsL4 ifconfig.me || echo "")
        ipv6_address=$(curl -fsL6 ifconfig.me || echo "")
        if [ ${ipv4_address} ] || [ ${ipv6_address} ]; then
            break
        else
            echo "Unable to obtain the local public IP address!"
            sleep 60
        fi
    done

    while true; do
        if [ ${ipv4_address} ] && dig A ${first_domain} +short | grep -Eqi "${ipv4_address}"; then
            break
        fi
        if [ ${ipv6_address} ] && dig AAAA ${first_domain} +short | grep -Eqi "${ipv6_address}"; then
            break
        fi
        echo "DNS resolution mismatch!"
        sleep 10
    done
}


# ------ run ------
if [ ! -f ${SERVER_FILE} ]; then
    init_variables
    if [ ${CHECK_DNS} -ne 0 ]; then
        check_domain
    fi
    generate_server_config
    generate_client_config
    echo "secret username: ${USERNAME}"
    echo "secret password: ${PASSWORD}"
    echo "secret uuid: ${UUID}"
    echo "secret vless flow: xtls-rprx-vision"
fi

exec "$@"
