# Image Build

自动构建 docker images 上传到 docker hub



**安装 docker 环境：**

- debian

```shell
apt-get update && apt-get install -y ca-certificates curl gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-compose-plugin
```



- centos

```shell
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-compose-plugin
```



## Sing-box

**自动构建 sing-box image：**

- 源码来源：https://github.com/SagerNet/sing-box



**Docker Compose**

- docker-compose.yaml

```yaml
version: "3.8"
services:
  sing-box:
    container_name: sing-box
    image: mings135/sing-box:v1.9.6
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - DOMAIN=example.com
      - EMAIL=user@gmail.com
      - PASSWORD=pwd
      - PORT_TROJAN=443
      - CLIENT_CLASH_PORT=9090
    network_mode: "host"
    volumes:
      - ./local:/root/.local
```



- Configuration

| **Parameter**       | **Description**                                              |
| ------------------- | ------------------------------------------------------------ |
| DOMAIN              | 域名（必须）                                                 |
| EMAIL               | 申请证书所需（必须）                                         |
| USERNAME            | 用户名，默认随机（重启重置）                                 |
| PASSWORD            | 密码，默认随机（重启重置）                                   |
| UUID                | uuid，默认随机（重启重置）                                   |
| LOG_LEVEL           | 日志级别，默认 warn                                          |
| CHECK_DNS           | 运行 Server 前，检查域名解析，默认 1(开启)，可选值 0 or 1    |
| PORT_TROJAN         | trojan 端口，默认 0(关闭) or 443(未配置服务时默认开启，端口 443) |
| PORT_NAIVE          | naive 端口，默认 0(关闭)                                     |
| PORT_VLESS          | vless 端口，默认 0(关闭)                                     |
| PORT_TUIC           | tuic 端口，默认 0(关闭)                                      |
| PORT_HYSTERIA2      | hysteria2 端口，默认 0(关闭)                                 |
| HYSTERIA_UP_SPEED   | hysteria2 上传端口速率，默认 100                             |
| HYSTERIA_DOWN_SPEED | hysteria2 下载端口速率，默认 100                             |
| NODE_TAG            | 节点标签，用于 client.json，默认随机                         |
| CLIENT_CLASH_PORT   | clash api 端口，用于 client.json，默认 0(关闭)               |



**服务端部署：**

- 需要 docker 环境，支持 Google Cloud 容器镜像直接部署

```shell
# 永久开启 BBR
echo "net.core.default_qdisc=fq" > /etc/sysctl.d/90-bbr.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/90-bbr.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.d/90-bbr.conf
sysctl --system

# 运行
docker compose up -d

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
  -e PORT_TROJAN=443 \
  -v sing-box-local:/root/.local \
  --network host \
  --restart always \
  mings135/sing-box:latest
```



**Windows bat  启动脚本 sing-box.bat：**

 ```bat
 cd /d %~dp0
 start /min sing-box.exe run -c client.json
 ```

