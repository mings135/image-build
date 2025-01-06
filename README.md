# Image Build

构建 docker images 上传到 docker hub



**Debian 12**

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



- fail2ban 安装，关闭 IPV6，优化 vi 命令（运行后需要重启）

```shell
cat > debian12-opt.sh <<"EOF"
set -e
sed -i 's/mouse=a/mouse-=a/' /usr/share/vim/vim90/defaults.vim
{ \
echo "net.ipv6.conf.all.disable_ipv6 = 1"; \
echo "net.ipv6.conf.default.disable_ipv6 = 1"; \
} > /etc/sysctl.d/90-disable-ipv6.conf
sysctl --system
apt-get update && apt-get install -y fail2ban rsyslog iptables
sed -e 's/maxretry = 5/maxretry = 3/' \
    -e 's/findtime  = 10m/findtime  = 90d/' \
    -e 's/bantime  = 10m/bantime  = 90d/' \
    -i /etc/fail2ban/jail.conf
grep -E 'maxretry = 3|findtime  = 90d|bantime  = 90d' /etc/fail2ban/jail.conf
EOF
bash debian12-opt.sh && rm debian12-opt.sh
```



**Almalinux9**

- docker

```shell
cat > almalinux9-docker.sh <<"EOF"
set -e
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-compose-plugin
EOF
bash almalinux9-docker.sh && rm almalinux9-docker.sh
```



## Sing-box

**构建 sing-box image**

- 源码来源：https://github.com/SagerNet/sing-box
- 每日检查正式版本，隔日自动更新

- docker-compose.yaml

```yaml
services:
  sing-box:
    container_name: sing-box
    image: mings135/sing-box:latest
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - DOMAIN=example.com
      - EMAIL=user@gmail.com
      - PASSWORD=pwd
    network_mode: "host"
    volumes:
      - ./certs:/root/.local/share/certmagic
```



- Configuration

| **Parameter**       | **Description**                                      |
| ------------------- | ---------------------------------------------------- |
| DOMAIN              | 域名（必须）                                         |
| EMAIL               | 用于申请证书（必须）                                 |
| USERNAME            | 用户名，默认随机（重启重置）                         |
| PASSWORD            | 密码，默认随机（重启重置）                           |
| UUID                | uuid，默认随机（重启重置）                           |
| LEVEL               | 日志级别，默认 warn                                  |
| LABEL               | 节点标签（client.json），默认随机                    |
| CHECK_DNS           | 运行 Server 前，检查域名解析，默认 1(开启)           |
| TROJAN_PORT         | Trojan 端口，默认 0(关闭) or 443(无任何其他服务开启) |
| NAIVE_PORT          | Naive 端口，默认 0(关闭)                             |
| VLESS_PORT          | Vless 端口，默认 0(关闭)                             |
| TUICPORT            | Tuic 端口，默认 0(关闭)                              |
| HYSTERIA2_PORT      | Hysteria2 端口，默认 0(关闭)                         |
| HYSTERIA_UP_SPEED   | Hysteria2 上传端口速率(Mbps)，默认 100               |
| HYSTERIA_DOWN_SPEED | Hysteria2 下载端口速率(Mbps)，默认 100               |
| CLIENT_CLASH_PORT   | clash api 端口（client.json），默认 0(关闭)          |



**其他相关命令**

```shell
# 永久开启 BBR
{ \
echo "net.core.default_qdisc=fq"; \
echo "net.ipv4.tcp_congestion_control=bbr"; \
}  > /etc/sysctl.d/90-bbr.conf
sysctl --system

# 查看账密等信息（如果没有设置相应的变量，重启后会重置）
docker compose logs | grep -E 'secret'

# 查看 sing-box client.json config
docker compose exec sing-box yq -oj /etc/sing-box/client.json

# 查看 sing-box client.json config about outbounds
docker compose exec sing-box yq -oj '.outbounds[] | select(.tag == "*-*")' /etc/sing-box/client.json

# docker 运行 sing-box
docker run -d --name sing-box \
  -e TZ=Asia/Shanghai \
  -e DOMAIN=example.com \
  -e EMAIL=user@gmail.com \
  -e PASSWORD=pwd \
  -v sing-box-certs:/root/.local/share/certmagic \
  --network host \
  --restart always \
  mings135/sing-box:latest
```



**Windows bat  启动脚本 sing-box.bat**

 ```bat
 cd /d %~dp0
 start /min sing-box.exe run -c client.json
 ```



## Nginx-proxy

**构建 nginx-proxy image**

- 在官方 nginx:*-alpine 版本上修改 entroypoint，用于 sing-box + web 的代理

- 手动更新

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
      - TZ=Asia/Shanghai
      - PROXY1=web,aa.example.com,10.1.1.10:80
      - PROXY2=app,bb.example.com,10.1.1.20:443
    networks:
      - net
    volumes:
      - ./certs:/etc/nginx/certs

networks:
  net:
    ipam:
      driver: default
      config:
        - subnet: "10.1.1.0/24"
```



- Configuration

| **Parameter** | **Description**                                              |
| ------------- | ------------------------------------------------------------ |
| PROXY1        | 代理条目，格式：type,domain:destination（必须）              |
| PROXY2~9      | 同上（可选）        type: app=4层代理，web=7层代理（需要挂载证书） |
| CERT_SOURCE   | sing-box(default) or certbot，证书来源（可选）               |
|               | sing-box: /root/.local/share/certmagic 和 /etc/nginx/certs 挂载到同一目录 |
|               | certbot: /etc/letsencrypt:/etc/nginx/certs                   |
