# Image Build

自动构建 docker images



## Sing-box

**自动构建 sing-box image：**

- 源码来源：https://github.com/SagerNet/sing-box



**服务端部署：**

- 需要 docker 环境，支持 Google Cloud 容器镜像直接部署

```shell
# 永久开启 BBR
echo "net.core.default_qdisc=fq" > /etc/sysctl.d/90-bbr.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/90-bbr.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.d/90-bbr.conf
sysctl --system

# 临时开启 BBR
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
sysctl -w net.core.rmem_max=16777216

# 运行
docker compose up -d

# 查看账密等信息（如果没有设置，每次重启都会变动）
docker compose logs | grep -E 'secret'

# 查看 sing-box client.json config
docker compose exec sing-box yq -oj /etc/sing-box/client.json

# 查看 sing-box client.json config about outbounds
docker compose exec sing-box yq -oj '.outbounds[] | select(.tag == "*-*")' /etc/sing-box/client.json

# docker 运行 sing-box
docker run -d --name sing-box \
  -e TZ=Asia/Shanghai \
  -e DOMAIN=x.x.top \
  -e EMAIL=xx@gmail.com \
  -e PASSWORD=pwd \
  -e PORT_TROJAN=443 \
  -v sing-box-local:/root/.local \
  --network host \
  --restart always \
  mings135/sing-box:v1.7.8
```



**Windows bat  启动脚本 sing-box.bat：**

 ```bat
 cd /d %~dp0
 start /min sing-box.exe run -c client.json
 ```

