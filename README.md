# Image Build

自动构建 docker images



## Sing-box

### Server

**docker compose 部署：**

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

# 查看账密等信息（如果没有设置，每次重启都会变动）
docker compose logs | grep -E 'secret'

# 查看 sing-box client.json config
docker compose exec sing-box yq -oj /etc/sing-box/client.json
docker compose exec sing-box yq -oj /etc/sing-box/client-1.8.json

# 查看 sing-box client.json config about outbounds
docker compose exec sing-box yq -oj '.outbounds[] | select(.tag == "*-*")' /etc/sing-box/client.json
docker compose exec sing-box yq -oj '.outbounds[] | select(.tag == "*-*")' /etc/sing-box/client-1.8.json

# docker 运行 sing-box
docker run -d --name sing-box \
  -e TZ=Asia/Shanghai \
  -e DOMAIN=x.x.top \
  -e EMAIL=xx@gmail.com \
  -e PASSWORD=pwd \
  -e PORT_TROJAN=443 \
  -v $(pwd)/local:/root/.local \
  --network host \
  --restart always \
  mings135/sing-box:v1.7.8
```



### Client

**Windows bat  启动脚本 sing-box.bat：**

 ```bat
 cd /d %~dp0
 start /min sing-box.exe run -c client.json
 ```



如果有设置 `CLIENT_CLASH_PORT`，访问地址：`127.0.0.1/ui`

