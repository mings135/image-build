#!/bin/sh
set -e

variable_by_const() {
    CONFIG_DIR="/etc/sing-box"
    # server
    SERVER_FILE=${CONFIG_DIR}/config.json
    SERVER_TROJAN=${CONFIG_DIR}/trojan.json
    SERVER_NAIVE=${CONFIG_DIR}/naive.json
    SERVER_VLESS=${CONFIG_DIR}/vless.json
    SERVER_TUIC=${CONFIG_DIR}/tuic.json
    SERVER_HYSTERIA2=${CONFIG_DIR}/hysteria2.json
    # client
    CLIENT_FILE=${CONFIG_DIR}/client.json
    CLIENT_TROJAN=${CONFIG_DIR}/client-trojan.json
    CLIENT_VLESS=${CONFIG_DIR}/client-vless.json
    CLIENT_TUIC=${CONFIG_DIR}/client-tuic.json
    CLIENT_HYSTERIA2=${CONFIG_DIR}/client-hysteria2.json
    CLIENT_ROUTE=${CONFIG_DIR}/client-route.json
    # auto
    VERSION=$(sing-box version | grep 'version' | grep -oE '[0-9]+\.[0-9]+')
}

variable_by_env() {
    # 获取变量, 否则自动生成
    USERNAME="${USERNAME:-$(pwgen 4 1 -s -0)}"
    PASSWORD="${PASSWORD:-$(pwgen 16 1 -s)}"
    UUID="${UUID:-$(sing-box generate uuid)}"
    LEVEL="${LEVEL:-warn}"
    LABEL="${LABEL:-$(pwgen 4 1 -s -0 -A)}"
    # 获取变量, 否则默认为 0, 表示不开启
    TROJAN_PORT="${TROJAN_PORT:-0}"
    NAIVE_PORT="${NAIVE_PORT:-0}"
    VLESS_PORT="${VLESS_PORT:-0}"
    TUIC_PORT="${TUIC_PORT:-0}"
    HYSTERIA2_PORT="${HYSTERIA2_PORT:-0}"
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
}

varialbe_by_auto() {
    ADDRESS_IPV4="$(curl -fsL4 ifconfig.me || echo '')"
    ADDRESS_IPV6="$(curl -fsL6 ifconfig.me || echo '')"
}

compare_version_ge() {
    local ver1_major=$(echo $1 | awk -F '.' '{print $1}')
    local ver1_minor=$(echo $1 | awk -F '.' '{print $2}')
    local ver2_major=$(echo $2 | awk -F '.' '{print $1}')
    local ver2_minor=$(echo $2 | awk -F '.' '{print $2}')
    if [ ${ver1_major} -gt ${ver2_major} ]; then
        return 0
    elif [ ${ver1_major} -eq ${ver2_major} ]; then
        if [ ${ver1_minor} -ge ${ver2_minor} ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

compare_version_le() {
    local ver1_major=$(echo $1 | awk -F '.' '{print $1}')
    local ver1_minor=$(echo $1 | awk -F '.' '{print $2}')
    local ver2_major=$(echo $2 | awk -F '.' '{print $1}')
    local ver2_minor=$(echo $2 | awk -F '.' '{print $2}')
    if [ ${ver1_major} -lt ${ver2_major} ]; then
        return 0
    elif [ ${ver1_major} -eq ${ver2_major} ]; then
        if [ ${ver1_minor} -le ${ver2_minor} ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# ------ server ------
server_create_trojan() {
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

server_create_naive() {
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

server_create_vless() {
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

server_create_tuic() {
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

server_create_hysteria2() {
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

server_create_config() {
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

# server generate config.json content
server_generate_config() {
    if [ ! -e ${CONFIG_DIR} ]; then
        mkdir -p ${CONFIG_DIR}
    fi
    
    # server config basic
    server_create_config
    tmp_var=${LEVEL} yq -ioj '.log.level = strenv(tmp_var)' ${SERVER_FILE}

    # trojan config
    if [ ${TROJAN_PORT} -ne 0 ]; then
        server_create_trojan
        tmp_var=${TROJAN_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TROJAN}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TROJAN}
        if [ ${TROJAN_FALLBACK_PORT} -ne 0 ]; then
            tmp_var=${TROJAN_FALLBACK_SERVER} yq -ioj '.fallback.server = strenv(tmp_var)' ${SERVER_TROJAN}
            tmp_var=${TROJAN_FALLBACK_PORT} yq -ioj '.fallback.server_port = env(tmp_var)' ${SERVER_TROJAN}
            yq -ioj 'del(.tls.alpn[] | select(. == "h2"))' ${SERVER_TROJAN}
        fi
        # server config change
        tmp_var=${SERVER_TROJAN} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
        rm ${SERVER_TROJAN}
    fi

    # naive config
    if [ ${NAIVE_PORT} -ne 0 ]; then
        server_create_naive
        tmp_var=${NAIVE_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_NAIVE}
        tmp_var=${USERNAME} yq -ioj '.users[0].username = strenv(tmp_var)' ${SERVER_NAIVE}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_NAIVE}
        # server config change
        tmp_var=${SERVER_NAIVE} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
        rm ${SERVER_NAIVE}
    fi

    # vless config
    if [ ${VLESS_PORT} -ne 0 ]; then
        server_create_vless
        tmp_var=${VLESS_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_VLESS}
        tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${SERVER_VLESS}
        # server config change
        tmp_var=${SERVER_VLESS} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
        rm ${SERVER_VLESS}
    fi

    # tuic config
    if [ ${TUIC_PORT} -ne 0 ]; then
        server_create_tuic
        tmp_var=${TUIC_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TUIC}
        tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${SERVER_TUIC}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TUIC}
        # server config change
        tmp_var=${SERVER_TUIC} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
        rm ${SERVER_TUIC}
    fi

    # hysteria2 config
    if [ ${HYSTERIA2_PORT} -ne 0 ]; then
        server_create_hysteria2
        tmp_var=${HYSTERIA2_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_HYSTERIA2}
        tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${SERVER_HYSTERIA2}
        tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${SERVER_HYSTERIA2}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_HYSTERIA2}
        # server config change
        tmp_var=${SERVER_HYSTERIA2} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
        rm ${SERVER_HYSTERIA2}
    fi

    # server config modify about tls
    for i in $(echo "${DOMAIN}" | awk -F ',' '{for(i=1;i<=NF;i++) print $i}')
    do
        tmp_var=${i} yq -ioj '.inbounds[].tls.acme.domain += strenv(tmp_var)' ${SERVER_FILE}
    done
    tmp_var=${EMAIL} yq -ioj '.inbounds[].tls.acme.email = strenv(tmp_var)' ${SERVER_FILE}
}

# ------ client ------
client_create_trojan() {
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

client_create_vless() {
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

client_create_tuic() {
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

client_create_hysteria2() {
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

client_create_config() {
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
            "inet6_address": "fdfe::1/126",
            "mtu": 1492,
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
            "outbounds": [],
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
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "store_fakeip": true
        }
    }
}
EOF
}

client_create_route() {
    cat >${CLIENT_ROUTE} <<"EOF"
{
    "rule_set": [
        {
            "type": "remote",
            "tag": "geoip-cn",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs",
            "download_detour": "proxy"
        },
        {
            "type": "remote",
            "tag": "geosite-cn",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs",
            "download_detour": "proxy"
        },
        {
            "type": "remote",
            "tag": "geosite-geolocation-!cn",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs",
            "download_detour": "proxy"
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

client_generate_config() {
    local first_domain="$(echo "${DOMAIN}" | awk -F ',' '{print $1}')"
    local trojan_tag="Trojan-${LABEL}"
    local vless_tag="Vless-${LABEL}"
    local tuic_tag="Tuic-${LABEL}"
    local hysteria2_tag="Hysteria2-${LABEL}"
    
    # client config basic
    client_create_config
    tmp_var=${LEVEL} yq -ioj '.log.level = strenv(tmp_var)' ${CLIENT_FILE}
    local proxy_index=$(yq -roj '.outbounds[] | select(.tag == "proxy") | key' ${CLIENT_FILE})
    local auto_index=$(yq -roj '.outbounds[] | select(.tag == "auto") | key' ${CLIENT_FILE})

    # client route config
    client_create_route
    tmp_var=${CLIENT_ROUTE} yq -ioj '.route = load(strenv(tmp_var))' ${CLIENT_FILE}
    rm ${CLIENT_ROUTE}
    
    # client trojan
    if [ ${TROJAN_PORT} -ne 0 ]; then
        client_create_trojan
        tmp_var=${trojan_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TROJAN}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TROJAN}
        tmp_var=${TROJAN_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TROJAN}
        tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TROJAN}
        # client config change
        tmp_var=${CLIENT_TROJAN} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        rm ${CLIENT_TROJAN}
    fi

    # client vless
    if [ ${VLESS_PORT} -ne 0 ]; then
        client_create_vless
        tmp_var=${vless_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_VLESS}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_VLESS}
        tmp_var=${VLESS_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_VLESS}
        tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_VLESS}
        # client config change
        tmp_var=${CLIENT_VLESS} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        rm ${CLIENT_VLESS}
    fi

    # client tuic
    if [ ${TUIC_PORT} -ne 0 ]; then
        client_create_tuic
        tmp_var=${tuic_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TUIC}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TUIC}
        tmp_var=${TUIC_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TUIC}
        tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_TUIC}
        tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TUIC}
        # client config change
        tmp_var=${CLIENT_TUIC} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        rm ${CLIENT_TUIC}
    fi

    # client hysteria2
    if [ ${HYSTERIA2_PORT} -ne 0 ]; then
        client_create_hysteria2
        tmp_var=${hysteria2_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_HYSTERIA2}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_HYSTERIA2}
        tmp_var=${HYSTERIA2_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_HYSTERIA2}
        tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${CLIENT_HYSTERIA2}
        tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${CLIENT_HYSTERIA2}
        tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_HYSTERIA2}
        # client config change
        tmp_var=${CLIENT_HYSTERIA2} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        rm ${CLIENT_HYSTERIA2}
    fi

    # client clash_api
    if [ ${CLIENT_CLASH_PORT} -ne 0 ]; then
        tmp_var="127.0.0.1:${CLIENT_CLASH_PORT}" yq -ioj '.experimental.clash_api.external_controller = strenv(tmp_var)' ${CLIENT_FILE}
        tmp_var="${CLIENT_CLASH_UI}" yq -ioj '.experimental.clash_api.external_ui = strenv(tmp_var)' ${CLIENT_FILE}
    fi
    
    # Deprecated changes about sing-box v1.10
    if compare_version_ge "${VERSION}" "1.10"; then
        yq -ioj 'del(.inbounds[0].inet4_address)' ${CLIENT_FILE}
        yq -ioj 'del(.inbounds[0].inet6_address)' ${CLIENT_FILE}
        yq -ioj '.inbounds[0].address[0] = "172.19.0.1/30"' ${CLIENT_FILE}
        yq -ioj '.inbounds[0].address[1] = "fdfe::1/126"' ${CLIENT_FILE}
    fi 
}

check_variable() {
    # 检查 version
    if compare_version_le "${VERSION}" "1.7"; then
        echo "Sing-box version need >= 1.8"
        exit 1
    fi
    # 必须配置 domain
    if [ ! "${DOMAIN}" ]; then
        echo "DOMAIN environment variables must be set"
        exit 1
    fi
    # 必须配置 email
    if [ ! "${EMAIL}" ]; then
        echo "EMAIL environment variables must be set"
        exit 1
    fi
    # 检查 port
    if ! echo "${TROJAN_PORT}${NAIVE_PORT}${VLESS_PORT}${TUIC_PORT}${HYSTERIA2_PORT}" | grep -Eqi '^[[:digit:]]*$'; then
        echo "Port must be a number"
        exit 1
    fi
    # 如果未设置 port，默认开启 trojan，端口 443
    local tmp_sum=$((TROJAN_PORT + NAIVE_PORT + VLESS_PORT + TUIC_PORT + HYSTERIA2_PORT))
    if [ ${tmp_sum} -eq 0 ]; then
        TROJAN_PORT=443
    fi
}

check_one_domain() {
    local tmp_domain="$1"

    while true; do
        if [ ${ADDRESS_IPV4} ] && dig A ${tmp_domain} +short | grep -Eqi "${ADDRESS_IPV4}"; then
            break
        fi
        if [ ${ADDRESS_IPV6} ] && dig AAAA ${tmp_domain} +short | grep -Eqi "${ADDRESS_IPV6}"; then
            break
        fi
        echo "DNS resolution mismatch ${tmp_domain}!"
        sleep 30
    done
}

check_domain() {
    while true; do
        if [ ${ADDRESS_IPV4} ] || [ ${ADDRESS_IPV6} ]; then
            break
        else
            echo "Unable to obtain the local public IP address!"
            sleep 60
        fi
    done

    for i in $(echo ${DOMAIN} | awk -F ',' '{for(i=1;i<=NF;i++){print $i}}')
    do
        check_one_domain "$i"
    done
}

main() {
    variable_by_const
    if [ ! -f ${SERVER_FILE} ]; then
        variable_by_env
        varialbe_by_auto
        check_variable
        if [ ${CHECK_DNS} -eq 1 ]; then
            check_domain
        fi
        server_generate_config
        if [ ${DOMAIN} ]; then
            client_generate_config
        fi
        echo "Network ipv4 address: ${ADDRESS_IPV4}"
        echo "Network ipv6 address: ${ADDRESS_IPV6}"
        echo "Secret username: ${USERNAME}"
        echo "Secret password: ${PASSWORD}"
        echo "Secret uuid: ${UUID}"
        echo "Secret vless flow: xtls-rprx-vision"
    fi
}

main
exec "$@"
