#!/bin/sh
set -e

variable_by_const() {
    CONFIG_DIR="/etc/sing-box"
    # server
    SERVER_FILE=${CONFIG_DIR}/config.json
    SERVER_TMP=/tmp/server-tmp.json
    # client
    CLIENT_FILE=${CONFIG_DIR}/client.json
    CLIENT_TMP=/tmp/client-tmp.json
    # vless
    VLESS_FLOW="xtls-rprx-vision"
    # auto
    VERSION=$(sing-box version | grep 'version' | grep -oE '[0-9]+\.[0-9]+')
}

variable_by_env() {
    local tmp_keypair=$(sing-box generate reality-keypair | sed 'Ns/\n/ /')
    local tmp_private=$(echo "${tmp_keypair}" | awk '{print $2}')
    local tmp_public=$(echo "${tmp_keypair}" | awk '{print $NF}')
    # reality variable
    PUBLIC_KEY=${PUBLIC_KEY:-"${tmp_public}"}
    PRIVATE_KEY=${PRIVATE_KEY:-"${tmp_private}"}
    SHORT_ID=${SHORT_ID:-"$(sing-box generate rand 8 --hex)"}
    REALITY_DOMAIN=${REALITY_DOMAIN:-"www.microsoft.com"}
    # 获取变量, 否则自动生成
    USERNAME=${USERNAME:-"$(pwgen 4 1 -s -0)"}
    PASSWORD=${PASSWORD:-"$(pwgen 16 1 -s)"}
    UUID=${UUID:-"$(sing-box generate uuid)"}
    LEVEL=${LEVEL:-"warn"}
    LABEL=${LABEL:-"$(pwgen 4 1 -s -0 -A)"}
    # 获取变量, 否则默认为 0, 表示不开启
    TROJAN_PORT=${TROJAN_PORT:-"0"}
    VLESS_PORT=${VLESS_PORT:-"0"}
    TUIC_PORT=${TUIC_PORT:-"0"}
    HYSTERIA2_PORT=${HYSTERIA2_PORT:-"0"}
    # 额外配置
    HYSTERIA_UP_SPEED=${HYSTERIA_UP_SPEED:-"100"}
    HYSTERIA_DOWN_SPEED=${HYSTERIA_DOWN_SPEED:-"100"}
    # 客户端配置
    CLIENT_CLASH_PORT=${CLIENT_CLASH_PORT:-"9090"}
    CLIENT_CLASH_UI=${CLIENT_CLASH_UI:-"ui"}
    # 检查
    CHECK_DNS=${CHECK_DNS:-"1"}
    # Upload client.json
    SUB_UPLOAD_LEVEL=${SUB_UPLOAD_LEVEL:-"1"}
}

varialbe_by_auto() {
    ADDRESS_IPV4=$(curl -fsL4 ifconfig.me || echo '')
    ADDRESS_IPV6=$(curl -fsL6 ifconfig.me || echo '')
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

# ------ server ------
server_create_trojan() {
    cat >${SERVER_TMP} <<"EOF"
{
  "type": "trojan",
  "tag": "trojan-in",
  "listen": "::",
  "listen_port": 443,
  "users": [
    {
      "password": ""
    }
  ],
  "tls": {
    "enabled": true,
    "alpn": ["h2", "http/1.1"],
    "acme": {
      "domain": [],
      "email": "",
      "provider": "letsencrypt"
    }
  },
  "multiplex": {
    "enabled": true
  }
}
EOF
}

server_create_vless() {
    cat >${SERVER_TMP} <<"EOF"
{
  "type": "vless",
  "tag": "vless-in",
  "listen": "::",
  "listen_port": 443,
  "users": [
    {
      "uuid": "",
      "flow": ""
    }
  ],
  "tls": {
    "enabled": true,
    "server_name": "",
    "reality": {
      "enabled": true,
      "handshake": {
        "server": "",
        "server_port": 443
      },
      "private_key": "",
      "short_id": []
    }
  }
}
EOF
}

server_create_tuic() {
    cat >${SERVER_TMP} <<"EOF"
{
  "type": "tuic",
  "tag": "tuic-in",
  "listen": "::",
  "listen_port": 443,
  "users": [
    {
      "uuid": "",
      "password": ""
    }
  ],
  "congestion_control": "bbr",
  "tls": {
    "enabled": true,
    "alpn": ["h3"],
    "acme": {
      "domain": [],
      "email": "",
      "provider": "letsencrypt"
    }
  }
}
EOF
}

server_create_hysteria2() {
    cat >${SERVER_TMP} <<"EOF"
{
  "type": "hysteria2",
  "tag": "hysteria2-in",
  "listen": "::",
  "listen_port": 443,
  "up_mbps": 100,
  "down_mbps": 100,
  "users": [
    {
      "password": ""
    }
  ],
  "tls": {
    "enabled": true,
    "alpn": ["h3"],
    "acme": {
      "domain": [],
      "email": "",
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
        tmp_var=${TROJAN_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TMP}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TMP}
        for i in $(echo "${DOMAIN}" | awk -F ',' '{for(i=1;i<=NF;i++) print $i}')
        do
            tmp_var=${i} yq -ioj '.tls.acme.domain += strenv(tmp_var)' ${SERVER_TMP}
        done
        tmp_var=${EMAIL} yq -ioj '.tls.acme.email = strenv(tmp_var)' ${SERVER_TMP}
        # server config change
        tmp_var=${SERVER_TMP} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi

    # vless config
    if [ ${VLESS_PORT} -ne 0 ]; then
        server_create_vless
        tmp_var=${VLESS_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TMP}
        tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${SERVER_TMP}
        tmp_var=${VLESS_FLOW} yq -ioj '.users[0].flow = strenv(tmp_var)' ${SERVER_TMP}
        tmp_var=${REALITY_DOMAIN} yq -ioj '.tls.server_name = strenv(tmp_var)' ${SERVER_TMP}
        tmp_var=${REALITY_DOMAIN} yq -ioj '.tls.reality.handshake.server = strenv(tmp_var)' ${SERVER_TMP}
        tmp_var=${PRIVATE_KEY} yq -ioj '.tls.reality.private_key = strenv(tmp_var)' ${SERVER_TMP}
        tmp_var=${SHORT_ID} yq -ioj '.tls.reality.short_id += strenv(tmp_var)' ${SERVER_TMP}
        # server config change
        tmp_var=${SERVER_TMP} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi

    # tuic config
    if [ ${TUIC_PORT} -ne 0 ]; then
        server_create_tuic
        tmp_var=${TUIC_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TMP}
        tmp_var=${UUID} yq -ioj '.users[0].uuid = strenv(tmp_var)' ${SERVER_TMP}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TMP}
        for i in $(echo "${DOMAIN}" | awk -F ',' '{for(i=1;i<=NF;i++) print $i}')
        do
            tmp_var=${i} yq -ioj '.tls.acme.domain += strenv(tmp_var)' ${SERVER_TMP}
        done
        tmp_var=${EMAIL} yq -ioj '.tls.acme.email = strenv(tmp_var)' ${SERVER_TMP}
        # server config change
        tmp_var=${SERVER_TMP} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi

    # hysteria2 config
    if [ ${HYSTERIA2_PORT} -ne 0 ]; then
        server_create_hysteria2
        tmp_var=${HYSTERIA2_PORT} yq -ioj '.listen_port = env(tmp_var)' ${SERVER_TMP}
        tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${SERVER_TMP}
        tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${SERVER_TMP}
        tmp_var=${PASSWORD} yq -ioj '.users[0].password = strenv(tmp_var)' ${SERVER_TMP}
        for i in $(echo "${DOMAIN}" | awk -F ',' '{for(i=1;i<=NF;i++) print $i}')
        do
            tmp_var=${i} yq -ioj '.tls.acme.domain += strenv(tmp_var)' ${SERVER_TMP}
        done
        tmp_var=${EMAIL} yq -ioj '.tls.acme.email = strenv(tmp_var)' ${SERVER_TMP}
        # server config change
        tmp_var=${SERVER_TMP} yq -ioj '.inbounds += load(strenv(tmp_var))' ${SERVER_FILE}
    fi
}

# ------ client ------
client_create_trojan() {
    cat >${CLIENT_TMP} <<"EOF"
{
  "type": "trojan",
  "tag": "trojan-out",
  "server": "",
  "server_port": 443,
  "password": "",
  "tls": {
    "enabled": true,
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    }
  },
  "multiplex": {
    "enabled": true
  }
}
EOF
}

client_create_vless() {
    cat >${CLIENT_TMP} <<"EOF"
{
  "type": "vless",
  "tag": "vless-out",
  "server": "",
  "server_port": 443,
  "uuid": "",
  "flow": "",
  "tls": {
    "enabled": true,
    "server_name": "",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "",
      "short_id": ""
    }
  },
  "packet_encoding": "xudp"
}
EOF
}

client_create_tuic() {
    cat >${CLIENT_TMP} <<"EOF"
{
  "type": "tuic",
  "tag": "tuic-out",
  "server": "",
  "server_port": 443,
  "uuid": "",
  "password": "",
  "congestion_control": "bbr",
  "tls": {
    "enabled": true,
    "alpn": ["h3"]
  }
}
EOF
}

client_create_hysteria2() {
    cat >${CLIENT_TMP} <<"EOF"
{
  "type": "hysteria2",
  "tag": "hysteria2-out",
  "server": "",
  "server_port": 443,
  "up_mbps": 100,
  "down_mbps": 100,
  "password": "",
  "tls": {
    "enabled": true,
    "alpn": ["h3"]
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
  "dns": {},
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "tun0",
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "address": ["172.19.0.1/30", "fdfe::1/126"]
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
    }
  ],
  "route": {},
  "experimental": {}
}
EOF
}

client_create_dns() {
    cat >${CLIENT_TMP} <<"EOF"
{
  "servers": [
    {
      "tag": "google",
      "type": "tls",
      "server": "8.8.4.4"
    },
    {
      "tag": "local",
      "type": "udp",
      "server": "223.5.5.5"
    },
    {
      "tag": "remote",
      "type": "fakeip",
      "inet4_range": "198.18.0.0/15",
      "inet6_range": "fc00::/18"
    }
  ],
  "rules": [
    {
      "query_type": ["A", "AAAA"],
      "server": "remote"
    }
  ],
  "independent_cache": true,
  "strategy": "ipv4_only"
}
EOF
}

client_create_route() {
    cat >${CLIENT_TMP} <<"EOF"
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
      "tag": "geosite-geolocation-cn",
      "format": "binary",
      "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-cn.srs",
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
    { "action": "sniff" },
    {
      "type": "logical",
      "mode": "or",
      "rules": [{ "protocol": "dns" }, { "port": 53 }],
      "action": "hijack-dns"
    },
    {
      "ip_is_private": true,
      "outbound": "direct"
    },
    {
      "type": "logical",
      "mode": "or",
      "rules": [
        { "port": 853 },
        {
          "network": "udp",
          "port": 443
        },
        { "protocol": "stun" }
      ],
      "action": "reject"
    },
    {
      "rule_set": "geosite-geolocation-cn",
      "outbound": "direct"
    },
    {
      "type": "logical",
      "mode": "and",
      "rules": [
        { "rule_set": "geoip-cn" },
        {
          "rule_set": "geosite-geolocation-!cn",
          "invert": true
        }
      ],
      "outbound": "direct"
    }
  ],
  "final": "proxy",
  "auto_detect_interface": true,
  "default_domain_resolver": "local"
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

    # client dns config
    client_create_dns
    tmp_var=${CLIENT_TMP} yq -ioj '.dns = load(strenv(tmp_var))' ${CLIENT_FILE}

    # client route config
    client_create_route
    tmp_var=${CLIENT_TMP} yq -ioj '.route = load(strenv(tmp_var))' ${CLIENT_FILE}

    # client cache_file
    tmp_var="true" yq -ioj '.experimental.cache_file.enabled = env(tmp_var)' ${CLIENT_FILE}
    tmp_var="true" yq -ioj '.experimental.cache_file.store_rdrc = env(tmp_var)' ${CLIENT_FILE}
    
    # client trojan
    if [ ${TROJAN_PORT} -ne 0 ]; then
        client_create_trojan
        tmp_var=${trojan_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${TROJAN_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TMP}
        tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TMP}
        # client config change
        tmp_var=${CLIENT_TMP} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${trojan_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi

    # client vless
    if [ ${VLESS_PORT} -ne 0 ]; then
        client_create_vless
        tmp_var=${vless_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${VLESS_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TMP}
        tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${VLESS_FLOW} yq -ioj '.flow = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${REALITY_DOMAIN} yq -ioj '.tls.server_name = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${PUBLIC_KEY} yq -ioj '.tls.reality.public_key = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${SHORT_ID} yq -ioj '.tls.reality.short_id = strenv(tmp_var)' ${CLIENT_TMP}
        # client config change
        tmp_var=${CLIENT_TMP} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${vless_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi

    # client tuic
    if [ ${TUIC_PORT} -ne 0 ]; then
        client_create_tuic
        tmp_var=${tuic_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${TUIC_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TMP}
        tmp_var=${UUID} yq -ioj '.uuid = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TMP}
        # client config change
        tmp_var=${CLIENT_TMP} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${tuic_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi

    # client hysteria2
    if [ ${HYSTERIA2_PORT} -ne 0 ]; then
        client_create_hysteria2
        tmp_var=${hysteria2_tag} yq -ioj '.tag = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${first_domain} yq -ioj '.server = strenv(tmp_var)' ${CLIENT_TMP}
        tmp_var=${HYSTERIA2_PORT} yq -ioj '.server_port = env(tmp_var)' ${CLIENT_TMP}
        tmp_var=${HYSTERIA_UP_SPEED} yq -ioj '.up_mbps = env(tmp_var)' ${CLIENT_TMP}
        tmp_var=${HYSTERIA_DOWN_SPEED} yq -ioj '.down_mbps = env(tmp_var)' ${CLIENT_TMP}
        tmp_var=${PASSWORD} yq -ioj '.password = strenv(tmp_var)' ${CLIENT_TMP}
        # client config change
        tmp_var=${CLIENT_TMP} yq -ioj '.outbounds += load(strenv(tmp_var))' ${CLIENT_FILE}
        tmp_key=${proxy_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
        tmp_key=${auto_index} tmp_var=${hysteria2_tag} yq -ioj '.outbounds[env(tmp_key)].outbounds += strenv(tmp_var)' ${CLIENT_FILE}
    fi

    # client clash_api
    if [ ${CLIENT_CLASH_PORT} -ne 0 ]; then
        tmp_var="127.0.0.1:${CLIENT_CLASH_PORT}" yq -ioj '.experimental.clash_api.external_controller = strenv(tmp_var)' ${CLIENT_FILE}
        tmp_var="${CLIENT_CLASH_UI}" yq -ioj '.experimental.clash_api.external_ui = strenv(tmp_var)' ${CLIENT_FILE}
    fi   
}

client_deprecated_changes() {
    # Deprecated changes about sing-box v1.13
    if compare_version_ge "${VERSION}" "1.13"; then
        echo "no changes about sing-box v1.13"
    fi
}


check_variable() {
    # 检查 version
    if ! compare_version_ge "${VERSION}" "1.12"; then
        echo "Sing-box version need >= 1.12"
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
    if ! echo "${TROJAN_PORT}${VLESS_PORT}${TUIC_PORT}${HYSTERIA2_PORT}" | grep -Eqi '^[[:digit:]]*$'; then
        echo "Port must be a number"
        exit 1
    fi
    # 如果未设置 port，默认开启 trojan，端口 443
    local tmp_sum=$((TROJAN_PORT + VLESS_PORT + TUIC_PORT + HYSTERIA2_PORT))
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

upload_client_config() {
    local tmp_name="subscribe.sh"
    local cron_file
    if [ ${SUB_UPLOAD_LEVEL} -eq 3 ]; then
        cron_file="/etc/periodic/hourly/${tmp_name}"
    elif [ ${SUB_UPLOAD_LEVEL} -eq 2 ]; then
        cron_file="/etc/periodic/daily/${tmp_name}"
    else
        cron_file="/tmp/${tmp_name}"
    fi

    cat >${cron_file} <<EOF
#!/bin/sh
SUB_API_TOKEN="${SUB_API_TOKEN}"
SUB_API_URL="${SUB_API_URL}"
CLIENT_FILE="${CLIENT_FILE}"
ATTEMPT_COUNT=3
EOF

    cat >>${cron_file} <<'EOF'
for i in $(seq 1 ${ATTEMPT_COUNT}); do
    curl -fsSL -H "Authorization: Bearer ${SUB_API_TOKEN}" -H 'content-type: application/json' -X POST ${SUB_API_URL} -d @${CLIENT_FILE}
    if [ $? -eq 0 ]; then
        echo "$(date +"%Y/%m/%d %H:%M"): Upload success" >> /tmp/upload-config.log
        break
    fi
    echo "$(date +"%Y/%m/%d %H:%M"): Upload failed" >> /tmp/upload-config.log
    if [ $i -ne ${ATTEMPT_COUNT} ]; then
        sleep 20
    fi
done
EOF

    chmod +x ${cron_file}
    if [ ${SUB_UPLOAD_LEVEL} -ge 1 ]; then
        ${cron_file}
    fi
    if [ ${SUB_UPLOAD_LEVEL} -ge 2 ]; then
        crond
    fi
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
        client_generate_config
        client_deprecated_changes
        echo "Network ipv4 address: ${ADDRESS_IPV4}"
        echo "Network ipv6 address: ${ADDRESS_IPV6}"
        echo "Secret username: ${USERNAME}"
        echo "Secret password: ${PASSWORD}"
        echo "Secret uuid: ${UUID}"
        echo "Secret vless flow: ${VLESS_FLOW}"
        echo "Secret public key: ${PUBLIC_KEY}"
        echo "Secret private key: ${PRIVATE_KEY}"
        echo "Secret short id: ${SHORT_ID}"
        echo "Secret reality domain: ${REALITY_DOMAIN}"
    fi

    if [ -e ${CLIENT_FILE} ] && [ "${SUB_API_TOKEN}" ] && [ "${SUB_API_URL}" ]; then
        upload_client_config
    fi
}

main
exec "$@"
