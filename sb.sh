#!/bin/bash
export LANG=en_US.UTF-8
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "Please run script as root" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "Script does not support current system，Please use Ubuntu, Debian, or Centos system。" && exit
fi
export sbfiles="/etc/s-box/sb10.json /etc/s-box/sb11.json /etc/s-box/sb.json"
export sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
#if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "Script does not support current $op system，Please use Ubuntu, Debian, or Centos system。" && exit
fi
version=$(uname -r | cut -d "-" -f1)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
armv7l) cpu=armv7;;
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "Script does not currently support$(uname -m)architecture" && exit;;
esac
#bit=$(uname -m)
#if [[ $bit = "aarch64" ]]; then
#cpu="arm64"
#elif [[ $bit = "x86_64" ]]; then
#amdv=$(cat /proc/cpuinfo | grep flags | head -n 1 | cut -d: -f2)
#[[ $amdv == *avx2* && $amdv == *f16c* ]] && cpu="amd64v3" || cpu="amd64"
#else
#red "Script does not currently support $bit architecture" && exit
#fi
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="OpenVZ BBR-Plus"
else
bbr="Openvz/Lxc"
fi
hostname=$(hostname)

if [ ! -f sbyg_update ]; then
green "First-time installing Sing-box-yg script required dependencies……"
if [[ x"${release}" == x"alpine" ]]; then
apk update
apk add jq openssl iproute2 iputils coreutils expect git socat iptables grep util-linux dcron tar tzdata 
apk add virt-what
else
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install jq cron socat iptables-persistent coreutils util-linux -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install jq socat coreutils util-linux -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install jq socat coreutils util-linux -y
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie iptables-services
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie iptables-services
fi
systemctl enable iptables >/dev/null 2>&1
systemctl start iptables >/dev/null 2>&1
fi
if [[ -z $vi ]]; then
apt install iputils-ping iproute2 systemctl -y
fi

packages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
inspackages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
fi
touch sbyg_update
fi

if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "TUN not enabled detected, attempting to add TUN support" && sleep 4
cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "Failed to add TUN support, suggest contacting VPS provider or enable in control panel" && exit
else
echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN daemon started"
fi
fi
fi

v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
}

warpcheck(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

v6(){
v4orv6(){
if [ -z "$(curl -s4m5 icanhazip.com -k)" ]; then
echo
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow "Detected pure IPv6 VPS, adding NAT64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
ipv=prefer_ipv6
else
ipv=prefer_ipv4
fi
if [ -n "$(curl -s6m5 icanhazip.com -k)" ]; then
endip=2606:4700:d0::a29f:c001
else
endip=162.159.192.1
fi
}
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4orv6
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4orv6
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

argopid(){
ym=$(cat /etc/s-box/sbargoympid.log 2>/dev/null)
ls=$(cat /etc/s-box/sbargopid.log 2>/dev/null)
}

close(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
sleep 1
green "Port opening and firewall disabling completed"
}

openyn(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
readp "Open ports and disable firewall？\n1、Yes, execute (Enter for default)\n2、No, skip！handle manually\nPlease select【1-2】：" action
if [[ -z $action ]] || [[ "$action" = "1" ]]; then
close
elif [[ "$action" = "2" ]]; then
echo
else
red "Invalid input, please select again" && openyn
fi
}

inssb(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "Which kernel version to use？Note: 1.10 series stable kernel supports geosite routing, latest kernel after 1.10 series does not support geosite routing"
yellow "1：Use latest stable kernel after 1.10 series (Enter for default)"
yellow "2：Use 1.10.7 stable kernel"
readp "Please select【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
#sbcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"[0-9.]+",' | sed -n 1p | tr -d '",')
sbcore="1.12.21"
else
sbcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"1\.10[0-9\.]*",'  | sed -n 1p | tr -d '",')
fi
sbname="sing-box-$sbcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
blue "Successfully installed Sing-box kernel version：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
else
red "Download.*incomplete，installation failed，Please run installation again" && exit
fi
else
red "Download.*failed，Please run installation again，and check if VPS can access Github" && exit
fi
}

inscertificate(){
ymzs(){
ym_vl_re=apple.com
echo
blue "Vless-reality SNI domain defaults to apple.com"
blue "Vmess-ws will enable TLS，Hysteria-2, Tuic-v5 will use $(cat /root/ygkkkca/ca.log 2>/dev/null) certificate with SNI verification enabled"
tlsyn=true
ym_vm_ws=$(cat /root/ygkkkca/ca.log 2>/dev/null)
certificatec_vmess_ws='/root/ygkkkca/cert.crt'
certificatep_vmess_ws='/root/ygkkkca/private.key'
certificatec_hy2='/root/ygkkkca/cert.crt'
certificatep_hy2='/root/ygkkkca/private.key'
certificatec_tuic='/root/ygkkkca/cert.crt'
certificatep_tuic='/root/ygkkkca/private.key'
}

zqzs(){
ym_vl_re=apple.com
echo
blue "Vless-reality SNI domain defaults to apple.com"
blue "Vmess-ws will disable TLS，Hysteria-2, Tuic-v5 will usebingself-signed certificate，with SNI verification disabled"
tlsyn=false
ym_vm_ws=www.bing.com
certificatec_vmess_ws='/etc/s-box/cert.pem'
certificatep_vmess_ws='/etc/s-box/private.key'
certificatec_hy2='/etc/s-box/cert.pem'
certificatep_hy2='/etc/s-box/private.key'
certificatec_tuic='/etc/s-box/cert.pem'
certificatep_tuic='/etc/s-box/private.key'
}

red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "2. Generate and set up certificates"
echo
blue "Auto-generating bing self-signed certificate……" && sleep 2
openssl ecparam -genkey -name prime256v1 -out /etc/s-box/private.key
openssl req -new -x509 -days 36500 -key /etc/s-box/private.key -out /etc/s-box/cert.pem -subj "/CN=www.bing.com"
echo
if [[ -f /etc/s-box/cert.pem ]]; then
blue "Generated.*certificate successfully"
else
red "Failed to generate.*certificate" && exit
fi
echo
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
yellow "Detected previous Acme domain certificate applied via Acme-yg script：$(cat /root/ygkkkca/ca.log) "
green "Whether to use $(cat /root/ygkkkca/ca.log) domain certificate？"
yellow "1：No! Use self-signed certificate (Enter for default)"
yellow "2：Yes! Use $(cat /root/ygkkkca/ca.log) domain certificate"
readp "Please select【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
ymzs
fi
else
green "If you have a resolved domain, apply for an Acmedomain certificate？"
yellow "1：No! Continue using self-signed certificate (Enter for default)"
yellow "2：Yes! Use Acme-yg script to apply for Acme certificate (supports regular port 80 mode and DNS API mode)"
readp "Please select【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/acme.sh)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key && ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Acme certificate application failed，Continue usingself-signed certificate" 
zqzs
else
ymzs
fi
fi
fi
}

chooseport(){
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nPort is in use，Please re-enter port" && readp "Custom port:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nPort is in use，Please re-enter port" && readp "Custom port:" port
done
fi
blue "Confirmed port：$port" && sleep 2
}

vlport(){
readp "\nSet Vless-reality port[1-65535] (Enter to skip(10000-65535 random port))：" port
chooseport
port_vl_re=$port
}
vmport(){
readp "\nSet Vmess-ws port[1-65535] (Enter to skip(10000-65535 random port))：" port
chooseport
port_vm_ws=$port
}
hy2port(){
readp "\nSet Hysteria2 main port[1-65535] (Enter to skip(10000-65535 random port))：" port
chooseport
port_hy2=$port
}
tu5port(){
readp "\nSet Tuic5 main port[1-65535] (Enter to skip(10000-65535 random port))：" port
chooseport
port_tu=$port
}

insport(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "3. Set ports for each protocol"
yellow "1：Auto-generate random port for each protocol (10000-65535 range)，Enter for default"
yellow "2：Custom port for each protocol"
readp "Please enter【1-2】：" port
if [ -z "$port" ] || [ "$port" = "1" ] ; then
ports=()
for i in {1..4}; do
while true; do
port=$(shuf -i 10000-65535 -n 1)
if ! [[ " ${ports[@]} " =~ " $port " ]] && \
[[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && \
[[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
ports+=($port)
break
fi
done
done
port_vm_ws=${ports[0]}
port_vl_re=${ports[1]}
port_hy2=${ports[2]}
port_tu=${ports[3]}
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
until [[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port_vm_ws") ]]
do
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
done
echo
blue "Based on Vmess-ws TLS status, randomly assign standard port supporting CDN optimized IP：$port_vm_ws"
else
vlport && vmport && hy2port && tu5port
fi
echo
blue "Confirmed ports for each protocol"
blue "Vless-realityport:$port_vl_re"
blue "Vmess-wsport:$port_vm_ws"
blue "Hysteria-2port:$port_hy2"
blue "Tuic-v5port:$port_tu"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "4. Auto-generate unified UUID (password) for each protocol"
uuid=$(/etc/s-box/sing-box generate uuid)
blue "Confirmed UUID (password)：${uuid}"
blue "Confirmed Vmess path：${uuid}-vm"
}

inssbjsonser(){
cat > /etc/s-box/sb10.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "sniff": true,
      "sniff_override_destination": true,
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",
            "sniff": true,
            "sniff_override_destination": true,
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        }
],
"outbounds": [
{
"type":"direct",
"tag":"direct",
"domain_strategy": "$ipv"
},
{
"type":"direct",
"tag": "vps-outbound-v4", 
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag": "vps-outbound-v6",
"domain_strategy":"prefer_ipv6"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
},
{
"type":"direct",
"tag":"socks-IPv4-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"socks-IPv6-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"direct",
"tag":"warp-IPv4-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"warp-IPv6-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"wireguard",
"tag":"wireguard-out",
"server":"$endip",
"server_port":2408,
"local_address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"reserved":$res
},
{
"type": "block",
"tag": "block"
}
],
"route":{
"rules":[
{
"protocol": [
"quic",
"stun"
],
"outbound": "block"
},
{
"outbound":"warp-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"warp-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v4",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v6",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF

cat > /etc/s-box/sb11.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",

      
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",

 
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",

 
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",

     
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        }
],
"endpoints":[
{
"type":"wireguard",
"tag":"warp-out",
"address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peers": [
{
"address": "$endip",
"port":2408,
"public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"allowed_ips": [
"0.0.0.0/0",
"::/0"
],
"reserved":$res
}
]
}
],
"outbounds": [
{
"type":"direct",
"tag":"direct",
"domain_strategy": "$ipv"
},
{
"type":"direct",
"tag":"vps-outbound-v4", 
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"vps-outbound-v6",
"domain_strategy":"prefer_ipv6"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
}
],
"route":{
"rules":[
{
 "action": "sniff"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv4"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv6"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"socks-out"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"warp-out"
},
{
"outbound":"vps-outbound-v4",
"domain_suffix":[
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v6",
"domain_suffix":[
"yg_kkk"
]
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
}

sbservice(){
if [[ x"${release}" == x"alpine" ]]; then
echo '#!/sbin/openrc-run
description="sing-box service"
command="/etc/s-box/sing-box"
command_args="run -c /etc/s-box/sb.json"
command_background=true
pidfile="/var/run/sing-box.pid"' > /etc/init.d/sing-box
chmod +x /etc/init.d/sing-box
rc-update add sing-box default
rc-service sing-box start
else
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl start sing-box
systemctl restart sing-box
fi
}

ipuuid(){
if [[ x"${release}" == x"alpine" ]]; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl status sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Dual-stack VPS requires IP config selection, NAT VPS recommended to use IPv6"
yellow "1：Use IPv4 config output (Enter for default) "
yellow "2：Use IPv6 config output"
readp "Please select【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ]; then
sbdnsip='tls://8.8.8.8/dns-query'
echo "$sbdnsip" > /etc/s-box/sbdnsip.log
server_ip="$v4"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v4"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
sbdnsip='tls://[2001:4860:4860::8888]/dns-query'
echo "$sbdnsip" > /etc/s-box/sbdnsip.log
server_ip="[$v6]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v6"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
else
yellow "VPS is not dual-stack, IP config output switching not supported"
serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
if [[ "$serip" =~ : ]]; then
sbdnsip='tls://[2001:4860:4860::8888]/dns-query'
echo "$sbdnsip" > /etc/s-box/sbdnsip.log
server_ip="[$serip]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
sbdnsip='tls://8.8.8.8/dns-query'
echo "$sbdnsip" > /etc/s-box/sbdnsip.log
server_ip="$serip"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
fi
else
red "Sing-box service not running" && exit
fi
}

wgcfgo(){
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ipuuid
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ipuuid
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

result_vl_vm_hy_tu(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
fi
rm -rf /etc/s-box/vm_ws_argo.txt /etc/s-box/vm_ws.txt /etc/s-box/vm_ws_tls.txt
sbdnsip=$(cat /etc/s-box/sbdnsip.log)
server_ip=$(cat /etc/s-box/server_ip.log)
server_ipcl=$(cat /etc/s-box/server_ipcl.log)
uuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vl_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
public_key=$(cat /etc/s-box/public.key)
short_id=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.short_id[0]')
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
ws_path=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
if [[ -f /etc/s-box/cfvmadd_local.txt ]]; then
vmadd_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
vmadd_are_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
else
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
fi
if [[ -f /etc/s-box/cfvmadd_argo.txt ]]; then
vmadd_argo=$(cat /etc/s-box/cfvmadd_argo.txt 2>/dev/null)
else
vmadd_argo=www.visa.com.sg
fi
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
if [[ -n $hy2_ports ]]; then
hy2ports=$(echo $hy2_ports | sed 's/:/-/g')
hyps=$hy2_port,$hy2ports
else
hyps=
fi
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [[ "$hy2_sniname" = '/etc/s-box/private.key' ]]; then
hy2_name=www.bing.com
sb_hy2_ip=$server_ip
cl_hy2_ip=$server_ipcl
ins_hy2=1
hy2_ins=true
else
hy2_name=$ym
sb_hy2_ip=$ym
cl_hy2_ip=$ym
ins_hy2=0
hy2_ins=false
fi
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [[ "$tu5_sniname" = '/etc/s-box/private.key' ]]; then
tu5_name=www.bing.com
sb_tu5_ip=$server_ip
cl_tu5_ip=$server_ipcl
ins=1
tu5_ins=true
else
tu5_name=$ym
sb_tu5_ip=$ym
cl_tu5_ip=$ym
ins=0
tu5_ins=false
fi
}

resvless(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vl_link="vless://$uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
echo "$vl_link" > /etc/s-box/vl_reality.txt
red "🚀【 vless-reality-vision 】Node info as follows：" && sleep 2
echo
echo "Share link【v2ran(switch singbox kernel)、nekobox、Shadowrocket】"
echo -e "${yellow}$vl_link${plain}"
echo
echo "QR code【v2ran(switch singbox kernel)、nekobox、Shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vl_reality.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resvmess(){
if [[ "$tls" = "false" ]]; then
argopid
if [[ -n $(ps -e | grep -w $ls 2>/dev/null) ]]; then
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo 】temporaryNode info as follows(can select 3-8-3 to customize CDN optimized address)：" && sleep 2
echo
echo "Share link【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argols.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argols.txt)"
fi
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) ]]; then
argogd=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo 】fixedNode info as follows (can select 3-8-3 to customize CDN optimized address)：" && sleep 2
echo
echo "Share link【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argogd.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argogd.txt)"
fi
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws 】Node info as follows (suggest selecting 3-8-1 to set as CDN optimized node)：" && sleep 2
echo
echo "Share link【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws.txt)"
else
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws-tls 】Node info as follows (suggest selecting 3-8-1 to set as CDN optimized node)：" && sleep 2
echo
echo "Share link【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_tls.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_tls.txt)"
fi
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

reshy2(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
#hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&mport=$hyps&sni=$hy2_name#hy2-$hostname"
hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&sni=$hy2_name#hy2-$hostname"
echo "$hy2_link" > /etc/s-box/hy2.txt
red "🚀【 Hysteria-2 】Node info as follows：" && sleep 2
echo
echo "Share link【v2rayn、v2rayng、nekobox、Shadowrocket】"
echo -e "${yellow}$hy2_link${plain}"
echo
echo "QR code【v2rayn、v2rayng、nekobox、Shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/hy2.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

restu5(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
tuic5_link="tuic://$uuid:$uuid@$sb_tu5_ip:$tu5_port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$tu5_name&allow_insecure=$ins&allowInsecure=$ins#tu5-$hostname"
echo "$tuic5_link" > /etc/s-box/tuic5.txt
red "🚀【 Tuic-v5 】Node info as follows：" && sleep 2
echo
echo "Share link【v2rayn、nekobox、Shadowrocket】"
echo -e "${yellow}$tuic5_link${plain}"
echo
echo "QR code【v2rayn、nekobox、Shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/tuic5.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

sb_client(){
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
argopid
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) && -n $(ps -e | grep -w $ls 2>/dev/null) && "$tls" = "false" ]]; then
cat > /etc/s-box/sing_box_client.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "secret": "",
      "default_mode": "Rule"
       },
      "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "store_fakeip": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "proxydns",
                "address": "$sbdnsip",
                "detour": "select"
            },
            {
                "tag": "localdns",
                "address": "h3://223.5.5.5/dns-query",
                "detour": "direct"
            },
            {
                "tag": "dns_fakeip",
                "address": "fakeip"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "localdns",
                "disable_cache": true
            },
            {
                "clash_mode": "Global",
                "server": "proxydns"
            },
            {
                "clash_mode": "Direct",
                "server": "localdns"
            },
            {
                "rule_set": "geosite-cn",
                "server": "localdns"
            },
            {
                 "rule_set": "geosite-geolocation-!cn",
                 "server": "proxydns"
            },
             {
                "rule_set": "geosite-geolocation-!cn",         
                "query_type": [
                    "A",
                    "AAAA"
                ],
                "server": "dns_fakeip"
            }
          ],
           "fakeip": {
           "enabled": true,
           "inet4_range": "198.18.0.0/15",
           "inet6_range": "fc00::/18"
         },
          "independent_cache": true,
          "final": "proxydns"
        },
      "inbounds": [
    {
      "type": "tun",
           "tag": "tun-in",
	  "address": [
      "172.19.0.1/30",
	  "fd00::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
"vmess-tls-argofixed-$hostname",
"vmess-argofixed-$hostname",
"vmess-tls-argotemporary-$hostname",
"vmess-argotemporary-$hostname"
      ]
    },
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argofixed-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argofixed-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argotemporary-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argotemporary-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
"vmess-tls-argofixed-$hostname",
"vmess-argofixed-$hostname",
"vmess-tls-argotemporary-$hostname",
"vmess-argotemporary-$hostname"
      ],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    }
  ],
  "route": {
      "rule_set": [
            {
                "tag": "geosite-geolocation-!cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            }
        ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
      "inbound": "tun-in",
      "action": "sniff"
      },
      {
      "protocol": "dns",
      "action": "hijack-dns"
      },
      {
      "port": 443,
      "network": "udp",
      "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
      "ip_is_private": true,
      "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
    "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF

cat > /etc/s-box/clash_meta_client.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
dns:
  enable: false
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     

- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port                                
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins

- name: vmess-tls-argofixed-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd


- name: vmess-argofixed-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-tls-argotemporary-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argotemporary-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: Load Balance
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argofixed-$hostname
    - vmess-argofixed-$hostname
    - vmess-tls-argotemporary-$hostname
    - vmess-argotemporary-$hostname

- name: Auto Select
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argofixed-$hostname
    - vmess-argofixed-$hostname
    - vmess-tls-argotemporary-$hostname
    - vmess-argotemporary-$hostname
    
- name: 🌍Select Proxy Node
  type: select
  proxies:
    - Load Balance                                         
    - Auto Select
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argofixed-$hostname
    - vmess-argofixed-$hostname
    - vmess-tls-argotemporary-$hostname
    - vmess-argotemporary-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍Select Proxy Node
EOF


elif [[ ! -n $(ps -e | grep -w $ym 2>/dev/null) && -n $(ps -e | grep -w $ls 2>/dev/null) && "$tls" = "false" ]]; then
cat > /etc/s-box/sing_box_client.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "secret": "",
      "default_mode": "Rule"
       },
      "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "store_fakeip": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "proxydns",
                "address": "$sbdnsip",
                "detour": "select"
            },
            {
                "tag": "localdns",
                "address": "h3://223.5.5.5/dns-query",
                "detour": "direct"
            },
            {
                "tag": "dns_fakeip",
                "address": "fakeip"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "localdns",
                "disable_cache": true
            },
            {
                "clash_mode": "Global",
                "server": "proxydns"
            },
            {
                "clash_mode": "Direct",
                "server": "localdns"
            },
            {
                "rule_set": "geosite-cn",
                "server": "localdns"
            },
            {
                 "rule_set": "geosite-geolocation-!cn",
                 "server": "proxydns"
            },
             {
                "rule_set": "geosite-geolocation-!cn",         
                "query_type": [
                    "A",
                    "AAAA"
                ],
                "server": "dns_fakeip"
            }
          ],
           "fakeip": {
           "enabled": true,
           "inet4_range": "198.18.0.0/15",
           "inet6_range": "fc00::/18"
         },
          "independent_cache": true,
          "final": "proxydns"
        },
      "inbounds": [
    {
      "type": "tun",
           "tag": "tun-in",
	  "address": [
      "172.19.0.1/30",
	  "fd00::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
"vmess-tls-argotemporary-$hostname",
"vmess-argotemporary-$hostname"
      ]
    },
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argotemporary-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argotemporary-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
"vmess-tls-argotemporary-$hostname",
"vmess-argotemporary-$hostname"
      ],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    }
  ],
  "route": {
      "rule_set": [
            {
                "tag": "geosite-geolocation-!cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            }
        ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
      "inbound": "tun-in",
      "action": "sniff"
      },
      {
      "protocol": "dns",
      "action": "hijack-dns"
      },
      {
      "port": 443,
      "network": "udp",
      "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
      "ip_is_private": true,
      "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
    "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF

cat > /etc/s-box/clash_meta_client.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
dns:
  enable: false
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     

- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port                                
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins









- name: vmess-tls-argotemporary-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argotemporary-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: Load Balance
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argotemporary-$hostname
    - vmess-argotemporary-$hostname

- name: Auto Select
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argotemporary-$hostname
    - vmess-argotemporary-$hostname
    
- name: 🌍Select Proxy Node
  type: select
  proxies:
    - Load Balance                                         
    - Auto Select
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argotemporary-$hostname
    - vmess-argotemporary-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍Select Proxy Node
EOF

elif [[ -n $(ps -e | grep -w $ym 2>/dev/null) && ! -n $(ps -e | grep -w $ls 2>/dev/null) && "$tls" = "false" ]]; then
cat > /etc/s-box/sing_box_client.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "secret": "",
      "default_mode": "Rule"
       },
      "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "store_fakeip": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "proxydns",
                "address": "$sbdnsip",
                "detour": "select"
            },
            {
                "tag": "localdns",
                "address": "h3://223.5.5.5/dns-query",
                "detour": "direct"
            },
            {
                "tag": "dns_fakeip",
                "address": "fakeip"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "localdns",
                "disable_cache": true
            },
            {
                "clash_mode": "Global",
                "server": "proxydns"
            },
            {
                "clash_mode": "Direct",
                "server": "localdns"
            },
            {
                "rule_set": "geosite-cn",
                "server": "localdns"
            },
            {
                 "rule_set": "geosite-geolocation-!cn",
                 "server": "proxydns"
            },
             {
                "rule_set": "geosite-geolocation-!cn",         
                "query_type": [
                    "A",
                    "AAAA"
                ],
                "server": "dns_fakeip"
            }
          ],
           "fakeip": {
           "enabled": true,
           "inet4_range": "198.18.0.0/15",
           "inet6_range": "fc00::/18"
         },
          "independent_cache": true,
          "final": "proxydns"
        },
      "inbounds": [
    {
      "type": "tun",
     "tag": "tun-in",
	  "address": [
      "172.19.0.1/30",
	  "fd00::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
"vmess-tls-argofixed-$hostname",
"vmess-argofixed-$hostname"
      ]
    },
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argofixed-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argofixed-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
"vmess-tls-argofixed-$hostname",
"vmess-argofixed-$hostname"
      ],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    }
  ],
  "route": {
      "rule_set": [
            {
                "tag": "geosite-geolocation-!cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            }
        ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
      "inbound": "tun-in",
      "action": "sniff"
      },
      {
      "protocol": "dns",
      "action": "hijack-dns"
      },
      {
      "port": 443,
      "network": "udp",
      "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
      "ip_is_private": true,
      "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
    "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF

cat > /etc/s-box/clash_meta_client.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
dns:
  enable: false
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     

- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port                                
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins







- name: vmess-tls-argofixed-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-argofixed-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

proxy-groups:
- name: Load Balance
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argofixed-$hostname
    - vmess-argofixed-$hostname

- name: Auto Select
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argofixed-$hostname
    - vmess-argofixed-$hostname
    
- name: 🌍Select Proxy Node
  type: select
  proxies:
    - Load Balance                                         
    - Auto Select
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    - vmess-tls-argofixed-$hostname
    - vmess-argofixed-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍Select Proxy Node
EOF

else
cat > /etc/s-box/sing_box_client.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui": "ui",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "secret": "",
      "default_mode": "Rule"
       },
      "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "store_fakeip": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "proxydns",
                "address": "$sbdnsip",
                "detour": "select"
            },
            {
                "tag": "localdns",
                "address": "h3://223.5.5.5/dns-query",
                "detour": "direct"
            },
            {
                "tag": "dns_fakeip",
                "address": "fakeip"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "localdns",
                "disable_cache": true
            },
            {
                "clash_mode": "Global",
                "server": "proxydns"
            },
            {
                "clash_mode": "Direct",
                "server": "localdns"
            },
            {
                "rule_set": "geosite-cn",
                "server": "localdns"
            },
            {
                 "rule_set": "geosite-geolocation-!cn",
                 "server": "proxydns"
            },
             {
                "rule_set": "geosite-geolocation-!cn",         
                "query_type": [
                    "A",
                    "AAAA"
                ],
                "server": "dns_fakeip"
            }
          ],
           "fakeip": {
           "enabled": true,
           "inet4_range": "198.18.0.0/15",
           "inet6_range": "fc00::/18"
         },
          "independent_cache": true,
          "final": "proxydns"
        },
      "inbounds": [
    {
      "type": "tun",
     "tag": "tun-in",
	  "address": [
      "172.19.0.1/30",
	  "fd00::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
    }
  ],
  "outbounds": [
    {
      "tag": "select",
      "type": "selector",
      "default": "auto",
      "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
      ]
    },
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
      ],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50,
      "interrupt_exist_connections": false
    }
  ],
  "route": {
      "rule_set": [
            {
                "tag": "geosite-geolocation-!cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "select",
                "update_interval": "1d"
            }
        ],
    "auto_detect_interface": true,
    "final": "select",
    "rules": [
      {
      "inbound": "tun-in",
      "action": "sniff"
      },
      {
      "protocol": "dns",
      "action": "hijack-dns"
      },
      {
      "port": 443,
      "network": "udp",
      "action": "reject"
      },
      {
        "clash_mode": "Direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "Global",
        "outbound": "select"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      },
      {
      "ip_is_private": true,
      "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "select"
      }
    ]
  },
    "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m",
    "detour": "direct"
  }
}
EOF

cat > /etc/s-box/clash_meta_client.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
dns:
  enable: false
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                    
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     





- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port                                
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins

proxy-groups:
- name: Load Balance
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname

- name: Auto Select
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    
- name: 🌍Select Proxy Node
  type: select
  proxies:
    - Load Balance                                         
    - Auto Select
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍Select Proxy Node
EOF
fi

cat > /etc/s-box/v2rayn_hy2.yaml <<EOF
server: $sb_hy2_ip:$hy2_port
auth: $uuid
tls:
  sni: $hy2_name
  insecure: $hy2_ins
fastOpen: true
socks5:
  listen: 127.0.0.1:50000
lazy: true
transport:
  udp:
    hopInterval: 30s
EOF

cat > /etc/s-box/v2rayn_tu5.json <<EOF
{
    "relay": {
        "server": "$sb_tu5_ip:$tu5_port",
        "uuid": "$uuid",
        "password": "$uuid",
        "congestion_control": "bbr",
        "alpn": ["h3", "spdy/3.1"]
    },
    "local": {
        "server": "127.0.0.1:55555"
    },
    "log_level": "info"
}
EOF
if [[ -n $hy2_ports ]]; then
hy2_ports=",$hy2_ports"
hy2_ports=$(echo $hy2_ports | sed 's/:/-/g')
a=$hy2_ports
sed -i "/server:/ s/$/$a/" /etc/s-box/v2rayn_hy2.yaml
fi
sed -i 's/server: \(.*\)/server: "\1"/' /etc/s-box/v2rayn_hy2.yaml
}

cfargo_ym(){
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
echo
yellow "1：Argotemporary tunnel"
yellow "2：Argofixed tunnel"
yellow "0：Return to previous menu"
readp "Please select【0-2】：" menu
if [ "$menu" = "1" ]; then
cfargo
elif [ "$menu" = "2" ]; then
cfargoym
else
changeserv
fi
else
yellow "Because vmess has TLS enabled, Argo tunnel function is not available" && sleep 2
fi
}

cloudflaredargo(){
if [ ! -e /etc/s-box/cloudflared ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/cloudflared -# --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu
#curl -L -o /etc/s-box/cloudflared -# --retry 2 https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/$cpu
chmod +x /etc/s-box/cloudflared
fi
}

cfargoym(){
echo
if [[ -f /etc/s-box/sbargotoken.log && -f /etc/s-box/sbargoym.log ]]; then
green "Current Argofixed tunneldomain：$(cat /etc/s-box/sbargoym.log 2>/dev/null)"
green "Current Argofixed tunnelToken：$(cat /etc/s-box/sbargotoken.log 2>/dev/null)"
fi
echo
green "Please ensure Cloudflare website --- Zero Trust --- Networks --- Tunnels has been configured"
yellow "1：Reset/Set Argofixed tunneldomain"
yellow "2：Stop Argofixed tunnel"
yellow "0：Return to previous menu"
readp "Please select【0-2】：" menu
if [ "$menu" = "1" ]; then
cloudflaredargo
readp "Enter Argofixed tunnelToken: " argotoken
readp "Enter Argofixed tunneldomain: " argoym
if [[ -n $(ps -e | grep cloudflared) ]]; then
kill -15 $(cat /etc/s-box/sbargoympid.log 2>/dev/null) >/dev/null 2>&1
fi
echo
if [[ -n "${argotoken}" && -n "${argoym}" ]]; then
nohup setsid /etc/s-box/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token ${argotoken} >/dev/null 2>&1 & echo "$!" > /etc/s-box/sbargoympid.log
sleep 20
fi
echo ${argoym} > /etc/s-box/sbargoym.log
echo ${argotoken} > /etc/s-box/sbargotoken.log
crontab -l > /tmp/crontab.tmp
sed -i '/sbargoympid/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid /etc/s-box/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $(cat /etc/s-box/sbargotoken.log 2>/dev/null) >/dev/null 2>&1 & pid=\$! && echo \$pid > /etc/s-box/sbargoympid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
argo=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
blue "Argofixed tunnel setup complete, fixeddomain: $argo"
elif [ "$menu" = "2" ]; then
kill -15 $(cat /etc/s-box/sbargoympid.log 2>/dev/null) >/dev/null 2>&1
crontab -l > /tmp/crontab.tmp
sed -i '/sbargoympid/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
rm -rf /etc/s-box/vm_ws_argogd.txt
green "Argofixed tunnel has been stopped"
else
cfargo_ym
fi
}

cfargo(){
echo
yellow "1：Reset Argotemporary tunneldomain"
yellow "2：Stop Argotemporary tunnel"
yellow "0：Return to previous menu"
readp "Please select【0-2】：" menu
if [ "$menu" = "1" ]; then
cloudflaredargo
i=0
while [ $i -le 4 ]; do let i++
yellow "Attempt $i: Verifying Cloudflared Argotemporary tunnel Domain validity, please wait..."
if [[ -n $(ps -e | grep cloudflared) ]]; then
kill -15 $(cat /etc/s-box/sbargopid.log 2>/dev/null) >/dev/null 2>&1
fi
nohup setsid /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
echo "$!" > /etc/s-box/sbargopid.log
sleep 20
if [[ -n $(curl -sL https://$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')/ -I | awk 'NR==1 && /404|400|503/') ]]; then
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
blue "Argotemporary tunnel application successful, Domain verification valid: $argo" && sleep 2
break
fi
if [ $i -eq 5 ]; then
echo
yellow "Argotemporary Domain verification temporarily unavailable, may recover automatically later, or apply for reset" && sleep 3
fi
done
crontab -l > /tmp/crontab.tmp
sed -i '/sbargopid/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 & pid=\$! && echo \$pid > /etc/s-box/sbargopid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
elif [ "$menu" = "2" ]; then
kill -15 $(cat /etc/s-box/sbargopid.log 2>/dev/null) >/dev/null 2>&1
crontab -l > /tmp/crontab.tmp
sed -i '/sbargopid/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
rm -rf /etc/s-box/vm_ws_argols.txt
green "Argotemporary tunnel has been stopped"
else
cfargo_ym
fi
}

instsllsingbox(){
if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
red "Already installed Sing-box service, cannot install again" && sleep 2 && sb
fi
mkdir -p /etc/s-box
v6
openyn
inssb
inscertificate
insport
sleep 2
echo
blue "Vless-reality related key and id will be Auto-generated..."
key_pair=$(/etc/s-box/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
echo "$public_key" > /etc/s-box/public.key
short_id=$(/etc/s-box/sing-box generate rand --hex 4)
wget -q -O /root/geoip.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.db
wget -q -O /root/geosite.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.db
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "5. Auto-generate warp-wireguard outbound account" && sleep 2
warpwg
inssbjsonser
sbservice
sbactive
#curl -sL https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/version/version | awk -F "Update content" '{print $1}' | head -n 1 > /etc/s-box/v
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/version | awk -F "Update content" '{print $1}' | head -n 1 > /etc/s-box/v
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
lnsb && blue "Sing-box-yg Script installed successfully, script shortcut: sb" && cronsb
echo
wgcfgo
sbshare
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
blue "Hysteria2/Tuic5 custom V2rayN config, Clash-Meta/Sing-box client config and private subscription links, Please select 9 to view"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

changeym(){
[ -f /root/ygkkkca/ca.log ] && ymzs="$yellow Switch to domain certificate: $(cat /root/ygkkkca/ca.log 2>/dev/null)$plain" || ymzs="$yellow No domain certificate applied, cannot switch$plain"
vl_na="Currently using domain: $(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name'). $yellow Change to a domain meeting reality requirements, certificate domain not supported$plain"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[[ "$tls" = "false" ]] && vm_na="TLS is currently disabled. $ymzs ${yellow}Will enable TLS, Argo tunnel will not be supported${plain}" || vm_na="Currently using domain certificate: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow Switch to disable TLS, Argo tunnel will be available$plain"
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_na="Currently using self-signed bing certificate. $ymzs" || hy2_na="Currently using domain certificate: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow Switch to self-signed bing certificate$plain"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_na="Currently using self-signed bing certificate. $ymzs" || tu5_na="Currently using domain certificate: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow Switch to self-signed bing certificate$plain"
echo
green "Please select the protocol to switch certificate mode"
green "1：vless-reality protocol, $vl_na"
if [[ -f /root/ygkkkca/ca.log ]]; then
green "2：vmess-ws protocol, $vm_na"
green "3：Hysteria2 protocol, $hy2_na"
green "4：Tuic5 protocol, $tu5_na"
else
red "Only option 1 (vless-reality) is supported. Because no domain certificate applied, vmess-ws, Hysteria-2, Tuic-v5 certificate switching options are not displayed"
fi
green "0：Return to previous menu"
readp "Please select：" menu
if [ "$menu" = "1" ]; then
readp "Please enter vless-reality domain (press Enter to use apple.com): " menu
ym_vl_re=${menu:-apple.com}
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.handshake.server')
c=$(cat /etc/s-box/vl_reality.txt | cut -d'=' -f5 | cut -d'&' -f1)
echo $sbfiles | xargs -n1 sed -i "23s/$a/$ym_vl_re/"
echo $sbfiles | xargs -n1 sed -i "27s/$b/$ym_vl_re/"
restartsb
blue "Setup complete, please return to Main Menu and select option 9 to update node configuration"
elif [ "$menu" = "2" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[ "$a" = "true" ] && a_a=false || a_a=true
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
[ "$b" = "www.bing.com" ] && b_b=$(cat /root/ygkkkca/ca.log) || b_b=$(cat /root/ygkkkca/ca.log)
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "55s#$a#$a_a#"
echo $sbfiles | xargs -n1 sed -i "56s#$b#$b_b#"
echo $sbfiles | xargs -n1 sed -i "57s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "58s#$d#$d_d#"
restartsb
blue "Setup complete, please return to Main Menu and select option 9 to update node configuration"
echo
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
blue "Current Vmess-ws(tls) port: $vm_port"
[[ "$tls" = "false" ]] && blue "Note: Go to Main Menu option 4-2, change Vmess-ws port to any of 7 port-80 series (80, 8080, 8880, 2052, 2082, 2086, 2095) for CDN optimized IP" || blue "Note: Go to Main Menu option 4-2, change Vmess-ws-tls port to any of 6 port-443 series (443, 8443, 2053, 2083, 2087, 2096) for CDN optimized IP"
echo
else
red "No domain certificate applied, cannot switch. Select Main Menu option 12 to apply for Acme certificate" && sleep 2 && sb
fi
elif [ "$menu" = "3" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "79s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "80s#$d#$d_d#"
restartsb
blue "Setup complete, please return to Main Menu and select option 9 to update node configuration"
else
red "No domain certificate applied, cannot switch. Select Main Menu option 12 to apply for Acme certificate" && sleep 2 && sb
fi
elif [ "$menu" = "4" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "102s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "103s#$d#$d_d#"
restartsb
blue "Setup complete, please return to Main Menu and select option 9 to update node configuration"
else
red "No domain certificate applied, cannot switch. Select Main Menu option 12 to apply for Acme certificate" && sleep 2 && sb
fi
else
sb
fi
}

allports(){
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
tu5_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$tu5_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
[[ -n $hy2_ports ]] && hy2zfport="$hy2_ports" || hy2zfport="Not added"
[[ -n $tu5_ports ]] && tu5zfport="$tu5_ports" || tu5zfport="Not added"
}

changeport(){
sbactive
allports
fports(){
readp "\nPlease enter the port range to forward (within 1000-65535, format: small_number:large_number): " rangeport
if [[ $rangeport =~ ^([1-9][0-9]{3,4}:[1-9][0-9]{3,4})$ ]]; then
b=${rangeport%%:*}
c=${rangeport##*:}
if [[ $b -ge 1000 && $b -le 65535 && $c -ge 1000 && $c -le 65535 && $b -lt $c ]]; then
iptables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "Confirmed forwarded port range: $rangeport"
else
red "Entered port range is not within valid range" && fports
fi
else
red "Incorrect input format. Format: small_number:large_number" && fports
fi
echo
}
fport(){
readp "\nPlease enter a port to forward (within 1000-65535): " onlyport
if [[ $onlyport -ge 1000 && $onlyport -le 65535 ]]; then
iptables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "Confirmed forwarded port: $onlyport"
else
blue "Entered port is not within valid range" && fport
fi
echo
}

hy2deports(){
allports
hy2_ports=$(echo "$hy2_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$hy2_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}
tu5deports(){
allports
tu5_ports=$(echo "$tu5_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$tu5_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}

allports
green "Vless-reality and Vmess-ws can only change one unique port, vmess-ws note Argo port reset"
green "Hysteria2 and Tuic5 support changing main port, also support adding/removing multiple forwarded ports"
green "Hysteria2 supports port hopping, and both Hysteria2 and Tuic5 support multi-port multiplexing"
echo
green "1：Vless-reality protocol ${yellow}port: $vl_port${plain}"
green "2：Vmess-ws protocol ${yellow}port: $vm_port${plain}"
green "3：Hysteria2 protocol ${yellow}port: $hy2_port  Forwarded multi-port: $hy2zfport${plain}"
green "4：Tuic5 protocol ${yellow}port: $tu5_port  Forwarded multi-port: $tu5zfport${plain}"
green "0：Return to previous menu"
readp "Please select the protocol to change port [0-4]: " menu
if [ "$menu" = "1" ]; then
vlport
echo $sbfiles | xargs -n1 sed -i "14s/$vl_port/$port_vl_re/"
restartsb
blue "Vless-reality port change complete, can select 9 to output configuration info"
echo
elif [ "$menu" = "2" ]; then
vmport
echo $sbfiles | xargs -n1 sed -i "41s/$vm_port/$port_vm_ws/"
restartsb
blue "Vmess-ws port change complete, can select 9 to output configuration info"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
blue "Note: If Argo is in use, temporary tunnel must be reset, fixed tunnel CF settings port must be changed to $port_vm_ws"
else
blue "Current Argo tunnel is no longer supported to be enabled"
fi
echo
elif [ "$menu" = "3" ]; then
green "1：Change Hysteria2 main port (original multi-port will be auto-reset and deleted)"
green "2：Add Hysteria2 multi-port"
green "3：Reset and delete Hysteria2 multi-port"
green "0：Return to previous menu"
readp "Please select【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n $hy2_ports ]; then
hy2deports
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb
result_vl_vm_hy_tu && reshy2 && sb_client
else
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb
result_vl_vm_hy_tu && reshy2 && sb_client
fi
elif [ "$menu" = "2" ]; then
green "1：Add Hysteria2 port range"
green "2：Add Hysteria2 single port"
green "0：Return to previous menu"
readp "Please select【0-2】：" menu
if [ "$menu" = "1" ]; then
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
fports && result_vl_vm_hy_tu && sb_client && changeport
elif [ "$menu" = "2" ]; then
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
fport && result_vl_vm_hy_tu && sb_client && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n $hy2_ports ]; then
hy2deports && result_vl_vm_hy_tu && sb_client && changeport
else
yellow "Hysteria2 has no multi-port set" && changeport
fi
else
changeport
fi

elif [ "$menu" = "4" ]; then
green "1：Change Tuic5 main port (original multi-port will be auto-reset and deleted)"
green "2：Add Tuic5 multi-port"
green "3：Reset and delete Tuic5 multi-port"
green "0：Return to previous menu"
readp "Please select【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n $tu5_ports ]; then
tu5deports
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb
result_vl_vm_hy_tu && restu5 && sb_client
else
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb
result_vl_vm_hy_tu && restu5 && sb_client
fi
elif [ "$menu" = "2" ]; then
green "1：Add Tuic5 port range"
green "2：Add Tuic5 single port"
green "0：Return to previous menu"
readp "Please select【0-2】：" menu
if [ "$menu" = "1" ]; then
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
fports && result_vl_vm_hy_tu && sb_client && changeport
elif [ "$menu" = "2" ]; then
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
fport && result_vl_vm_hy_tu && sb_client && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n $tu5_ports ]; then
tu5deports && result_vl_vm_hy_tu && sb_client && changeport
else
yellow "Tuic5 has no multi-port set" && changeport
fi
else
changeport
fi
else
sb
fi
}

changeuuid(){
echo
olduuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
oldvmpath=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
green "UUID (password) for all protocols: $olduuid"
green "Vmess path: $oldvmpath"
echo
yellow "1：Custom UUID (password) for all protocols"
yellow "2：Custom Vmess path"
yellow "0：Return to previous menu"
readp "Please select【0-2】：" menu
if [ "$menu" = "1" ]; then
readp "Enter UUID, must be in UUID format, press Enter if unsure (reset and randomly generate UUID): " menu
if [ -z "$menu" ]; then
uuid=$(/etc/s-box/sing-box generate uuid)
else
uuid=$menu
fi
echo $sbfiles | xargs -n1 sed -i "s/$olduuid/$uuid/g"
restartsb
blue "Confirmed UUID (password)：${uuid}" 
blue "Confirmed Vmess path：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
elif [ "$menu" = "2" ]; then
readp "Enter Vmess path, press Enter to keep unchanged: " menu
if [ -z "$menu" ]; then
echo
else
vmpath=$menu
echo $sbfiles | xargs -n1 sed -i "50s#$oldvmpath#$vmpath#g"
restartsb
fi
blue "Confirmed Vmess path：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
sbshare
else
changeserv
fi
}

listusers(){
echo
green "Current users list:"
echo
local i=1
while read -r user_uuid; do
if [[ -n "$user_uuid" ]]; then
echo -e "  ${yellow}$i${plain}. UUID: ${blue}$user_uuid${plain}"
((i++))
fi
done < <(jq -r '.inbounds[0].users[].uuid' /etc/s-box/sb.json 2>/dev/null)
echo
local total=$(jq '.inbounds[0].users | length' /etc/s-box/sb.json 2>/dev/null)
blue "Total users: $total"
echo
}

genuserlinks(){
local user_uuid=$1
if [[ -z "$user_uuid" ]]; then
red "UUID not provided"
return 1
fi

local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)
local vl_port=$(jq -r '.inbounds[0].listen_port' /etc/s-box/sb.json)
local vm_port=$(jq -r '.inbounds[1].listen_port' /etc/s-box/sb.json)
local hy2_port=$(jq -r '.inbounds[2].listen_port' /etc/s-box/sb.json)
local tu5_port=$(jq -r '.inbounds[3].listen_port' /etc/s-box/sb.json)
local vl_name=$(jq -r '.inbounds[0].tls.server_name' /etc/s-box/sb.json)
local public_key=$(cat /etc/s-box/public.key 2>/dev/null)
local short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /etc/s-box/sb.json)
local ws_path=$(jq -r '.inbounds[1].transport.path' /etc/s-box/sb.json)
local vm_name=$(jq -r '.inbounds[1].tls.server_name' /etc/s-box/sb.json)
local hy2_name=$(jq -r '.inbounds[2].tls.server_name' /etc/s-box/sb.json)
local tu5_name=$(jq -r '.inbounds[3].tls.server_name' /etc/s-box/sb.json)
local hostname=$(hostname)
local tls=$(jq -r '.inbounds[1].tls.enabled' /etc/s-box/sb.json)

local hy2_key_path=$(jq -r '.inbounds[2].tls.key_path' /etc/s-box/sb.json)
local tu5_key_path=$(jq -r '.inbounds[3].tls.key_path' /etc/s-box/sb.json)
local ins_hy2=1
local ins_tu5=1
[[ "$hy2_key_path" = '/etc/s-box/private.key' ]] && ins_hy2=0
[[ "$tu5_key_path" = '/etc/s-box/private.key' ]] && ins_tu5=0

local v6test=$(curl -s6m5 ip.sb 2>/dev/null)
if [[ -n "$v6test" ]]; then
sb_hy2_ip="[$server_ip]"
sb_tu5_ip="[$server_ip]"
else
sb_hy2_ip="$server_ip"
sb_tu5_ip="$server_ip"
fi

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "Share links for user: $user_uuid"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo
red "🚀【 Vless-reality-vision 】"
local vl_link="vless://$user_uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
echo -e "${yellow}$vl_link${plain}"
echo

red "🚀【 Vmess-ws 】"
if [[ "$tls" = "true" ]]; then
local vm_link="vmess://$(echo '{"add":"'$server_ip'","aid":"0","host":"'$vm_name'","id":"'$user_uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","type":"none","v":"2"}' | base64 -w 0)"
else
local vm_link="vmess://$(echo '{"add":"'$server_ip'","aid":"0","host":"'$vm_name'","id":"'$user_uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0)"
fi
echo -e "${yellow}$vm_link${plain}"
echo

red "🚀【 Hysteria-2 】"
local hy2_link="hysteria2://$user_uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&sni=$hy2_name#hy2-$hostname"
echo -e "${yellow}$hy2_link${plain}"
echo

red "🚀【 Tuic-v5 】"
local tu5_link="tuic://$user_uuid:$user_uuid@$sb_tu5_ip:$tu5_port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$tu5_name&allow_insecure=$ins_tu5&allowInsecure=$ins_tu5#tu5-$hostname"
echo -e "${yellow}$tu5_link${plain}"
echo

white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "QR codes:"
echo
green "Vless-reality QR code:"
qrencode -o - -t ANSIUTF8 "$vl_link"
echo
green "Vmess-ws QR code:"
qrencode -o - -t ANSIUTF8 "$vm_link"
echo
green "Hysteria2 QR code:"
qrencode -o - -t ANSIUTF8 "$hy2_link"
echo
green "Tuic5 QR code:"
qrencode -o - -t ANSIUTF8 "$tu5_link"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 Four-in-one aggregated subscription 】for user: $user_uuid"
echo
local aggr_links="$vl_link
$vm_link
$hy2_link
$tu5_link"
local aggr_base64=$(echo -e "$aggr_links" | base64 -w 0)
echo "Aggregated share link (base64):"
echo -e "${yellow}$aggr_base64${plain}"
echo
green "Aggregated subscription QR code:"
qrencode -o - -t ANSIUTF8 "$aggr_base64"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

adduser(){
sbactive
echo
green "Add new user for all protocols"
echo
readp "Enter UUID (press Enter to auto-generate): " new_uuid
if [[ -z "$new_uuid" ]]; then
new_uuid=$(/etc/s-box/sing-box generate uuid)
blue "Generated UUID: $new_uuid"
fi

if [[ ! "$new_uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
red "Invalid UUID format! Must be: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
return 1
fi

local exists=$(jq -r --arg uuid "$new_uuid" '.inbounds[0].users[] | select(.uuid == $uuid) | .uuid' /etc/s-box/sb.json 2>/dev/null)
if [[ -n "$exists" ]]; then
red "UUID already exists!"
return 1
fi

[[ "$sbnh" == "1.10" ]] && num=10 || num=11

tmp_file=$(mktemp)
jq --arg uuid "$new_uuid" '.inbounds[0].users += [{"uuid": $uuid, "flow": "xtls-rprx-vision"}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$new_uuid" '.inbounds[1].users += [{"uuid": $uuid, "alterId": 0}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$new_uuid" '.inbounds[2].users += [{"password": $uuid}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$new_uuid" '.inbounds[3].users += [{"uuid": $uuid, "password": $uuid}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

green "User added successfully!"
restartsb

genuserlinks "$new_uuid"
}

deluser(){
sbactive
listusers

local total=$(jq '.inbounds[0].users | length' /etc/s-box/sb.json 2>/dev/null)
if [[ "$total" -le 1 ]]; then
red "Cannot delete! At least one user must remain."
return 1
fi

readp "Enter UUID to delete: " del_uuid
if [[ -z "$del_uuid" ]]; then
red "UUID not provided"
return 1
fi

local exists=$(jq -r --arg uuid "$del_uuid" '.inbounds[0].users[] | select(.uuid == $uuid) | .uuid' /etc/s-box/sb.json 2>/dev/null)
if [[ -z "$exists" ]]; then
red "UUID not found!"
return 1
fi

[[ "$sbnh" == "1.10" ]] && num=10 || num=11

tmp_file=$(mktemp)
jq --arg uuid "$del_uuid" 'del(.inbounds[0].users[] | select(.uuid == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$del_uuid" 'del(.inbounds[1].users[] | select(.uuid == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$del_uuid" 'del(.inbounds[2].users[] | select(.password == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$del_uuid" 'del(.inbounds[3].users[] | select(.uuid == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

green "User deleted successfully!"
restartsb
}

manageusers(){
sbactive
echo
green "User Management"
yellow "1：Add new user"
yellow "2：Delete user"
yellow "3：List all users"
yellow "4：Generate share links for specific user"
yellow "0：Return to main menu"
readp "Please select [0-4]: " menu

case "$menu" in
1) adduser ;;
2) deluser ;;
3) listusers ;;
4)
listusers
readp "Enter UUID: " show_uuid
if [[ -n "$show_uuid" ]]; then
genuserlinks "$show_uuid"
fi
;;
0) sb ;;
*) manageusers ;;
esac
}

install_dumbproxy(){
if [[ -f /etc/dumbproxy/dumbproxy.cfg ]]; then
red "Dumbproxy is already installed!" && sleep 2 && manage_dumbproxy
return
fi

green "Installing Dumbproxy HTTPS Proxy..."

local arch_map
case "$(uname -m)" in
x86_64) arch_map="amd64" ;;
i386|i486|i586|i686) arch_map="386" ;;
aarch64) arch_map="arm64" ;;
armv5l|armv6l|armv7l|armhf) arch_map="arm" ;;
*) red "Unsupported architecture: $(uname -m)" && sleep 2 && sb ;;
esac

green "1. Downloading dumbproxy binary..."
mkdir -p /usr/local/bin
local tmp_file=$(mktemp)
if ! curl --no-progress-meter -Lo "$tmp_file" "https://github.com/SenseUnit/dumbproxy/releases/latest/download/dumbproxy.linux-${arch_map}"; then
red "Failed to download dumbproxy" && rm -f "$tmp_file" && sleep 2 && sb
fi
install "$tmp_file" /usr/local/bin/dumbproxy
rm -f "$tmp_file"

green "2. Downloading myip utility..."
tmp_file=$(mktemp)
if ! curl --no-progress-meter -Lo "$tmp_file" "https://github.com/Snawoot/myip/releases/latest/download/myip.linux-${arch_map}"; then
yellow "Warning: Failed to download myip, will use curl instead"
else
install "$tmp_file" /usr/local/bin/myip
rm -f "$tmp_file"
fi

green "3. Creating directories and generating password..."
mkdir -p /etc/dumbproxy
local dp_passwd=$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=10 2>/dev/null || echo "dumbproxy$(date +%s)" | head -c 10)
/usr/local/bin/dumbproxy -passwd /etc/dumbproxy/passwd "auto" "${dp_passwd}" 2>/dev/null || {
echo "auto:$(openssl passwd -apr1 "$dp_passwd")" > /etc/dumbproxy/passwd
}

green "4. Detecting external IP..."
local ext_ip
if [[ -f /usr/local/bin/myip ]]; then
ext_ip=$(/usr/local/bin/myip 2>/dev/null)
else
ext_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)
fi

if [[ -z "$ext_ip" ]]; then
red "Failed to detect external IP address" && sleep 2 && sb
fi

green "5. Installing acme.sh..."
if [[ ! -f /usr/local/bin/acme.sh ]]; then
curl --no-progress-meter -Lo /usr/local/bin/acme.sh 'https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh'
chmod +x /usr/local/bin/acme.sh
/usr/local/bin/acme.sh --install-cronjob 2>/dev/null || true
fi

green "6. Issuing SSL certificate for IP: $ext_ip..."
/usr/local/bin/acme.sh --issue \
-d "$ext_ip" \
--alpn \
--force \
--pre-hook "systemctl stop dumbproxy 2>/dev/null || true" \
--post-hook "[ -e /etc/dumbproxy/cert.pem -a -e /etc/dumbproxy/fullchain.pem ] && systemctl restart dumbproxy 2>/dev/null || true" \
--server letsencrypt \
--certificate-profile shortlived \
--days 3 2>/dev/null || yellow "Certificate issue may have warnings, continuing..."

/usr/local/bin/acme.sh --install-cert \
-d "$ext_ip" \
--cert-file /etc/dumbproxy/cert.pem \
--key-file /etc/dumbproxy/key.pem \
--fullchain-file /etc/dumbproxy/fullchain.pem \
--reloadcmd "systemctl restart dumbproxy 2>/dev/null || true" 2>/dev/null || true

if [[ ! -f /etc/dumbproxy/cert.pem ]]; then
yellow "Generating self-signed certificate as fallback..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/dumbproxy/key.pem \
-out /etc/dumbproxy/cert.pem \
-subj "/CN=$ext_ip" 2>/dev/null
cp /etc/dumbproxy/cert.pem /etc/dumbproxy/fullchain.pem
fi

green "7. Creating dumbproxy configuration..."
local dp_port=8443
if ss -tlnp 2>/dev/null | grep -q ":${dp_port} "; then
readp "Port $dp_port is in use. Enter custom port: " dp_port
if [[ -z "$dp_port" ]]; then
dp_port=9443
fi
fi

cat > /etc/dumbproxy/dumbproxy.cfg <<EOF
auth basicfile://?path=/etc/dumbproxy/passwd
bind-address :${dp_port}
cert /etc/dumbproxy/fullchain.pem
key /etc/dumbproxy/key.pem
EOF

echo "DP_PORT=$dp_port" > /etc/dumbproxy/config.env
echo "DP_IP=$ext_ip" >> /etc/dumbproxy/config.env
echo "DP_PASS=$dp_passwd" >> /etc/dumbproxy/config.env

green "8. Creating systemd service..."
cat > /etc/systemd/system/dumbproxy.service <<'EOF'
[Unit]
Description=Dumb Proxy - Simple HTTPS Proxy
Documentation=https://github.com/SenseUnit/dumbproxy
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/dumbproxy -config /etc/dumbproxy/dumbproxy.cfg
TimeoutStopSec=5s
PrivateTmp=true
ProtectSystem=full
LimitNOFILE=20000

[Install]
WantedBy=default.target
EOF

if [[ x"${release}" == x"alpine" ]]; then
green "9. Setting up OpenRC service for Alpine..."
cat > /etc/init.d/dumbproxy <<'EOF'
#!/sbin/openrc-run
name="dumbproxy"
description="Dumb Proxy - Simple HTTPS Proxy"
command="/usr/local/bin/dumbproxy"
command_args="-config /etc/dumbproxy/dumbproxy.cfg"
command_background="yes"
pidfile="/run/dumbproxy.pid"
EOF
chmod +x /etc/init.d/dumbproxy
rc-update add dumbproxy default 2>/dev/null
rc-service dumbproxy start 2>/dev/null
else
green "9. Starting systemd service..."
systemctl daemon-reload
systemctl enable dumbproxy
systemctl start dumbproxy
fi

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "Dumbproxy installation complete!"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "Proxy URL: ${yellow}https://auto:${dp_passwd}@${ext_ip}:${dp_port}${plain}"
echo
blue "Configuration:"
echo "  Protocol: HTTPS"
echo "  Host: $ext_ip"
echo "  Port: $dp_port"
echo "  Username: auto"
echo "  Password: $dp_passwd"
echo
yellow "Usage in browser/app:"
echo "  Set HTTPS proxy to: $ext_ip:$dp_port"
echo "  Authentication: auto / $dp_passwd"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

uninstall_dumbproxy(){
if [[ ! -f /etc/dumbproxy/dumbproxy.cfg ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

readp "Are you sure you want to uninstall Dumbproxy? [y/n]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
manage_dumbproxy
return
fi

green "Uninstalling Dumbproxy..."

if [[ x"${release}" == x"alpine" ]]; then
rc-service dumbproxy stop 2>/dev/null
rc-update del dumbproxy default 2>/dev/null
rm -f /etc/init.d/dumbproxy
else
systemctl stop dumbproxy 2>/dev/null
systemctl disable dumbproxy 2>/dev/null
rm -f /etc/systemd/system/dumbproxy.service
systemctl daemon-reload
fi

rm -rf /etc/dumbproxy
rm -f /usr/local/bin/dumbproxy
rm -f /usr/local/bin/myip

green "Dumbproxy uninstalled successfully!"
sleep 2
manage_dumbproxy
}

show_dumbproxy_info(){
if [[ ! -f /etc/dumbproxy/config.env ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

source /etc/dumbproxy/config.env

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "Dumbproxy Configuration"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "Proxy URL: ${yellow}https://auto:${DP_PASS}@${DP_IP}:${DP_PORT}${plain}"
echo
blue "Settings:"
echo "  Protocol: HTTPS"
echo "  Host: $DP_IP"
echo "  Port: $DP_PORT"
echo "  Username: auto"
echo "  Password: $DP_PASS"
echo
yellow "Browser setup:"
echo "  HTTPS Proxy: $DP_IP:$DP_PORT"
echo "  Auth: auto / $DP_PASS"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

restart_dumbproxy(){
if [[ ! -f /etc/dumbproxy/dumbproxy.cfg ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

green "Restarting Dumbproxy..."
if [[ x"${release}" == x"alpine" ]]; then
rc-service dumbproxy restart
else
systemctl restart dumbproxy
fi
green "Dumbproxy restarted successfully!"
sleep 2
manage_dumbproxy
}

list_dumbproxy_users(){
if [[ ! -f /etc/dumbproxy/passwd ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

echo
green "Dumbproxy Users List:"
echo

source /etc/dumbproxy/config.env 2>/dev/null

local user_count=0
while IFS=: read -r username hash; do
[[ -z "$username" ]] && continue
((user_count++))
echo -e "  ${yellow}$user_count.${plain} User: ${blue}$username${plain}"
if [[ "$username" == "auto" && -n "$DP_PASS" ]]; then
echo -e "     Password: $DP_PASS"
else
echo -e "     Password: ${red}(stored as hash, not available)${plain}"
fi
echo -e "     URL: https://${username}:PASSWORD@${DP_IP}:${DP_PORT}"
echo
done < /etc/dumbproxy/passwd

if [[ "$user_count" -eq 0 ]]; then
yellow "No users found!"
fi

blue "Total users: $user_count"
echo
}

add_dumbproxy_user(){
if [[ ! -f /etc/dumbproxy/passwd ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

echo
green "Add new Dumbproxy user"
echo

readp "Enter username: " new_user
if [[ -z "$new_user" ]]; then
red "Username is required!" && sleep 2 && manage_dumbproxy_users
return
fi

if grep -q "^${new_user}:" /etc/dumbproxy/passwd 2>/dev/null; then
red "Username '$new_user' already exists!" && sleep 2 && manage_dumbproxy_users
return
fi

readp "Enter password (press Enter for auto-generate): " new_pass
if [[ -z "$new_pass" ]]; then
new_pass=$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=12 2>/dev/null || echo "dppass$(date +%s)" | head -c 12)
fi

green "Adding user '$new_user'..."

if [[ -f /usr/local/bin/dumbproxy ]]; then
/usr/local/bin/dumbproxy -passwd /etc/dumbproxy/passwd "$new_user" "$new_pass" 2>/dev/null || {
echo "${new_user}:$(openssl passwd -apr1 "$new_pass")" >> /etc/dumbproxy/passwd
}
else
echo "${new_user}:$(openssl passwd -apr1 "$new_pass")" >> /etc/dumbproxy/passwd
fi

source /etc/dumbproxy/config.env 2>/dev/null

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "User added successfully!"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "Username: ${blue}$new_user${plain}"
echo -e "Password: ${blue}$new_pass${plain}"
echo -e "Proxy URL: ${yellow}https://${new_user}:${new_pass}@${DP_IP}:${DP_PORT}${plain}"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

delete_dumbproxy_user(){
if [[ ! -f /etc/dumbproxy/passwd ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

local user_count=$(wc -l < /etc/dumbproxy/passwd | tr -d ' ')

if [[ "$user_count" -le 1 ]]; then
red "Cannot delete! At least one user must remain." && sleep 2 && manage_dumbproxy_users
return
fi

list_dumbproxy_users

readp "Enter username to delete: " del_user

if [[ -z "$del_user" ]]; then
red "Username not provided" && sleep 2 && manage_dumbproxy_users
return
fi

if ! grep -q "^${del_user}:" /etc/dumbproxy/passwd 2>/dev/null; then
red "Username '$del_user' not found!" && sleep 2 && manage_dumbproxy_users
return
fi

readp "Confirm delete user '$del_user'? [y/n]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
manage_dumbproxy_users
return
fi

green "Deleting user '$del_user'..."

sed -i "/^${del_user}:/d" /etc/dumbproxy/passwd

green "User '$del_user' deleted successfully!"
sleep 2
manage_dumbproxy_users
}

manage_dumbproxy_users(){
if [[ ! -f /etc/dumbproxy/passwd ]]; then
red "Dumbproxy is not installed!" && sleep 2 && manage_dumbproxy
return
fi

echo
green "Dumbproxy User Management"
echo
local user_count=$(wc -l < /etc/dumbproxy/passwd | tr -d ' ')
blue "Current users: $user_count"
echo
yellow "1：Add new user"
yellow "2：Delete user"
yellow "3：List all users"
yellow "0：Return to previous menu"
readp "Please select [0-3]: " menu

case "$menu" in
1) add_dumbproxy_user ;;
2) delete_dumbproxy_user ;;
3) list_dumbproxy_users ;;
0) manage_dumbproxy ;;
*) manage_dumbproxy_users ;;
esac
}

manage_dumbproxy(){
echo
green "Dumbproxy HTTPS Proxy Management"
echo
if [[ -f /etc/dumbproxy/dumbproxy.cfg ]]; then
blue "Status: Installed"
local user_count=$(wc -l < /etc/dumbproxy/passwd 2>/dev/null | tr -d ' ')
echo "Users: $user_count"
else
blue "Status: Not installed"
fi
echo
yellow "1：Install Dumbproxy (auto SSL certificate for IP)"
yellow "2：Uninstall Dumbproxy"
yellow "3：Show proxy credentials"
yellow "4：Restart Dumbproxy service"
yellow "5：Manage Dumbproxy users (add/delete/list)"
yellow "0：Return to main menu"
readp "Please select [0-5]: " menu

case "$menu" in
1) install_dumbproxy ;;
2) uninstall_dumbproxy ;;
3) show_dumbproxy_info ;;
4) restart_dumbproxy ;;
5) manage_dumbproxy_users ;;
0) sb ;;
*) manage_dumbproxy ;;
esac
}

check_socks5_exists(){
local inbound_count=$(jq '.inbounds | length' /etc/s-box/sb.json 2>/dev/null)
if [[ "$inbound_count" -ge 5 ]]; then
local inbound_type=$(jq -r '.inbounds[4].type' /etc/s-box/sb.json 2>/dev/null)
if [[ "$inbound_type" == "socks" ]]; then
return 0
fi
fi
return 1
}

install_socks5(){
sbactive

if check_socks5_exists; then
red "SOCKS5 proxy is already enabled!" && sleep 2 && manage_socks5
return
fi

green "Enabling SOCKS5 proxy in Sing-box..."

local socks_port=1080
if ss -tlnp 2>/dev/null | grep -q ":${socks_port} "; then
readp "Port $socks_port is in use. Enter custom port: " socks_port
if [[ -z "$socks_port" ]]; then
socks_port=10800
fi
fi

local socks_user="socks5"
local socks_pass=$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=12 2>/dev/null || echo "socks5pass$(date +%s)" | head -c 12)

green "Adding SOCKS5 inbound to configuration..."

local tmp_file=$(mktemp)
jq --arg port "$socks_port" --arg user "$socks_user" --arg pass "$socks_pass" '
.inbounds += [{
"type": "socks",
"tag": "socks5-in",
"listen": "::",
"listen_port": ($port | tonumber),
"users": [{
"username": $user,
"password": $pass
}]
}]
' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

echo "SOCKS5_PORT=$socks_port" > /etc/s-box/socks5.env
echo "SOCKS5_USER=$socks_user" >> /etc/s-box/socks5.env
echo "SOCKS5_PASS=$socks_pass" >> /etc/s-box/socks5.env

restartsb

local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "SOCKS5 proxy enabled successfully!"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "SOCKS5 URL: ${yellow}socks5://${socks_user}:${socks_pass}@${server_ip}:${socks_port}${plain}"
echo
blue "Configuration:"
echo "  Host: $server_ip"
echo "  Port: $socks_port"
echo "  Username: $socks_user"
echo "  Password: $socks_pass"
echo
yellow "Telegram setup:"
echo "  Settings → Data and Storage → Proxy → SOCKS5"
echo "  Server: $server_ip:$socks_port"
echo "  User: $socks_user"
echo "  Password: $socks_pass"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

uninstall_socks5(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

green "Disabling SOCKS5 proxy..."

local tmp_file=$(mktemp)
jq 'del(.inbounds[4])' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

rm -f /etc/s-box/socks5.env

restartsb

green "SOCKS5 proxy disabled successfully!"
sleep 2
manage_socks5
}

show_socks5_info(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

if [[ ! -f /etc/s-box/socks5.env ]]; then
local socks_port=$(jq -r '.inbounds[4].listen_port' /etc/s-box/sb.json)
local socks_user=$(jq -r '.inbounds[4].users[0].username' /etc/s-box/sb.json)
local socks_pass=$(jq -r '.inbounds[4].users[0].password' /etc/s-box/sb.json)
else
source /etc/s-box/socks5.env
fi

local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "SOCKS5 Proxy Configuration"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "SOCKS5 URL: ${yellow}socks5://${socks_user}:${socks_pass}@${server_ip}:${socks_port}${plain}"
echo
blue "Settings:"
echo "  Host: $server_ip"
echo "  Port: $socks_port"
echo "  Username: $socks_user"
echo "  Password: $socks_pass"
echo
yellow "Telegram setup:"
echo "  Settings → Data and Storage → Proxy"
echo "  Add Proxy → SOCKS5"
echo "  Server: $server_ip:$socks_port"
echo "  User: $socks_user"
echo "  Password: $socks_pass"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

change_socks5_creds(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

readp "Enter new username (press Enter to keep current): " new_user
readp "Enter new password (press Enter for auto-generate): " new_pass

if [[ -z "$new_user" ]]; then
new_user=$(jq -r '.inbounds[4].users[0].username' /etc/s-box/sb.json)
fi

if [[ -z "$new_pass" ]]; then
new_pass=$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=12 2>/dev/null || echo "socks5pass$(date +%s)" | head -c 12)
fi

green "Updating SOCKS5 credentials..."

local tmp_file=$(mktemp)
jq --arg user "$new_user" --arg pass "$new_pass" '
.inbounds[4].users[0].username = $user |
.inbounds[4].users[0].password = $pass
' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

echo "SOCKS5_USER=$new_user" > /etc/s-box/socks5.env
echo "SOCKS5_PASS=$new_pass" >> /etc/s-box/socks5.env
local socks_port=$(jq -r '.inbounds[4].listen_port' /etc/s-box/sb.json)
echo "SOCKS5_PORT=$socks_port" >> /etc/s-box/socks5.env

restartsb

green "SOCKS5 credentials updated!"
show_socks5_info
}

list_socks5_users(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

echo
green "SOCKS5 Users List:"
echo

local user_count=$(jq '.inbounds[4].users | length' /etc/s-box/sb.json 2>/dev/null)
local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)
local socks_port=$(jq -r '.inbounds[4].listen_port' /etc/s-box/sb.json)

if [[ "$user_count" -eq 0 ]]; then
yellow "No users found!"
return
fi

for ((i=0; i<user_count; i++)); do
local username=$(jq -r ".inbounds[4].users[$i].username" /etc/s-box/sb.json)
local password=$(jq -r ".inbounds[4].users[$i].password" /etc/s-box/sb.json)
echo -e "  ${yellow}$((i+1)).${plain} User: ${blue}$username${plain}"
echo -e "     Password: $password"
echo -e "     URL: socks5://${username}:${password}@${server_ip}:${socks_port}"
echo
done

blue "Total users: $user_count"
echo
}

add_socks5_user(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

echo
green "Add new SOCKS5 user"
echo

readp "Enter username (press Enter for auto-generate): " new_user
if [[ -z "$new_user" ]]; then
local user_count=$(jq '.inbounds[4].users | length' /etc/s-box/sb.json 2>/dev/null)
new_user="socks5_$((user_count + 1))"
fi

local existing=$(jq -r --arg user "$new_user" '.inbounds[4].users[] | select(.username == $user) | .username' /etc/s-box/sb.json 2>/dev/null)
if [[ -n "$existing" ]]; then
red "Username '$new_user' already exists!" && sleep 2 && manage_socks5_users
return
fi

readp "Enter password (press Enter for auto-generate): " new_pass
if [[ -z "$new_pass" ]]; then
new_pass=$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=12 2>/dev/null || echo "socks5pass$(date +%s)" | head -c 12)
fi

green "Adding user '$new_user'..."

local tmp_file=$(mktemp)
jq --arg user "$new_user" --arg pass "$new_pass" '
.inbounds[4].users += [{"username": $user, "password": $pass}]
' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

restartsb

local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)
local socks_port=$(jq -r '.inbounds[4].listen_port' /etc/s-box/sb.json)

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "User added successfully!"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "Username: ${blue}$new_user${plain}"
echo -e "Password: ${blue}$new_pass${plain}"
echo -e "SOCKS5 URL: ${yellow}socks5://${new_user}:${new_pass}@${server_ip}:${socks_port}${plain}"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

delete_socks5_user(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

local user_count=$(jq '.inbounds[4].users | length' /etc/s-box/sb.json 2>/dev/null)

if [[ "$user_count" -le 1 ]]; then
red "Cannot delete! At least one user must remain." && sleep 2 && manage_socks5_users
return
fi

list_socks5_users

readp "Enter username to delete: " del_user

if [[ -z "$del_user" ]]; then
red "Username not provided" && sleep 2 && manage_socks5_users
return
fi

local existing=$(jq -r --arg user "$del_user" '.inbounds[4].users[] | select(.username == $user) | .username' /etc/s-box/sb.json 2>/dev/null)
if [[ -z "$existing" ]]; then
red "Username '$del_user' not found!" && sleep 2 && manage_socks5_users
return
fi

readp "Confirm delete user '$del_user'? [y/n]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
manage_socks5_users
return
fi

green "Deleting user '$del_user'..."

local tmp_file=$(mktemp)
jq --arg user "$del_user" 'del(.inbounds[4].users[] | select(.username == $user))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json

[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

restartsb

green "User '$del_user' deleted successfully!"
sleep 2
manage_socks5_users
}

manage_socks5_users(){
sbactive

if ! check_socks5_exists; then
red "SOCKS5 proxy is not enabled!" && sleep 2 && manage_socks5
return
fi

echo
green "SOCKS5 User Management"
echo
local user_count=$(jq '.inbounds[4].users | length' /etc/s-box/sb.json 2>/dev/null)
blue "Current users: $user_count"
echo
yellow "1：Add new user"
yellow "2：Delete user"
yellow "3：List all users"
yellow "0：Return to previous menu"
readp "Please select [0-3]: " menu

case "$menu" in
1) add_socks5_user ;;
2) delete_socks5_user ;;
3) list_socks5_users ;;
0) manage_socks5 ;;
*) manage_socks5_users ;;
esac
}

manage_socks5(){
sbactive
echo
green "SOCKS5 Proxy Management (via Sing-box)"
echo
if check_socks5_exists; then
blue "Status: Enabled"
local socks_port=$(jq -r '.inbounds[4].listen_port' /etc/s-box/sb.json 2>/dev/null)
local user_count=$(jq '.inbounds[4].users | length' /etc/s-box/sb.json 2>/dev/null)
echo "Port: $socks_port"
echo "Users: $user_count"
else
blue "Status: Disabled"
fi
echo
yellow "1：Enable SOCKS5 proxy"
yellow "2：Disable SOCKS5 proxy"
yellow "3：Show SOCKS5 credentials"
yellow "4：Manage SOCKS5 users (add/delete/list)"
yellow "0：Return to main menu"
readp "Please select [0-4]: " menu

case "$menu" in
1) install_socks5 ;;
2) uninstall_socks5 ;;
3) show_socks5_info ;;
4) manage_socks5_users ;;
0) sb ;;
*) manage_socks5 ;;
esac
}

check_docker(){
if command -v docker &> /dev/null; then
return 0
fi

green "Docker not detected, installing..."

if [[ x"${release}" == x"alpine" ]]; then
apk update
apk add docker docker-cli-compose
rc-update add docker boot 2>/dev/null
rc-service docker start 2>/dev/null
else
if [ -x "$(command -v apt-get)" ]; then
apt-get update
apt-get install -y docker.io docker-compose
elif [ -x "$(command -v yum)" ]; then
yum install -y docker docker-compose
elif [ -x "$(command -v dnf)" ]; then
dnf install -y docker docker-compose
fi

if [[ x"${release}" != x"alpine" ]]; then
systemctl enable docker
systemctl start docker
fi
fi

if command -v docker &> /dev/null; then
green "Docker installed successfully!"
return 0
else
red "Failed to install Docker!"
return 1
fi
}

install_mtproto(){
if [[ -f /etc/mtproto/config.env ]]; then
red "MTProto proxy is already installed!" && sleep 2 && manage_mtproto
return
fi

green "Installing MTProto Proxy for Telegram..."

if ! check_docker; then
red "Docker installation failed. Cannot continue." && sleep 2 && sb
return
fi

green "1. Configuring port..."
local mtp_port=443

get_used_ports(){
ss -tunlp 2>/dev/null | awk '{print $5}' | sed 's/.*://' | grep -E '^[0-9]+$' | sort -u
}

local used_ports=$(get_used_ports)

check_port_used(){
local port=$1
echo "$used_ports" | grep -q "^${port}$"
}

if check_port_used "$mtp_port"; then
yellow "Port $mtp_port is already in use!"
echo "Used ports detected: $(echo $used_ports | tr '\n' ' ')"
readp "Enter custom port for MTProto proxy (default 8443): " mtp_port
if [[ -z "$mtp_port" ]]; then
mtp_port=8443
fi
while check_port_used "$mtp_port"; do
yellow "Port $mtp_port is also in use!"
readp "Enter another port: " mtp_port
if [[ -z "$mtp_port" ]]; then
mtp_port=$((RANDOM % 55535 + 10000))
yellow "Using random port: $mtp_port"
fi
done
fi

green "Port selected: $mtp_port"

green "2. Selecting Fake TLS domain..."
echo
yellow "Popular domains for Fake TLS:"
echo "  1) google.com (Recommended)"
echo "  2) cloudflare.com"
echo "  3) microsoft.com"
echo "  4) apple.com"
echo "  5) amazon.com"
echo "  6) github.com"
echo "  7) Enter custom domain"
echo
readp "Select domain [1-7, default=1]: " domain_choice

case "$domain_choice" in
2) mtp_domain="cloudflare.com" ;;
3) mtp_domain="microsoft.com" ;;
4) mtp_domain="apple.com" ;;
5) mtp_domain="amazon.com" ;;
6) mtp_domain="github.com" ;;
7) 
readp "Enter custom domain for Fake TLS: " mtp_domain
if [[ -z "$mtp_domain" ]]; then
mtp_domain="google.com"
fi
;;
*) mtp_domain="google.com" ;;
esac

green "Domain selected: $mtp_domain"

green "3. Generating secret..."
local mtp_secret=$(head -c 16 /dev/urandom | xxd -ps)
green "Secret generated: $mtp_secret"

green "4. Detecting external IP..."
local mtp_ip
mtp_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s4m5 icanhazip.com 2>/dev/null)

if [[ -z "$mtp_ip" ]]; then
mtp_ip=$(curl -s6m5 ip.sb 2>/dev/null || curl -s6m5 icanhazip.com 2>/dev/null)
fi

if [[ -z "$mtp_ip" ]]; then
red "Failed to detect external IP address" && sleep 2 && sb
return
fi

green "External IP: $mtp_ip"

green "5. Pulling MTProto proxy image and starting container..."
docker pull telegrammessenger/proxy:latest 2>/dev/null

docker run -d \
--name mtproto-proxy \
--restart always \
-p ${mtp_port}:443 \
-e SECRET=${mtp_secret} \
-e TAG=${mtp_domain} \
telegrammessenger/proxy:latest

if [[ $? -ne 0 ]]; then
red "Failed to start MTProto proxy container!" && sleep 2 && sb
return
fi

green "6. Saving configuration..."
mkdir -p /etc/mtproto
cat > /etc/mtproto/config.env <<EOF
MTP_PORT=${mtp_port}
MTP_SECRET=${mtp_secret}
MTP_DOMAIN=${mtp_domain}
MTP_IP=${mtp_ip}
EOF

sleep 2

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "MTProto Proxy Installation Complete!"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "MTProto Link: ${yellow}tg://proxy?server=${mtp_ip}&port=${mtp_port}&secret=${mtp_secret}${plain}"
echo
blue "Manual Configuration:"
echo "  Server: $mtp_ip"
echo "  Port: $mtp_port"
echo "  Secret: $mtp_secret"
echo "  Fake TLS Domain: $mtp_domain"
echo
yellow "Usage in Telegram:"
echo "  1. Click the MTProto link above to auto-configure"
echo "  2. Or manually add proxy in Telegram settings"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

uninstall_mtproto(){
if [[ ! -f /etc/mtproto/config.env ]]; then
red "MTProto proxy is not installed!" && sleep 2 && manage_mtproto
return
fi

readp "Are you sure you want to uninstall MTProto proxy? [y/n]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
manage_mtproto
return
fi

green "Uninstalling MTProto Proxy..."

docker stop mtproto-proxy 2>/dev/null
docker rm mtproto-proxy 2>/dev/null

rm -rf /etc/mtproto

green "MTProto proxy uninstalled successfully!"
sleep 2
manage_mtproto
}

show_mtproto_info(){
if [[ ! -f /etc/mtproto/config.env ]]; then
red "MTProto proxy is not installed!" && sleep 2 && manage_mtproto
return
fi

source /etc/mtproto/config.env

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "MTProto Proxy Configuration"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "MTProto Link: ${yellow}tg://proxy?server=${MTP_IP}&port=${MTP_PORT}&secret=${MTP_SECRET}${plain}"
echo
blue "Connection Details:"
echo "  Server: $MTP_IP"
echo "  Port: $MTP_PORT"
echo "  Secret: $MTP_SECRET"
echo "  Fake TLS Domain: $MTP_DOMAIN"
echo
yellow "Usage in Telegram:"
echo "  1. Click the MTProto link above to auto-configure"
echo "  2. Or go to Settings > Data and Storage > Proxy > Add Proxy"
echo "  3. Select MTProto and enter the details above"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

restart_mtproto(){
if [[ ! -f /etc/mtproto/config.env ]]; then
red "MTProto proxy is not installed!" && sleep 2 && manage_mtproto
return
fi

green "Restarting MTProto Proxy..."
docker restart mtproto-proxy 2>/dev/null

if [[ $? -eq 0 ]]; then
green "MTProto proxy restarted successfully!"
else
red "Failed to restart MTProto proxy!"
fi
sleep 2
manage_mtproto
}

view_mtproto_logs(){
if [[ ! -f /etc/mtproto/config.env ]]; then
red "MTProto proxy is not installed!" && sleep 2 && manage_mtproto
return
fi

echo
green "MTProto Proxy Logs (last 50 lines):"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
docker logs --tail 50 mtproto-proxy 2>&1
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp "Press Enter to return to menu..."
manage_mtproto
}

manage_mtproto(){
echo
green "MTProto Proxy Management (for Telegram)"
echo
if [[ -f /etc/mtproto/config.env ]]; then
blue "Status: Installed"
source /etc/mtproto/config.env 2>/dev/null
echo "Port: $MTP_PORT"
echo "Domain: $MTP_DOMAIN"
if docker ps | grep -q mtproto-proxy; then
echo "Container: Running"
else
echo "Container: Stopped"
fi
else
blue "Status: Not installed"
fi
echo
yellow "1：Install MTProto proxy (requires Docker)"
yellow "2：Uninstall MTProto proxy"
yellow "3：Show proxy credentials and link"
yellow "4：Restart MTProto proxy"
yellow "5：View logs"
yellow "0：Return to main menu"
readp "Please select [0-5]: " menu

case "$menu" in
1) install_mtproto ;;
2) uninstall_mtproto ;;
3) show_mtproto_info ;;
4) restart_mtproto ;;
5) view_mtproto_logs ;;
0) sb ;;
*) manage_mtproto ;;
esac
}

changeip(){
v4v6
chip(){
rpip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy')
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sed -i "111s/$rpip/$rrpip/g" /etc/s-box/sb10.json
sed -i "134s/$rpip/$rrpip/g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
}
readp "1. IPV4 preferred\n2. IPV6 preferred\n3. IPV4 only\n4. IPV6 only\nPlease select: " choose
if [[ $choose == "1" && -n $v4 ]]; then
rrpip="prefer_ipv4" && chip && v4_6="IPV4 preferred ($v4)"
elif [[ $choose == "2" && -n $v6 ]]; then
rrpip="prefer_ipv6" && chip && v4_6="IPV6 preferred ($v6)"
elif [[ $choose == "3" && -n $v4 ]]; then
rrpip="ipv4_only" && chip && v4_6="IPV4 only ($v4)"
elif [[ $choose == "4" && -n $v6 ]]; then
rrpip="ipv6_only" && chip && v4_6="IPV6 only ($v6)"
else 
red "Selected IPV4/IPV6 address does not exist, or input error" && changeip
fi
blue "Current IP priority changed to: ${v4_6}" && sb
}

tgsbshow(){
echo
yellow "1：Reset/Set Telegram bot Token and user ID"
yellow "0：Return to previous menu"
readp "Please select【0-1】：" menu
if [ "$menu" = "1" ]; then
rm -rf /etc/s-box/sbtg.sh
readp "Enter Telegram bot Token: " token
telegram_token=$token
readp "Enter Telegram bot user ID: " userid
telegram_id=$userid
echo '#!/bin/bash
export LANG=en_US.UTF-8

total_lines=$(wc -l < /etc/s-box/clash_meta_client.yaml)
half=$((total_lines / 2))
head -n $half /etc/s-box/clash_meta_client.yaml > /etc/s-box/clash_meta_client1.txt
tail -n +$((half + 1)) /etc/s-box/clash_meta_client.yaml > /etc/s-box/clash_meta_client2.txt

total_lines=$(wc -l < /etc/s-box/sing_box_client.json)
quarter=$((total_lines / 4))
head -n $quarter /etc/s-box/sing_box_client.json > /etc/s-box/sing_box_client1.txt
tail -n +$((quarter + 1)) /etc/s-box/sing_box_client.json | head -n $quarter > /etc/s-box/sing_box_client2.txt
tail -n +$((2 * quarter + 1)) /etc/s-box/sing_box_client.json | head -n $quarter > /etc/s-box/sing_box_client3.txt
tail -n +$((3 * quarter + 1)) /etc/s-box/sing_box_client.json > /etc/s-box/sing_box_client4.txt

m1=$(cat /etc/s-box/vl_reality.txt 2>/dev/null)
m2=$(cat /etc/s-box/vm_ws.txt 2>/dev/null)
m3=$(cat /etc/s-box/vm_ws_argols.txt 2>/dev/null)
m3_5=$(cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null)
m4=$(cat /etc/s-box/vm_ws_tls.txt 2>/dev/null)
m5=$(cat /etc/s-box/hy2.txt 2>/dev/null)
m6=$(cat /etc/s-box/tuic5.txt 2>/dev/null)
m7=$(cat /etc/s-box/sing_box_client1.txt 2>/dev/null)
m7_5=$(cat /etc/s-box/sing_box_client2.txt 2>/dev/null)
m7_5_5=$(cat /etc/s-box/sing_box_client3.txt 2>/dev/null)
m7_5_5_5=$(cat /etc/s-box/sing_box_client4.txt 2>/dev/null)
m8=$(cat /etc/s-box/clash_meta_client1.txt 2>/dev/null)
m8_5=$(cat /etc/s-box/clash_meta_client2.txt 2>/dev/null)
m9=$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)
m10=$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)
m11=$(cat /etc/s-box/jh_sub.txt 2>/dev/null)
message_text_m1=$(echo "$m1")
message_text_m2=$(echo "$m2")
message_text_m3=$(echo "$m3")
message_text_m3_5=$(echo "$m3_5")
message_text_m4=$(echo "$m4")
message_text_m5=$(echo "$m5")
message_text_m6=$(echo "$m6")
message_text_m7=$(echo "$m7")
message_text_m7_5=$(echo "$m7_5")
message_text_m7_5_5=$(echo "$m7_5_5")
message_text_m7_5_5_5=$(echo "$m7_5_5_5")
message_text_m8=$(echo "$m8")
message_text_m8_5=$(echo "$m8_5")
message_text_m9=$(echo "$m9")
message_text_m10=$(echo "$m10")
message_text_m11=$(echo "$m11")
MODE=HTML
URL="https://api.telegram.org/bottelegram_token/sendMessage"
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vless-reality-vision Share link 】: Supports nekobox "$'"'"'\n\n'"'"'"${message_text_m1}")
if [[ -f /etc/s-box/vm_ws.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws Share link 】: Supports v2rayng, nekobox "$'"'"'\n\n'"'"'"${message_text_m2}")
fi
if [[ -f /etc/s-box/vm_ws_argols.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argotemporary domain Share link 】: Supports v2rayng, nekobox "$'"'"'\n\n'"'"'"${message_text_m3}")
fi
if [[ -f /etc/s-box/vm_ws_argogd.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argofixed domain Share link 】: Supports v2rayng, nekobox "$'"'"'\n\n'"'"'"${message_text_m3_5}")
fi
if [[ -f /etc/s-box/vm_ws_tls.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws-tls Share link 】: Supports v2rayng, nekobox "$'"'"'\n\n'"'"'"${message_text_m4}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Hysteria-2 Share link 】: Supports nekobox "$'"'"'\n\n'"'"'"${message_text_m5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Tuic-v5 Share link 】: Supports nekobox "$'"'"'\n\n'"'"'"${message_text_m6}")

if [[ -f /etc/s-box/sing_box_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box subscription links 】: Supports SFA, SFW, SFI "$'"'"'\n\n'"'"'"${message_text_m9}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box config files(4 parts) 】: Supports SFA, SFW, SFI "$'"'"'\n\n'"'"'"${message_text_m7}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5_5}")
fi

if [[ -f /etc/s-box/clash_meta_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Clash-meta subscription links 】: Supports Clash-meta related clients "$'"'"'\n\n'"'"'"${message_text_m10}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Clash-meta config files(2 parts) 】: Supports Clash-meta related clients "$'"'"'\n\n'"'"'"${message_text_m8}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m8_5}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Four-in-one protocol aggregated subscription links 】: Supports nekobox "$'"'"'\n\n'"'"'"${message_text_m11}")

if [ $? == 124 ];then
echo TG_api request timeout, please check if network has restarted and can access TG
fi
resSuccess=$(echo "$res" | jq -r ".ok")
if [[ $resSuccess = "true" ]]; then
echo "TG push successful";
else
echo "TG push failed, please check TG bot Token and ID";
fi
' > /etc/s-box/sbtg.sh
sed -i "s/telegram_token/$telegram_token/g" /etc/s-box/sbtg.sh
sed -i "s/telegram_id/$telegram_id/g" /etc/s-box/sbtg.sh
green "Setup complete! Please ensure TG bot is activated!"
tgnotice
else
changeserv
fi
}

tgnotice(){
if [[ -f /etc/s-box/sbtg.sh ]]; then
green "Please wait 5 seconds, TG bot is preparing to push..."
sbshare > /dev/null 2>&1
bash /etc/s-box/sbtg.sh
else
yellow "TG notification not configured"
fi
exit
}

changeserv(){
sbactive
echo
green "Sing-box configuration change options:"
readp "1：Change Reality domain disguise address, switch between self-signed certificate and Acme domain certificate, enable/disable TLS\n2：Change UUID (password) for all protocols, Vmess-Path\n3：Set Argo temporary tunnel, fixed tunnel\n4：Switch IPV4 or IPV6 proxy priority\n5：Set Telegram push node notification\n6：Change Warp-wireguard outbound account\n7：Set Gitlab subscription Share link\n8：Set CDN optimized address for all Vmess nodes\n0：Return to previous menu\nPlease select [0-8]: " menu
if [ "$menu" = "1" ];then
changeym
elif [ "$menu" = "2" ];then
changeuuid
elif [ "$menu" = "3" ];then
cfargo_ym
elif [ "$menu" = "4" ];then
changeip
elif [ "$menu" = "5" ];then
tgsbshow
elif [ "$menu" = "6" ];then
changewg
elif [ "$menu" = "7" ];then
gitlabsub
elif [ "$menu" = "8" ];then
vmesscfadd
else 
sb
fi
}

vmesscfadd(){
echo
green "Recommended to use stable official CDN domains from major global companies or organizations as CDN optimized address:"
blue "www.visa.com.sg"
blue "www.wto.org"
blue "www.web.com"
echo
yellow "1：Custom CDN optimized address for Vmess-ws(tls) main protocol node"
yellow "2：For option 1, reset client host/sni domain (domain with IP resolved to CF)"
yellow "3：Custom CDN optimized address for Vmess-ws(tls)-Argo node"
yellow "0：Return to previous menu"
readp "Please select【0-3】：" menu
if [ "$menu" = "1" ]; then
echo
green "Please ensure VPS IP is resolved to a domain on Cloudflare"
if [[ ! -f /etc/s-box/cfymjx.txt ]] 2>/dev/null; then
readp "Enter client host/sni domain (domain with IP resolved to CF): " menu
echo "$menu" > /etc/s-box/cfymjx.txt
fi
echo
readp "Enter custom optimized IP/domain: " menu
echo "$menu" > /etc/s-box/cfvmadd_local.txt
green "Setup successful, select Main Menu 9 to update node configuration" && sleep 2 && vmesscfadd
elif  [ "$menu" = "2" ]; then
rm -rf /etc/s-box/cfymjx.txt
green "Reset successful, can select 1 to set up again" && sleep 2 && vmesscfadd
elif  [ "$menu" = "3" ]; then
readp "Enter custom optimized IP/domain: " menu
echo "$menu" > /etc/s-box/cfvmadd_argo.txt
green "Setup successful, select Main Menu 9 to update node configuration" && sleep 2 && vmesscfadd
else
changeserv
fi
}

gitlabsub(){
echo
green "Please ensure project is created on Gitlab website, push function is enabled, and access token is obtained"
yellow "1：Reset/Set Gitlab subscription links"
yellow "0：Return to previous menu"
readp "Please select【0-1】：" menu
if [ "$menu" = "1" ]; then
cd /etc/s-box
readp "Enter login email: " email
readp "Enter access token: " token
readp "Enter username: " userid
readp "Enter project name: " project
echo
green "Multiple VPS can share one token and project name, can create multiple branch subscription links"
green "Enter to skip means not creating new branch, only use main branch subscription links (recommended for first VPS to skip)"
readp "New branch name: " gitlabml
echo
if [[ -z "$gitlabml" ]]; then
gitlab_ml=''
git_sk=main
rm -rf /etc/s-box/gitlab_ml_ml
else
gitlab_ml=":${gitlabml}"
git_sk="${gitlabml}"
echo "${gitlab_ml}" > /etc/s-box/gitlab_ml_ml
fi
echo "$token" > /etc/s-box/gitlabtoken.txt
rm -rf /etc/s-box/.git
git init >/dev/null 2>&1
git add sing_box_client.json clash_meta_client.yaml jh_sub.txt >/dev/null 2>&1
git config --global user.email "${email}" >/dev/null 2>&1
git config --global user.name "${userid}" >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
branches=$(git branch)
if [[ $branches == *master* ]]; then
git branch -m master main >/dev/null 2>&1
fi
git remote add origin https://${token}@gitlab.com/${userid}/${project}.git >/dev/null 2>&1
if [[ $(ls -a | grep '^\.git$') ]]; then
cat > /etc/s-box/gitpush.sh <<EOF
#!/usr/bin/expect
spawn bash -c "git push -f origin main${gitlab_ml}"
expect "Password for 'https://$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)@gitlab.com':"
send "$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)\r"
interact
EOF
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/sing_box_client.json/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/sing_box_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/clash_meta_client.yaml/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/clash_meta_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/jh_sub.txt/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/jh_sub_gitlab.txt
clsbshow
else
yellow "Gitlab subscription links setup failed, please report"
fi
cd
else
changeserv
fi
}

gitlabsubgo(){
cd /etc/s-box
if [[ $(ls -a | grep '^\.git$') ]]; then
if [ -f /etc/s-box/gitlab_ml_ml ]; then
gitlab_ml=$(cat /etc/s-box/gitlab_ml_ml)
fi
git rm --cached sing_box_client.json clash_meta_client.yaml jh_sub.txt >/dev/null 2>&1
git commit -m "commit_rm_$(date +"%F %T")" >/dev/null 2>&1
git add sing_box_client.json clash_meta_client.yaml jh_sub.txt >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
clsbshow
else
yellow "Gitlab subscription links not configured"
fi
cd
}

clsbshow(){
green "Current Sing-box node updated and pushed"
green "Sing-box subscription links as follows:"
blue "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
green "Sing-box subscription links QR code as follows:"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "Current Clash-meta node config updated and pushed"
green "Clash-meta subscription links as follows:"
blue "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
green "Clash-meta subscription links QR code as follows:"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "Current aggregated subscription node config updated and pushed"
green "subscription links as follows:"
blue "$(cat /etc/s-box/jh_sub_gitlab.txt 2>/dev/null)"
echo
yellow "You can enter subscription links on webpage to view config content, if no content, please check Gitlab settings and reset"
echo
}

warpwg(){
warpcode(){
reg(){
keypair=$(openssl genpkey -algorithm X25519 | openssl pkey -text -noout)
private_key=$(echo "$keypair" | awk '/priv:/{flag=1; next} /pub:/{flag=0} flag' | tr -d '[:space:]' | xxd -r -p | base64)
public_key=$(echo "$keypair" | awk '/pub:/{flag=1} flag' | tr -d '[:space:]' | xxd -r -p | base64)
response=$(curl -sL --tlsv1.3 --connect-timeout 3 --max-time 5 \
-X POST 'https://api.cloudflareclient.com/v0a2158/reg' \
-H 'CF-Client-Version: a-7.21-0721' \
-H 'Content-Type: application/json' \
-d '{
"key": "'"$public_key"'",
"tos": "'"$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')"'"
}')
if [ -z "$response" ]; then
return 1
fi
echo "$response" | python3 -m json.tool 2>/dev/null | sed "/\"account_type\"/i\         \"private_key\": \"$private_key\","
}
reserved(){
reserved_str=$(echo "$warp_info" | grep 'client_id' | cut -d\" -f4)
reserved_hex=$(echo "$reserved_str" | base64 -d | xxd -p)
reserved_dec=$(echo "$reserved_hex" | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
echo -e "{\n    \"reserved_dec\": $reserved_dec,"
echo -e "    \"reserved_hex\": \"0x$reserved_hex\","
echo -e "    \"reserved_str\": \"$reserved_str\"\n}"
}
result() {
echo "$warp_reserved" | grep -P "reserved" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/:\[/: \[/g' | sed 's/\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/\1, \2, \3/' | sed 's/^"/    "/g' | sed 's/"$/",/g'
echo "$warp_info" | grep -P "(private_key|public_key|\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/    "/g'
echo "}"
}
warp_info=$(reg) 
warp_reserved=$(reserved) 
result
}
output=$(warpcode)
if ! echo "$output" 2>/dev/null | grep -w "private_key" > /dev/null; then
v6=2606:4700:110:860e:738f:b37:f15:d38d
pvk=g9I2sgUH6OCbIBTehkEfVEnuvInHYZvPOFhWchMLSc4=
res=[33,217,129]
else
pvk=$(echo "$output" | sed -n 4p | awk '{print $2}' | tr -d ' "' | sed 's/.$//')
v6=$(echo "$output" | sed -n 7p | awk '{print $2}' | tr -d ' "')
res=$(echo "$output" | sed -n 1p | awk -F":" '{print $NF}' | tr -d ' ' | sed 's/.$//')
fi
blue "Private_key: $pvk"
blue "IPV6 address: $v6"
blue "reserved value: $res"
}

changewg(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
if [[ "$sbnh" == "1.10" ]]; then
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .local_address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .private_key')
wgres=$(sed -n '165s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server_port')
else
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .private_key')
wgres=$(sed -n '125s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].address')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].port')
fi
echo
green "Current warp-wireguard changeable parameters:"
green "Private_key: $wgprkey"
green "IPV6 address: $wgipv6"
green "Reserved value: $wgres"
green "Peer IP: $wgip:$wgpo"
echo
yellow "1：Change warp-wireguard account"
yellow "0：Return to previous menu"
readp "Please select【0-1】：" menu
if [ "$menu" = "1" ]; then
green "Latest randomly generated regular warp-wireguard account as follows"
warpwg
echo
readp "Enter custom Private_key: " menu
sed -i "163s#$wgprkey#$menu#g" /etc/s-box/sb10.json
sed -i "115s#$wgprkey#$menu#g" /etc/s-box/sb11.json
readp "Enter custom IPV6 address: " menu
sed -i "161s/$wgipv6/$menu/g" /etc/s-box/sb10.json
sed -i "113s/$wgipv6/$menu/g" /etc/s-box/sb11.json
readp "Enter custom Reserved value (format: number,number,number), Enter to skip if none: " menu
if [ -z "$menu" ]; then
menu=0,0,0
fi
sed -i "165s/$wgres/$menu/g" /etc/s-box/sb10.json
sed -i "125s/$wgres/$menu/g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
green "Setup complete"
green "You can first use full domain routing in option 5-1 or 5-2: cloudflare.com"
green "Then use any node to open webpage https://cloudflare.com/cdn-cgi/trace, check current WARP account type"
elif  [ "$menu" = "2" ]; then
green "Please wait... updating..."
if [ -z $(curl -s4m5 icanhazip.com -k) ]; then
curl -sSL https://gitlab.com/rwkgyg/CFwarp/raw/main/point/endip.sh -o endip.sh && chmod +x endip.sh && (echo -e "1\n2\n") | bash endip.sh > /dev/null 2>&1
nwgip=$(awk -F, 'NR==2 {print $1}' /root/result.csv 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
nwgpo=$(awk -F, 'NR==2 {print $1}' /root/result.csv 2>/dev/null | awk -F "]" '{print $2}' | tr -d ':')
else
curl -sSL https://gitlab.com/rwkgyg/CFwarp/raw/main/point/endip.sh -o endip.sh && chmod +x endip.sh && (echo -e "1\n1\n") | bash endip.sh > /dev/null 2>&1
nwgip=$(awk -F, 'NR==2 {print $1}' /root/result.csv 2>/dev/null | awk -F: '{print $1}')
nwgpo=$(awk -F, 'NR==2 {print $1}' /root/result.csv 2>/dev/null | awk -F: '{print $2}')
fi
a=$(cat /root/result.csv 2>/dev/null | awk -F, '$3!="timeout ms" {print} ' | sed -n '2p' | awk -F ',' '{print $2}')
if [[ -z $a || $a = "100.00%" ]]; then
if [[ -z $(curl -s4m5 icanhazip.com -k) ]]; then
nwgip=2606:4700:d0::a29f:c001
nwgpo=2408
else
nwgip=162.159.192.1
nwgpo=2408
fi
fi
sed -i "157s#$wgip#$nwgip#g" /etc/s-box/sb10.json
sed -i "158s#$wgpo#$nwgpo#g" /etc/s-box/sb10.json
sed -i "118s#$wgip#$nwgip#g" /etc/s-box/sb11.json
sed -i "119s#$wgpo#$nwgpo#g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
rm -rf /root/result.csv /root/endip.sh 
echo
green "Optimization complete, current peer IP: $nwgip:$nwgpo"
else
changeserv
fi
}

sbymfl(){
sbport=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}' | awk -F":" '{print $NF}') 
sbport=${sbport:-'40000'}
resv1=$(curl -s --socks5 localhost:$sbport icanhazip.com)
resv2=$(curl -sx socks5h://localhost:$sbport icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
warp_s4_ip='Socks5-IPV4 not started, blacklist mode'
warp_s6_ip='Socks5-IPV6 not started, blacklist mode'
else
warp_s4_ip='Socks5-IPV4 available'
warp_s6_ip='Socks5-IPV6 self-test'
fi
v4v6
if [[ -z $v4 ]]; then
vps_ipv4='No local IPV4, blacklist mode'      
vps_ipv6="Current IP: $v6"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="Current IP: $v4"    
vps_ipv6="Current IP: $v6"
else
vps_ipv4="Current IP: $v4"    
vps_ipv6='No local IPV6, blacklist mode'
fi
unset swg4 swd4 swd6 swg6 ssd4 ssg4 ssd6 ssg6 sad4 sag4 sad6 sag6
wd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].domain_suffix | join(" ")')
wg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].geosite | join(" ")' 2>/dev/null)
if [[ "$wd4" == "yg_kkk" && ("$wg4" == "yg_kkk" || -z "$wg4") ]]; then
wfl4="${yellow}【warp outbound IPV4 available】No routing${plain}"
else
if [[ "$wd4" != "yg_kkk" ]]; then
swd4="$wd4 "
fi
if [[ "$wg4" != "yg_kkk" ]]; then
swg4=$wg4
fi
wfl4="${yellow}【warp outbound IPV4 available】Routed: $swd4$swg4${plain} "
fi

wd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].domain_suffix | join(" ")')
wg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].geosite | join(" ")' 2>/dev/null)
if [[ "$wd6" == "yg_kkk" && ("$wg6" == "yg_kkk"|| -z "$wg6") ]]; then
wfl6="${yellow}【warp outbound IPV6 self-test】No routing${plain}"
else
if [[ "$wd6" != "yg_kkk" ]]; then
swd6="$wd6 "
fi
if [[ "$wg6" != "yg_kkk" ]]; then
swg6=$wg6
fi
wfl6="${yellow}【warp outbound IPV6 self-test】Routed: $swd6$swg6${plain} "
fi

sd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].domain_suffix | join(" ")')
sg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].geosite | join(" ")' 2>/dev/null)
if [[ "$sd4" == "yg_kkk" && ("$sg4" == "yg_kkk" || -z "$sg4") ]]; then
sfl4="${yellow}【$warp_s4_ip】No routing${plain}"
else
if [[ "$sd4" != "yg_kkk" ]]; then
ssd4="$sd4 "
fi
if [[ "$sg4" != "yg_kkk" ]]; then
ssg4=$sg4
fi
sfl4="${yellow}【$warp_s4_ip】Routed: $ssd4$ssg4${plain} "
fi

sd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].domain_suffix | join(" ")')
sg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].geosite | join(" ")' 2>/dev/null)
if [[ "$sd6" == "yg_kkk" && ("$sg6" == "yg_kkk" || -z "$sg6") ]]; then
sfl6="${yellow}【$warp_s6_ip】No routing${plain}"
else
if [[ "$sd6" != "yg_kkk" ]]; then
ssd6="$sd6 "
fi
if [[ "$sg6" != "yg_kkk" ]]; then
ssg6=$sg6
fi
sfl6="${yellow}【$warp_s6_ip】Routed: $ssd6$ssg6${plain} "
fi

ad4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].domain_suffix | join(" ")')
ag4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].geosite | join(" ")' 2>/dev/null)
if [[ "$ad4" == "yg_kkk" && ("$ag4" == "yg_kkk" || -z "$ag4") ]]; then
adfl4="${yellow}【$vps_ipv4】No routing${plain}" 
else
if [[ "$ad4" != "yg_kkk" ]]; then
sad4="$ad4 "
fi
if [[ "$ag4" != "yg_kkk" ]]; then
sag4=$ag4
fi
adfl4="${yellow}【$vps_ipv4】Routed: $sad4$sag4${plain} "
fi

ad6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].domain_suffix | join(" ")')
ag6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].geosite | join(" ")' 2>/dev/null)
if [[ "$ad6" == "yg_kkk" && ("$ag6" == "yg_kkk" || -z "$ag6") ]]; then
adfl6="${yellow}【$vps_ipv6】No routing${plain}" 
else
if [[ "$ad6" != "yg_kkk" ]]; then
sad6="$ad6 "
fi
if [[ "$ag6" != "yg_kkk" ]]; then
sag6=$ag6
fi
adfl6="${yellow}【$vps_ipv6】Routed: $sad6$sag6${plain} "
fi
}

changefl(){
sbactive
blue "Unified domain routing for all protocols"
blue "To ensure routing availability, dual-stack IP (IPV4/IPV6) routing mode is the preferred mode"
blue "warp-wireguard enabled by default (options 1 and 2)"
blue "socks5 requires installing warp official client or WARP-plus-Socks5-Psiphon VPN on VPS (options 3 and 4)"
blue "VPS local outbound routing (options 5 and 6)"
echo
[[ "$sbnh" == "1.10" ]] && blue "Current Sing-box kernel supports geosite routing mode" || blue "Current Sing-box kernel does not support geosite routing mode, only supports routing options 2, 3, 5, 6"
echo
yellow "Note:"
yellow "1. Full domain mode only accepts full domain (e.g., for Google website: www.google.com)"
yellow "2. Geosite mode requires geosite rule name (e.g., Netflix: netflix; Disney: disney; ChatGPT: openai; Global bypass China: geolocation-!cn)"
yellow "3. Do not route the same full domain or geosite repeatedly"
yellow "4. If any routing channel has no network, the routing is blacklist mode, i.e., blocking access to that website"
changef
}

changef(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sbymfl
echo
if [[ "$sbnh" != "1.10" ]]; then
wfl4='Not supported'
sfl6='Not supported'
fi
green "1：Reset warp-wireguard-ipv4 priority routing domain $wfl4"
green "2：Reset warp-wireguard-ipv6 priority routing domain $wfl6"
green "3：Reset warp-socks5-ipv4 priority routing domain $sfl4"
green "4：Reset warp-socks5-ipv6 priority routing domain $sfl6"
green "5：Reset VPS local ipv4 priority routing domain $adfl4"
green "6：Reset VPS local ipv6 priority routing domain $adfl6"
green "0：Return to previous menu"
echo
readp "Please select【0-6】：" menu

if [ "$menu" = "1" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：Use full domain mode\n2：Use geosite mode\n3：Return to previous menu\nPlease select: " menu
if [ "$menu" = "1" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-wireguard-ipv4 full domain routing channel): " w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "184s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-wireguard-ipv4 geosite routing channel): " w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "187s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "Unfortunately! Currently only warp-wireguard-ipv6 is supported. If you need warp-wireguard-ipv4, please switch to 1.10 series kernel" && sleep 2 && sb
fi

elif [ "$menu" = "2" ]; then
readp "1：Use full domain mode\n2：Use geosite mode\n3：Return to previous menu\nPlease select: " menu
if [ "$menu" = "1" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-wireguard-ipv6 full domain routing channel: " w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "193s/.*/$w6flym/" /etc/s-box/sb10.json
sed -i "169s/.*/$w6flym/" /etc/s-box/sb11.json
sed -i "181s/.*/$w6flym/" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-wireguard-ipv6 geosite routing channel: " w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "196s/.*/$w6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "Unfortunately! Current Sing-box kernel does not support geosite routing mode. To support, please switch to 1.10 series kernel" && sleep 2 && sb
fi
else
changef
fi

elif [ "$menu" = "3" ]; then
readp "1：Use full domain mode\n2：Use geosite mode\n3：Return to previous menu\nPlease select: " menu
if [ "$menu" = "1" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-socks5-ipv4 full domain routing channel: " s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "202s/.*/$s4flym/" /etc/s-box/sb10.json
sed -i "162s/.*/$s4flym/" /etc/s-box/sb11.json
sed -i "175s/.*/$s4flym/" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-socks5-ipv4 geosite routing channel: " s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "205s/.*/$s4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "Unfortunately! Current Sing-box kernel does not support geosite routing mode. To support, please switch to 1.10 series kernel" && sleep 2 && sb
fi
else
changef
fi

elif [ "$menu" = "4" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：Use full domain mode\n2：Use geosite mode\n3：Return to previous menu\nPlease select: " menu
if [ "$menu" = "1" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-socks5-ipv6 full domain routing channel: " s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "211s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear warp-socks5-ipv6 geosite routing channel: " s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "214s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "Unfortunately! Currently only warp-socks5-ipv4 is supported. If you need warp-socks5-ipv6, please switch to 1.10 series kernel" && sleep 2 && sb
fi

elif [ "$menu" = "5" ]; then
readp "1：Use full domain mode\n2：Use geosite mode\n3：Return to previous menu\nPlease select: " menu
if [ "$menu" = "1" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear VPS local ipv4 full domain routing channel: " ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "220s/.*/$ad4flym/" /etc/s-box/sb10.json
sed -i "188s/.*/$ad4flym/" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Separate domains with spaces, Enter to skip means reset and clear VPS local ipv4 geosite routing channel: " ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "223s/.*/$ad4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "Unfortunately! Current Sing-box kernel does not support geosite routing mode. To support, please switch to 1.10 series kernel" && sleep 2 && sb
fi
else
changef
fi

elif [ "$menu" = "6" ]; then
readp "1：Use full domain mode\n2：Use geosite mode\n3：Return to previous menu\nPlease select: " menu
if [ "$menu" = "1" ]; then
readp "Separate domains with spaces, Enter to skip means reset and clear VPS local ipv6 full domain routing channel: " ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "229s/.*/$ad6flym/" /etc/s-box/sb10.json
sed -i "194s/.*/$ad6flym/" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Separate domains with spaces, Enter to skip means reset and clear VPS local ipv6 geosite routing channel: " ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "232s/.*/$ad6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "Unfortunately! Current Sing-box kernel does not support geosite routing mode. To support, please switch to 1.10 series kernel" && sleep 2 && sb
fi
else
changef
fi
else
sb
fi
}

restartsb(){
if [[ x"${release}" == x"alpine" ]]; then
rc-service sing-box restart
else
systemctl enable sing-box
systemctl start sing-box
systemctl restart sing-box
fi
}

stclre(){
if [[ ! -f '/etc/s-box/sb.json' ]]; then
red "Sing-box not properly installed" && sleep 2 && sb
fi
readp "1：Restart\n2：Stop\nPlease select: " menu
if [ "$menu" = "1" ]; then
restartsb
sbactive
green "Sing-box service restarted\n" && sleep 3 && sb
elif [ "$menu" = "2" ]; then
if [[ x"${release}" == x"alpine" ]]; then
rc-service sing-box stop
else
systemctl stop sing-box
systemctl disable sing-box
fi
green "Sing-box service stopped\n" && sleep 3 && sb
else
stclre
fi
}

cronsb(){
uncronsb
crontab -l > /tmp/crontab.tmp
echo "0 1 * * * systemctl restart sing-box;rc-service sing-box restart" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}
uncronsb(){
crontab -l > /tmp/crontab.tmp
sed -i '/sing-box/d' /tmp/crontab.tmp
sed -i '/sbargopid/d' /tmp/crontab.tmp
sed -i '/sbargoympid/d' /tmp/crontab.tmp
sed -i '/sbwpphid.log/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

lnsb(){
rm -rf /usr/bin/sb
curl -L -o /usr/bin/sb -# --retry 2 --insecure https://raw.githubusercontent.com/anyagixx/proxme3/main/sb.sh
chmod +x /usr/bin/sb
}

upsbyg(){
if [[ ! -f '/usr/bin/sb' ]]; then
red "Sing-box-yg not properly installed" && sleep 2 && sb
fi
lnsb
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/version | awk -F "Update content" '{print $1}' | head -n 1 > /etc/s-box/v
green "Sing-box-yg installation script upgraded successfully" && sleep 5 && sb
}

lapre(){
latcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"[0-9.]+",' | sed -n 1p | tr -d '",')
precore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"[0-9.]*-[^"]*"' | sed -n 1p | tr -d '",')
inscore=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}')
}

upsbcroe(){
sbactive
lapre
[[ $inscore =~ ^[0-9.]+$ ]] && lat="【Already installed v$inscore】" || pre="【Already installed v$inscore】"
green "1：Upgrade/switch Sing-box latest stable version v$latcore  ${bblue}${lat}${plain}"
green "2：Upgrade/switch Sing-box latest beta version v$precore  ${bblue}${pre}${plain}"
green "3：Switch Sing-box specific stable or beta version, need to specify Version (recommended 1.10.0 or above)"
green "0：Return to previous menu"
readp "Please select【0-3】：" menu
if [ "$menu" = "1" ]; then
upcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"[0-9.]+",' | sed -n 1p | tr -d '",')
elif [ "$menu" = "2" ]; then
upcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"[0-9.]*-[^"]*"' | sed -n 1p | tr -d '",')
elif [ "$menu" = "3" ]; then
echo
red "Note: Version can be checked at https://github.com/SagerNet/sing-box/tags, must have Downloads (must be 1.10.0 or above)"
green "Stable version format: number.number.number (e.g., 1.10.7. Note: 1.10 series kernel supports geosite routing, above 1.10 kernel does not support geosite routing)"
green "Beta version format: number.number.number-alpha or rc or beta.number (e.g., 1.10.0-alpha or rc or beta.1)"
readp "Please enter Sing-box Version: " upcore
else
sb
fi
if [[ -n $upcore ]]; then
green "Starting Sing-box kernel download and update... please wait"
sbname="sing-box-$upcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$upcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
blue "Successfully upgraded/switched Sing-box kernel version: $(/etc/s-box/sing-box version | awk '/version/{print $NF}')" && sleep 3 && sb
else
red "Download.*incomplete, installation failed, please retry" && upsbcroe
fi
else
red "Download.*failed or does not exist, please retry" && upsbcroe
fi
else
red "Version detection error, please retry" && upsbcroe
fi
}

unins(){
if [[ x"${release}" == x"alpine" ]]; then
rc-service sing-box stop
rc-update del sing-box default
rm /etc/init.d/sing-box -f
else
systemctl stop sing-box >/dev/null 2>&1
systemctl disable sing-box >/dev/null 2>&1
rm -f /etc/systemd/system/sing-box.service
fi
kill -15 $(cat /etc/s-box/sbargopid.log 2>/dev/null) >/dev/null 2>&1
kill -15 $(cat /etc/s-box/sbargoympid.log 2>/dev/null) >/dev/null 2>&1
kill -15 $(cat /etc/s-box/sbwpphid.log 2>/dev/null) >/dev/null 2>&1
rm -rf /etc/s-box sbyg_update /usr/bin/sb /root/geoip.db /root/geosite.db /root/warpapi /root/warpip
uncronsb
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
green "Sing-box uninstallation complete!"
blue "Welcome to continue using Sing-box-yg script: bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/sb.sh)"
echo
}

sblog(){
red "Exit log Ctrl+c"
if [[ x"${release}" == x"alpine" ]]; then
yellow "Viewing logs not supported on alpine"
else
#systemctl status sing-box
journalctl -u sing-box.service -o cat -f
fi
}

sbactive(){
if [[ ! -f /etc/s-box/sb.json ]]; then
red "Sing-box not properly started, please uninstall and reinstall or select 10 to view running log for feedback" && sleep 2 && sb
fi
}

sbshare(){
rm -rf /etc/s-box/jhdy.txt /etc/s-box/vl_reality.txt /etc/s-box/vm_ws_argols.txt /etc/s-box/vm_ws_argogd.txt /etc/s-box/vm_ws.txt /etc/s-box/vm_ws_tls.txt /etc/s-box/hy2.txt /etc/s-box/tuic5.txt
result_vl_vm_hy_tu && resvless && resvmess && reshy2 && restu5
cat /etc/s-box/vl_reality.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argols.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_tls.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/hy2.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/tuic5.txt 2>/dev/null >> /etc/s-box/jhdy.txt
baseurl=$(base64 -w 0 < /etc/s-box/jhdy.txt 2>/dev/null)
v2sub=$(cat /etc/s-box/jhdy.txt 2>/dev/null)
echo "$v2sub" > /etc/s-box/jh_sub.txt
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 Four-in-one aggregated subscription 】Node info as follows: " && sleep 2
echo
echo "Share link"
echo -e "${yellow}$baseurl${plain}"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
sb_client
}

clash_sb_share(){
sbactive
echo
yellow "1：Refresh and view each protocol Share link, QR code, four-in-one aggregated subscription"
yellow "2：Refresh and view Clash-Meta, Sing-box client SFA/SFI/SFW three-in-one config, Gitlab private subscription links"
yellow "3：Refresh and view Hysteria2, Tuic5 V2rayN client custom config"
yellow "4：Push latest node config info (option 1 + option 2) to Telegram notification"
yellow "0：Return to previous menu"
readp "Please select【0-4】：" menu
if [ "$menu" = "1" ]; then
sbshare
elif  [ "$menu" = "2" ]; then
green "Please wait..."
sbshare > /dev/null 2>&1
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "Gitlab subscription links as follows:"
gitlabsubgo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vless-reality、vmess-ws、Hysteria2、Tuic5 】Clash-Meta config files displayed below:"
red "File directory /etc/s-box/clash_meta_client.yaml, copy and build using yaml file format" && sleep 2
echo
cat /etc/s-box/clash_meta_client.yaml
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vless-reality、vmess-ws、Hysteria2、Tuic5 】SFA/SFI/SFW config files displayed below:"
red "Android SFA, iOS SFI, Windows official SFW package please download from anyagixx GitHub Project,"
red "File directory /etc/s-box/sing_box_client.json, copy and build using json file format" && sleep 2
echo
cat /etc/s-box/sing_box_client.json
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
elif  [ "$menu" = "3" ]; then
green "Please wait..."
sbshare > /dev/null 2>&1
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 Hysteria-2 】custom V2rayN config files displayed below:"
red "File directory /etc/s-box/v2rayn_hy2.yaml, copy and build using yaml file format" && sleep 2
echo
cat /etc/s-box/v2rayn_hy2.yaml
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [[ "$tu5_sniname" = '/etc/s-box/private.key' ]]; then
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
red "Note: V2rayN client using custom Tuic5 official client core does not support Tuic5 self-signed certificate, only supports domain certificate" && sleep 2
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
else
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 Tuic-v5 】custom V2rayN config files displayed below:"
red "File directory /etc/s-box/v2rayn_tu5.json, copy and build using json file format" && sleep 2
echo
cat /etc/s-box/v2rayn_tu5.json
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
fi
elif [ "$menu" = "4" ]; then
tgnotice
else
sb
fi
}

acme(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/acme.sh)
}
cfwarp(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh)
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/CFwarp.sh)
}
bbr(){
if [[ $vi =~ lxc|openvz ]]; then
yellow "Current VPS architecture is $vi, does not support enabling original BBR acceleration" && sleep 2 && sb 
else
green "Press any key to enable BBR acceleration, ctrl+c to exit"
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
fi
}

showprotocol(){
allports
sbymfl
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
argopid
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) || -n $(ps -e | grep -w $ls 2>/dev/null) ]]; then
vm_zs="TLS disabled"
argoym="Enabled"
else
vm_zs="TLS disabled"
argoym="Not enabled"
fi
else
vm_zs="TLS enabled"
argoym="Not supported"
fi
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_zs="self-signed certificate" || hy2_zs="domain certificate"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_zs="self-signed certificate" || tu5_zs="domain certificate"
echo -e "Sing-box node key info, domain routing status as follows:"
echo -e "🚀【 Vless-reality 】${yellow}port: $vl_port  Reality domain certificate disguise address: $(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')${plain}"
if [[ "$tls" = "false" ]]; then
echo -e "🚀【   Vmess-ws    】${yellow}port: $vm_port   Certificate type: $vm_zs   Argo status: $argoym${plain}"
else
echo -e "🚀【 Vmess-ws-tls  】${yellow}port: $vm_port   Certificate type: $vm_zs   Argo status: $argoym${plain}"
fi
echo -e "🚀【  Hysteria-2   】${yellow}port: $hy2_port  Certificate type: $hy2_zs  Forwarded multi-port: $hy2zfport${plain}"
echo -e "🚀【    Tuic-v5    】${yellow}port: $tu5_port  Certificate type: $tu5_zs  Forwarded multi-port: $tu5zfport${plain}"
if [ "$argoym" = "Enabled" ]; then
echo -e "Vmess-UUID：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')${plain}"
echo -e "Vmess-Path：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')${plain}"
if [[ -n $(ps -e | grep -w $ls 2>/dev/null) ]]; then
echo -e "Argotemporarydomain：${yellow}$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')${plain}"
fi
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) ]]; then
echo -e "Argofixeddomain：${yellow}$(cat /etc/s-box/sbargoym.log 2>/dev/null)${plain}"
fi
fi
echo "------------------------------------------------------------------------------------"
if [[ -n $(ps -e | grep sbwpph) ]]; then
s5port=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}'| awk -F":" '{print $NF}')
s5gj=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $6}')
case "$s5gj" in
AT) showgj="Austria" ;;
AU) showgj="Australia" ;;
BE) showgj="Belgium" ;;
BG) showgj="Bulgaria" ;;
CA) showgj="Canada" ;;
CH) showgj="Switzerland" ;;
CZ) showgj="Czech Republic" ;;
DE) showgj="Germany" ;;
DK) showgj="Denmark" ;;
EE) showgj="Estonia" ;;
ES) showgj="Spain" ;;
FI) showgj="Finland" ;;
FR) showgj="France" ;;
GB) showgj="United Kingdom" ;;
HR) showgj="Croatia" ;;
HU) showgj="Hungary" ;;
IE) showgj="Ireland" ;;
IN) showgj="India" ;;
IT) showgj="Italy" ;;
JP) showgj="Japan" ;;
LT) showgj="Lithuania" ;;
LV) showgj="Latvia" ;;
NL) showgj="Netherlands" ;;
NO) showgj="Norway" ;;
PL) showgj="Poland" ;;
PT) showgj="Portugal" ;;
RO) showgj="Romania" ;;
RS) showgj="Serbia" ;;
SE) showgj="Sweden" ;;
SG) showgj="Singapore" ;;
SK) showgj="Slovakia" ;;
US) showgj="United States" ;;
esac
grep -q "country" /etc/s-box/sbwpph.log 2>/dev/null && s5ms="Multi-region Psiphon proxy mode (port: $s5port  country: $showgj)" || s5ms="Local Warp proxy mode (port: $s5port)"
echo -e "WARP-plus-Socks5 status: $yellow Started $s5ms$plain"
else
echo -e "WARP-plus-Socks5 status: $yellow Not started$plain"
fi
echo "------------------------------------------------------------------------------------"
ww4="warp-wireguard-ipv4 priority routing domain: $wfl4"
ww6="warp-wireguard-ipv6 priority routing domain: $wfl6"
ws4="warp-socks5-ipv4 priority routing domain: $sfl4"
ws6="warp-socks5-ipv6 priority routing domain: $sfl6"
l4="VPS local ipv4 priority routing domain: $adfl4"
l6="VPS local ipv6 priority routing domain: $adfl6"
[[ "$sbnh" == "1.10" ]] && ymflzu=("ww4" "ww6" "ws4" "ws6" "l4" "l6") || ymflzu=("ww6" "ws4" "l4" "l6")
for ymfl in "${ymflzu[@]}"; do
if [[ ${!ymfl} != *"No"* ]]; then
echo -e "${!ymfl}"
fi
done
if [[ $ww4 = *"No"* && $ww6 = *"No"* && $ws4 = *"No"* && $ws6 = *"No"* && $l4 = *"No"* && $l6 = *"No"* ]] ; then
echo -e "No domain routing configured"
fi
}

inssbwpph(){
sbactive
ins(){
if [ ! -e /etc/s-box/sbwpph ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/sbwpph -# --retry 2 --insecure https://raw.githubusercontent.com/anyagixx/proxme3/main/sbwpph_$cpu
chmod +x /etc/s-box/sbwpph
fi
if [[ -n $(ps -e | grep sbwpph) ]]; then
kill -15 $(cat /etc/s-box/sbwpphid.log 2>/dev/null) >/dev/null 2>&1
fi
v4v6
if [[ -n $v4 ]]; then
sw46=4
else
red "IPV4 does not exist, ensure WARP-IPV4 mode is installed"
sw46=6
fi
echo
readp "Set WARP-plus-Socks5 port (Enter to skip, default port 40000): " port
if [[ -z $port ]]; then
port=40000
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nPort is in use，Please re-enter port" && readp "Custom port:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nPort is in use，Please re-enter port" && readp "Custom port:" port
done
fi
s5port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "socks") | .server_port')
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sed -i "127s/$s5port/$port/g" /etc/s-box/sb10.json
sed -i "150s/$s5port/$port/g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
}
unins(){
kill -15 $(cat /etc/s-box/sbwpphid.log 2>/dev/null) >/dev/null 2>&1
rm -rf /etc/s-box/sbwpph.log /etc/s-box/sbwpphid.log
crontab -l > /tmp/crontab.tmp
sed -i '/sbwpphid.log/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}
echo
yellow "1：Reset/enable WARP-plus-Socks5 local Warp proxy mode"
yellow "2：Reset/enable WARP-plus-Socks5 multi-region Psiphon proxy mode"
yellow "3：Stop WARP-plus-Socks5 proxy mode"
yellow "0：Return to previous menu"
readp "Please select【0-3】：" menu
if [ "$menu" = "1" ]; then
ins
nohup setsid /etc/s-box/sbwpph -b 127.0.0.1:$port --gool -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 & echo "$!" > /etc/s-box/sbwpphid.log
green "Requesting IP... please wait..." && sleep 20
resv1=$(curl -s --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sx socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5 IP acquisition failed" && unins && sleep 2 && sb
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --gool -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
crontab -l > /tmp/crontab.tmp
sed -i '/sbwpphid.log/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid $(cat /etc/s-box/sbwpph.log 2>/dev/null) & pid=\$! && echo \$pid > /etc/s-box/sbwpphid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
green "WARP-plus-Socks5 IP acquired successfully, can perform Socks5 proxy routing"
fi
elif [ "$menu" = "2" ]; then
ins
echo '
Austria (AT)
Australia (AU)
Belgium (BE)
Bulgaria (BG)
Canada (CA)
Switzerland (CH)
Czech Republic (CZ)
Germany (DE)
Denmark (DK)
Estonia (EE)
Spain (ES)
Finland (FI)
France (FR)
United Kingdom (GB)
Croatia (HR)
Hungary (HU)
Ireland (IE)
India (IN)
Italy (IT)
Japan (JP)
Lithuania (LT)
Latvia (LV)
Netherlands (NL)
Norway (NO)
Poland (PL)
Portugal (PT)
Romania (RO)
Serbia (RS)
Sweden (SE)
Singapore (SG)
Slovakia (SK)
United States (US)
'
readp "Select country region (enter last two uppercase letters, e.g., for United States, enter US): " guojia
nohup setsid /etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 & echo "$!" > /etc/s-box/sbwpphid.log
green "Requesting IP... please wait..." && sleep 20
resv1=$(curl -s --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sx socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5 IP acquisition failed, try a different country region" && unins && sleep 2 && sb
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
crontab -l > /tmp/crontab.tmp
sed -i '/sbwpphid.log/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid $(cat /etc/s-box/sbwpph.log 2>/dev/null) & pid=\$! && echo \$pid > /etc/s-box/sbwpphid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
green "WARP-plus-Socks5 IP acquired successfully, can perform Socks5 proxy routing"
fi
elif [ "$menu" = "3" ]; then
unins && green "WARP-plus-Socks5 proxy function stopped"
else
sb
fi
}

sbsm(){
echo
green "GitHub Project: https://github.com/anyagixx/proxme3 for latest proxy protocols and bypass updates"
echo
blue "sing-box-yg script video tutorial: https://www.youtube.com/playlist?list=PLMgly2AulGG_Affv6skQXWnVqw7XWiPwJ"
echo
blue "sing-box-yg script blog description: http://ygkkk.blogspot.com/2023/10/sing-box-yg.html"
echo
blue "This fork project: https://github.com/anyagixx/proxme3"
echo
blue "Project: https://github.com/anyagixx/proxme3"
echo
blue "Recommended new product: ArgoSB one-click non-interactive compact script"
blue "Supports: AnyTLS, Any-reality, Vless-xhttp-reality, Vless-reality-vision, Shadowsocks-2022, Hysteria2, Tuic, Vmess-ws, Argo temporary/fixed tunnel"
blue "ArgoSB project address: https://github.com/anyagixx/proxme3"
echo
}

clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "GitHub Project  ：github.com/anyagixx/proxme3"
white "Original Author Blog ：ygkkk.blogspot.com"
white "Original Author YouTube ：www.youtube.com/@ygkkk"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Vless-reality-vision, Vmess-ws(tls)+Argo, Hysteria-2, Tuic-v5 four-protocol coexistence script"
white "Script shortcut: sb"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. One-click install Sing-box" 
green " 2. Uninstall Sing-box"
white "----------------------------------------------------------------------------------"
green " 3. Change config 【Dual certificate TLS/UUID path/Argo/IP priority/TG notification/Warp/Subscription/CDN optimization】" 
green " 4. Change main port/add multi-port hopping multiplexing" 
green " 5. Three-channel domain routing"
green " 6. Stop/Restart Sing-box"   
green " 7. Update Sing-box-yg script"
green " 8. Update/switch/specify Sing-box kernel version"
white "----------------------------------------------------------------------------------"
green " 9. Refresh and view nodes 【Clash-Meta/SFA+SFI+SFW three-in-one config/subscription links/push TG notification】"
green "10. View Sing-box running log"
green "11. One-click original BBR+FQ acceleration"
green "12. Manage Acme domain certificate application"
green "13. Manage Warp and view Netflix/ChatGPT unlock status"
green "14. Add WARP-plus-Socks5 proxy mode 【Local Warp/Multi-region Psiphon-VPN】"
green "15. Refresh local IP, switch IPV4/IPV6 config output"
green "16. Sing-box-yg script user manual"
green "17. User management (add/delete users)"
green "18. Dumbproxy HTTPS proxy (simple proxy with auto SSL)"
green "19. SOCKS5 proxy for Telegram (via Sing-box)"
green "20. MTProto proxy for Telegram (via Docker)"
white "----------------------------------------------------------------------------------"
green " 0. Exit script"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
insV=$(cat /etc/s-box/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/version | awk -F "Update content" '{print $1}' | head -n 1)
if [ -f /etc/s-box/v ]; then
if [ "$insV" = "$latestV" ]; then
echo -e "Current Sing-box-yg script Latest version: ${bblue}${insV}${plain} (Already installed)"
else
echo -e "Current Sing-box-yg script Version: ${bblue}${insV}${plain}"
echo -e "Detected latest Sing-box-yg script Version: ${yellow}${latestV}${plain} (can select 7 to update)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/version)${plain}"
fi
else
echo -e "Current Sing-box-yg script Version: ${bblue}${latestV}${plain}"
yellow "Not installed Sing-box-yg script! Please select 1 to install first"
fi

lapre
if [ -f '/etc/s-box/sb.json' ]; then
if [[ $inscore =~ ^[0-9.]+$ ]]; then
if [ "${inscore}" = "${latcore}" ]; then
echo
echo -e "Current Sing-box latest stable kernel: ${bblue}${inscore}${plain} (Already installed)"
echo
echo -e "Current Sing-box latest beta kernel: ${bblue}${precore}${plain} (can switch)"
else
echo
echo -e "Current Sing-box Already installed stable kernel: ${bblue}${inscore}${plain}"
echo -e "Detected latest Sing-box stable kernel: ${yellow}${latcore}${plain} (can select 8 to update)"
echo
echo -e "Current Sing-box latest beta kernel: ${bblue}${precore}${plain} (can switch)"
fi
else
if [ "${inscore}" = "${precore}" ]; then
echo
echo -e "Current Sing-box latest beta kernel: ${bblue}${inscore}${plain} (Already installed)"
echo
echo -e "Current Sing-box latest stable kernel: ${bblue}${latcore}${plain} (can switch)"
else
echo
echo -e "Current Sing-box Already installed beta kernel: ${bblue}${inscore}${plain}"
echo -e "Detected latest Sing-box beta kernel: ${yellow}${precore}${plain} (can select 8 to update)"
echo
echo -e "Current Sing-box latest stable kernel: ${bblue}${latcore}${plain} (can switch)"
fi
fi
else
echo
echo -e "Current Sing-box latest stable kernel: ${bblue}${latcore}${plain}"
echo -e "Current Sing-box latest beta kernel: ${bblue}${precore}${plain}"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "VPS status as follows:"
echo -e "system:$blue$op$plain  \c";echo -e "kernel:$blue$version$plain  \c";echo -e "processor:$blue$cpu$plain  \c";echo -e "virtualization:$blue$vi$plain  \c";echo -e "BBR algorithm:$blue$bbr$plain"
v4v6
if [[ "$v6" == "2a09"* ]]; then
w6="【WARP】"
fi
if [[ "$v4" == "104.28"* ]]; then
w4="【WARP】"
fi
rpip=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.outbounds[0].domain_strategy')
[[ -z $v4 ]] && showv4='IPV4 address lost, please switch to IPV6 or reinstall Sing-box' || showv4=$v4$w4
[[ -z $v6 ]] && showv6='IPV6 address lost, please switch to IPV4 or reinstall Sing-box' || showv6=$v6$w6
if [[ $rpip = 'prefer_ipv6' ]]; then
v4_6="IPV6 preferred outbound ($showv6)"
elif [[ $rpip = 'prefer_ipv4' ]]; then
v4_6="IPV4 preferred outbound ($showv4)"
elif [[ $rpip = 'ipv4_only' ]]; then
v4_6="IPV4 only outbound ($showv4)"
elif [[ $rpip = 'ipv6_only' ]]; then
v4_6="IPV6 only outbound ($showv6)"
fi
if [[ -z $v4 ]]; then
vps_ipv4='No IPV4'      
vps_ipv6="$v6"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="$v4"    
vps_ipv6="$v6"
else
vps_ipv4="$v4"    
vps_ipv6='No IPV6'
fi
echo -e "Local IPV4 address: $blue$vps_ipv4$w4$plain   Local IPV6 address: $blue$vps_ipv6$w6$plain"
if [[ -n $rpip ]]; then
echo -e "Proxy IP priority: $blue$v4_6$plain"
fi
if [[ x"${release}" == x"alpine" ]]; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl status sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box status: $blue Running$plain"
elif [[ -z $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box status: $yellow Not started, select 10 to view log and feedback, recommend switching to stable kernel or uninstall and reinstall script$plain"
else
echo -e "Sing-box status: $red Not installed$plain"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [ -f '/etc/s-box/sb.json' ]; then
showprotocol
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp "Please enter number [0-20]: " Input
case "$Input" in  
 1 ) instsllsingbox;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) changeport;;
 5 ) changefl;;
 6 ) stclre;;
 7 ) upsbyg;; 
 8 ) upsbcroe;;
 9 ) clash_sb_share;;
10 ) sblog;;
11 ) bbr;;
12 ) acme;;
13 ) cfwarp;;
14 ) inssbwpph;;
15 ) wgcfgo && sbshare;;
16 ) sbsm;;
17 ) manageusers;;
18 ) manage_dumbproxy;;
19 ) manage_socks5;;
20 ) manage_mtproto;;
* ) exit
esac
