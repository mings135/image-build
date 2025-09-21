# Image Build

构建 docker images 上传到 docker hub



**Debian 12、13**

- fail2ban 安装，关闭 IPV6，优化 vi 命令，开启 BBR

```shell
cat > debian12-opt.sh <<"EOF"
set -e
apt-get update && apt-get install -y vim fail2ban rsyslog iptables

if cat /etc/issue | grep -q "Linux 12"; then
	sed -i 's/mouse=a/mouse-=a/' /usr/share/vim/vim90/defaults.vim
elif cat /etc/issue | grep -q "Linux 13"; then
	sed -i 's/mouse=a/mouse-=a/' /usr/share/vim/vim91/defaults.vim
fi

{ \
    echo "net.ipv6.conf.all.disable_ipv6 = 1"; \
    echo "net.ipv6.conf.default.disable_ipv6 = 1"; \
} > /etc/sysctl.d/90-disable-ipv6.conf
if ! sysctl -a | grep -q "net.ipv4.tcp_congestion_control = bbr"; then
	{ \
        echo "net.core.default_qdisc = fq"; \
        echo "net.ipv4.tcp_congestion_control = bbr"; \
    }  > /etc/sysctl.d/90-bbr.conf
fi
sysctl --system

sed -e 's/maxretry = 5/maxretry = 3/' \
    -e 's/findtime  = 10m/findtime  = 90d/' \
    -e 's/bantime  = 10m/bantime  = 90d/' \
    -i /etc/fail2ban/jail.conf

echo "当前 faile2ban 部分配置："
grep -E 'maxretry = 3|findtime  = 90d|bantime  = 90d' /etc/fail2ban/jail.conf
echo "当前 bbr 设置："
sysctl -a | grep default_qdisc
sysctl -a | grep tcp_congestion_control
echo "手动 reboot 重启系统"
EOF
bash debian12-opt.sh && rm debian12-opt.sh
```



- docker 安装

```shell
cat > debian12-docker.sh <<"EOF"
set -e
apt-get update && apt-get install -y ca-certificates curl gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-compose-plugin
EOF
bash debian12-docker.sh && rm debian12-docker.sh
```



## Sing-box

**构建 sing-box image**

- 源码来源：https://github.com/SagerNet/sing-box
- 正式版本，自动更新

- docker-compose.yaml

```yaml
services:
  sing-box:
    container_name: sing-box
    image: mings135/sing-box:latest
    restart: always
    environment:
      - DOMAIN=example.com
      - EMAIL=user@gmail.com
      - PASSWORD=pwd
    network_mode: "host"
    volumes:
      - ./certs:/root/.local/share/certmagic
```



- Configuration

| **Parameter**       | **Description**                                       |
| ------------------- | ----------------------------------------------------- |
| DOMAIN              | 域名（必须）                                          |
| EMAIL               | 用于申请证书（必须）                                  |
| USERNAME            | 用户名，默认随机（重启重置）                          |
| PASSWORD            | 密码，默认随机（重启重置）                            |
| UUID                | uuid，默认随机（重启重置）                            |
| LEVEL               | 日志级别，默认 warn                                   |
| LABEL               | 节点标签，用于区分不同节点的配置，默认随机            |
| CHECK_DNS           | 运行 Server 前，检查域名解析，默认 1(开启)            |
| TROJAN_PORT         | Trojan 端口，默认 0(关闭) or 443(无任何其他服务开启)  |
| NAIVE_PORT          | Naive 端口，默认 0(关闭)                              |
| VLESS_PORT          | Vless 端口，默认 0(关闭)                              |
| TUIC_PORT           | Tuic 端口，默认 0(关闭)                               |
| HYSTERIA2_PORT      | Hysteria2 端口，默认 0(关闭)                          |
| HYSTERIA_UP_SPEED   | Hysteria2 上传端口速率(Mbps)，默认 100                |
| HYSTERIA_DOWN_SPEED | Hysteria2 下载端口速率(Mbps)，默认 100                |
| CLIENT_CLASH_PORT   | clash api 端口（client.json），默认 9090              |
| CLIENT_CLASH_UI     | clash api URI，默认 ui                                |
| SUB_API_URL         | Subscribe 服务的 URL，用于上传 client.json，整合配置  |
| SUB_API_TOKEN       | Subscribe 服务的 Token，用于上传 client.json          |
| SUB_UPLOAD_LEVEL    | 0=不上传，1=仅 1 次(默认)，2=每日 1 次，3=每小时 1 次 |



**其他相关命令**

```shell
# 查看账密等信息（如果没有设置相应的变量，重启后会重置）
docker compose logs | grep -Ei 'network|secret'

# 查看 sing-box client.json config
docker compose exec sing-box yq -oj /etc/sing-box/client.json

# 查看 sing-box client.json config about outbounds
docker compose exec sing-box yq -oj '.outbounds[] | select(.tag == "*-*")' /etc/sing-box/client.json
```



**Windows bat  启动脚本 sing-box.bat**

- 同一目录下包含：sing-box.exe、client.json、sing-box.bat
- sing-box.exe 官方获取，client.json 使用上面命令获取，也可以通过 Subscribe 服务获取

- sing-box.bat 自行创建，内容如下，同时创建 sing-box.bat 的桌面快捷方式，修改快捷方式高级属性，用管理员方式运行，启动直接运行快捷方式即可

 ```bat
 cd /d %~dp0
 start /min sing-box.exe run -c client.json
 ```



## Nginx-proxy

**构建 nginx-proxy image**

- 在官方 nginx:*-alpine 修改版，用于 sing-box + web 的代理

- 手动更新，仅代理 HTTPS/SSL

- docker-compose.yaml

```yaml
services:
  nginx:
    container_name: nginx
    image: mings135/nginx-proxy:latest
    restart: always
    ports:
      - 443:443
    environment:
      - PROXY1=app,aa.example.com,10.1.1.10:80
      - PROXY2=http,bb.example.com,10.1.1.20:443
    networks:
      - net
    volumes:
      - ./certs:/etc/nginx/certs

networks:
  net:
    ipam:
      driver: default
      config:
        - subnet: "10.6.6.0/24"
```



- Configuration

| **Parameter** | **Description**                                              |
| ------------- | ------------------------------------------------------------ |
| PROXY1        | 代理条目，格式：type,domain:destination（必须）              |
| PROXY2~9      | 连续、同上            type: app=4层代理，http=7层代理（需要挂载证书） |
| CERT_SOURCE   | sing-box(default) or certbot，证书来源（可选）               |
|               | sing-box: /root/.local/share/certmagic 和 /etc/nginx/certs 挂载到同一目录 |
|               | certbot: /etc/letsencrypt:/etc/nginx/certs                   |

