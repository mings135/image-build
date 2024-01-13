#!/bin/sh
set -e

# server config file path
CONFIG_FILE='/etc/sing-box/config.json'
CONFIG_DIR=$(dirname ${CONFIG_FILE})
TROJAN_JSON=${CONFIG_DIR}/trojan.json
NAIVE_JSON=${CONFIG_DIR}/naive.json
VLESS_JSON=${CONFIG_DIR}/vless.json
TUIC_JSON=${CONFIG_DIR}/tuic.json
HYSTERIA2_JSON=${CONFIG_DIR}/hysteria2.json
# client config file path
CLIENT_FILE=${CONFIG_DIR}/client.json
CLIENT_1_8_FILE=${CONFIG_DIR}/client-1.8.json
CLIENT_1_8_PATCH_DNS_JSON=${CONFIG_DIR}/client-1-8-patch-dns.json
CLIENT_1_8_PATCH_ROUTE_JSON=${CONFIG_DIR}/client-1-8-patch-route.json
CLIENT_TROJAN_JSON=${CONFIG_DIR}/client-trojan.json
CLIENT_VLESS_JSON=${CONFIG_DIR}/client-vless.json
CLIENT_TUIC_JSON=${CONFIG_DIR}/client-tuic.json
CLIENT_HYSTERIA2_JSON=${CONFIG_DIR}/client-hysteria2.json
CLIENT_DNS_RULES_JSON=${CONFIG_DIR}/client-dns-rules.json

## server
# create trojan.json
create_trojan_json() {
    cat >${TROJAN_JSON} <<"EOF"
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

# create naive.json
create_naive_json() {
    cat >${NAIVE_JSON} <<"EOF"
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

# create vless.json
create_vless_json() {
    cat >${VLESS_JSON} <<"EOF"
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

# create tuic.json
create_tuic_json() {
    cat >${TUIC_JSON} <<"EOF"
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

# create hysteria2.json
create_hysteria2_json() {
    cat >${HYSTERIA2_JSON} <<"EOF"
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

# create config.json
create_config_json() {
    cat >${CONFIG_FILE} <<"EOF"
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
generate_config() {
    mkdir -p ${CONFIG_DIR}
    # 创建修改 trojan 配置
    create_trojan_json
    tmp_var=${PORT_TROJAN} yq -ioj '.listen_port = env(tmp_var)' ${TROJAN_JSON}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${TROJAN_JSON}
    if [ ${TROJAN_FALLBACK_PORT} -ne 0 ]; then
        tmp_var=${TROJAN_FALLBACK_SERVER} yq -ioj '.fallback.server = strenv(tmp_var)' ${TROJAN_JSON}
        tmp_var=${TROJAN_FALLBACK_PORT} yq -ioj '.fallback.server_port = env(tmp_var)' ${TROJAN_JSON}
        yq -ioj 'del(.tls.alpn[] | select(. == "h2"))' ${TROJAN_JSON}
    fi
    # 创建修改 naive 配置
    create_naive_json
    tmp_var=${PORT_NAIVE} yq -ioj '.listen_port = env(tmp_var)' ${NAIVE_JSON}
    tmp_var=${USERNAME} yq -ioj '.users[0].username = strenv(tmp_var)' ${NAIVE_JSON}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${NAIVE_JSON}
    # 创建修改 vless 配置
    create_vless_json
    tmp_var=${PORT_VLESS} yq -ioj '.listen_port = env(tmp_var)' ${VLESS_JSON}
    tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${VLESS_JSON}
    # 创建修改 tuic config
    create_tuic_json
    tmp_var=${PORT_TUIC} yq -ioj '.listen_port = env(tmp_var)' ${TUIC_JSON}
    tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${TUIC_JSON}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${TUIC_JSON}
    # 创建修改 hysteria2 config
    create_hysteria2_json
    tmp_var=${PORT_HYSTERIA2} yq -ioj '.listen_port = env(tmp_var)' ${HYSTERIA2_JSON}
    tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${HYSTERIA2_JSON}
    tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${HYSTERIA2_JSON}
    tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${HYSTERIA2_JSON}
    # 创建修改 config 配置
    create_config_json
    tmp_var=${LOG_LEVEL} yq -ioj '.log.level = strenv(tmp_var)' ${CONFIG_FILE}
    # add trojan config
    if [ ${PORT_TROJAN} -ne 0 ]; then
        tmp_var=${TROJAN_JSON} yq -ioj '.inbounds += load(strenv(tmp_var))' ${CONFIG_FILE}
    fi
    # add naive config
    if [ ${PORT_NAIVE} -ne 0 ]; then
        tmp_var=${NAIVE_JSON} yq -ioj '.inbounds += load(strenv(tmp_var))' ${CONFIG_FILE}
    fi
    # add vless config
    if [ ${PORT_VLESS} -ne 0 ]; then
        tmp_var=${VLESS_JSON} yq -ioj '.inbounds += load(strenv(tmp_var))' ${CONFIG_FILE}
    fi
    # add tuic config
    if [ ${PORT_TUIC} -ne 0 ]; then
        tmp_var=${TUIC_JSON} yq -ioj '.inbounds += load(strenv(tmp_var))' ${CONFIG_FILE}
    fi
    # add hysteria2 config
    if [ ${PORT_HYSTERIA2} -ne 0 ]; then
        tmp_var=${HYSTERIA2_JSON} yq -ioj '.inbounds += load(strenv(tmp_var))' ${CONFIG_FILE}
    fi
    # modify config about tls
    for i in $(echo "${DOMAIN}" | awk -F ',' '{for(i=1;i<=NF;i++) print $i}'); do
        tmp_var=${i} yq -ioj '.inbounds[].tls.acme.domain += strenv(tmp_var)' ${CONFIG_FILE}
    done
    tmp_var=${EMAIL} yq -ioj '.inbounds[].tls.acme.email = strenv(tmp_var)' ${CONFIG_FILE}
    # Delete temporary files
    rm -f ${TROJAN_JSON} ${NAIVE_JSON} ${VLESS_JSON} ${TUIC_JSON} ${HYSTERIA2_JSON}
}

## client
# create client.json
create_client_file() {
    cat >${CLIENT_FILE} <<"EOF"
{
    "log": {
        "level": "warn",
        "timestamp": true
    },
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
        "final": "google",
        "independent_cache": true
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
    "route": {
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
}
EOF
}

create_client_trojan_json() {
    cat >${CLIENT_TROJAN_JSON} <<"EOF"
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

create_client_vless_json() {
    cat >${CLIENT_VLESS_JSON} <<"EOF"
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

create_client_tuic_json() {
    cat >${CLIENT_TUIC_JSON} <<"EOF"
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

create_client_hysteria2_json() {
    cat >${CLIENT_HYSTERIA2_JSON} <<"EOF"
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

create_client_dns_rules_json() {
    cat >${CLIENT_DNS_RULES_JSON} <<"EOF"
[
    {
        "outbound": "any",
        "server": "aliyun"
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
                ]
            }
        ],
        "server": "aliyun"
    }
]
EOF
}

create_client_1_8_file() {
   /bin/cp -a ${CLIENT_FILE} ${CLIENT_1_8_FILE}
}

create_client_1_8_patch_dns_json() {
    cat >${CLIENT_1_8_PATCH_DNS_JSON} <<"EOF"
{
    "type": "logical",
    "mode": "and",
    "rules": [
        {
            "rule_set": "geosite-geolocation-!cn",
            "invert": true
        },
        {
            "rule_set": "geosite-cn",
        }
    ],
    "server": "aliyun"
}
EOF
}

create_client_1_8_patch_route_json() {
    cat >${CLIENT_1_8_PATCH_ROUTE_JSON} <<"EOF"
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

# generate client.json content
generate_client() {
    first_domain="$(echo "${DOMAIN}" | awk -F ',' '{print $1}')"
    trojan_tag="Trojan-${NODE_TAG}"
    vless_tag="Vless-${NODE_TAG}"
    tuic_tag="Tuic-${NODE_TAG}"
    hysteria2_tag="Hysteria2-${NODE_TAG}"
    # 创建 client dns rule 1
    create_client_dns_rules_json
    # 创建修改 client trojan 配置
    create_client_trojan_json
    tmp_var=${trojan_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TROJAN_JSON}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TROJAN_JSON}
    tmp_var=${PORT_TROJAN} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TROJAN_JSON}
    tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TROJAN_JSON}
    # 创建修改 client vless 配置
    create_client_vless_json
    tmp_var=${vless_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_VLESS_JSON}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_VLESS_JSON}
    tmp_var=${PORT_VLESS} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_VLESS_JSON}
    tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_VLESS_JSON}
    # 创建修改 client tuic 配置
    create_client_tuic_json
    tmp_var=${tuic_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TUIC_JSON}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TUIC_JSON}
    tmp_var=${PORT_TUIC} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TUIC_JSON}
    tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_TUIC_JSON}
    tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TUIC_JSON}
    # 创建修改 client hysteria2 配置
    create_client_hysteria2_json
    tmp_var=${hysteria2_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_HYSTERIA2_JSON}
    tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_HYSTERIA2_JSON}
    tmp_var=${PORT_HYSTERIA2} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_HYSTERIA2_JSON}
    tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${CLIENT_HYSTERIA2_JSON}
    tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${CLIENT_HYSTERIA2_JSON}
    tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_HYSTERIA2_JSON}
    # 创建修改 client 配置
    create_client_file
    tmp_var=${LOG_LEVEL} yq -ioj '.log.level = strenv(tmp_var)' ${CLIENT_FILE}
    proxy_index=$(yq -Moj '.outbounds[] | select(.tag == "proxy") | key' ${CLIENT_FILE})
    auto_index=$(yq -Moj '.outbounds[] | select(.tag == "auto") | key' ${CLIENT_FILE})
    # add client trojan config
    if [ ${PORT_TROJAN} -ne 0 ]; then
        tmp_var=${CLIENT_TROJAN_JSON} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client vless config
    if [ ${PORT_VLESS} -ne 0 ]; then
        tmp_var=${CLIENT_VLESS_JSON} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client tuic config
    if [ ${PORT_TUIC} -ne 0 ]; then
        tmp_var=${CLIENT_TUIC_JSON} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add client hysteria2 config
    if [ ${PORT_HYSTERIA2} -ne 0 ]; then
        tmp_var=${CLIENT_HYSTERIA2_JSON} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # add clash api config
    if [ ${CLIENT_CLASH_PORT} -ne 0 ]; then
        tmp_var="127.0.0.1:${CLIENT_CLASH_PORT}" yq -ioj '.experimental.clash_api.external_controller = strenv(tmp_var)' ${CLIENT_FILE}
        tmp_var=${CLIENT_CLASH_UI} yq -ioj '.experimental.clash_api.external_ui = strenv(tmp_var)' ${CLIENT_FILE}
    fi
    # change dns rule if not fakeip
    if [ ${CLIENT_DNS_MODE} != 'fakeip' ]; then
        yq -ioj 'del(.dns.servers[] | select(.tag == "remote"))' ${CLIENT_FILE}
        yq -ioj 'del(.dns.rules[] | select(.server == "remote"))' ${CLIENT_FILE}
        yq -ioj 'del(.dns.fakeip)' ${CLIENT_FILE}
        tmp_var=${CLIENT_DNS_RULES_JSON} yq -ioj '.dns.rules = load(strenv(tmp_var))' ${CLIENT_FILE}
    fi
    # Delete temporary files
    rm -f ${CLIENT_TROJAN_JSON} ${CLIENT_VLESS_JSON} ${CLIENT_TUIC_JSON} ${CLIENT_HYSTERIA2_JSON} ${CLIENT_DNS_RULES_JSON}
}

generate_client_1_8() {
    create_client_1_8_patch_dns_json
    create_client_1_8_patch_route_json
    create_client_1_8_file
    if [ ${CLIENT_DNS_MODE} != 'fakeip' ]; then
        tmp_var=${CLIENT_1_8_PATCH_DNS_JSON} yq -ioj '.dns.rules = load(strenv(tmp_var))' ${CLIENT_1_8_FILE}
    fi
    tmp_var=${CLIENT_1_8_PATCH_ROUTE_JSON} yq -ioj '.route = load(strenv(tmp_var))' ${CLIENT_1_8_FILE}
    rm -f ${CLIENT_1_8_PATCH_DNS_JSON} ${CLIENT_1_8_PATCH_ROUTE_JSON}
}

init_variables() {
    # 获取变量, 否则自动生成
    USERNAME="${USERNAME:-$(pwgen 4 1 -s -0)}"
    PASSWORD="${PASSWORD:-$(pwgen 16 1 -s)}"
    UUID="${UUID:-$(sing-box generate uuid)}"
    LOG_LEVEL="${LOG_LEVEL:-warn}"
    NODE_TAG="${NODE_TAG:-$(pwgen 4 1 -s -0 -A)}"
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
    CLIENT_DNS_MODE="${CLIENT_DNS_MODE:-fakeip}"
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

if [ ! -f ${CONFIG_FILE} ]; then
    init_variables
    if [ ${CHECK_DNS} -ne 0 ]; then
        check_domain
    fi
    generate_config
    generate_client
    generate_client_1_8
    echo "secret username: ${USERNAME}"
    echo "secret password: ${PASSWORD}"
    echo "secret uuid: ${UUID}"
    echo "secret vless flow: xtls-rprx-vision"
fi

exec "$@"
