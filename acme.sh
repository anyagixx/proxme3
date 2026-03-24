#!/bin/bash 
export LANG=en_US.UTF-8
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "Please run script as root" && exit

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
red "Script does not support current system, please use Ubuntu, Debian, or Centos system" && exit 
fi
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "Script does not support current $op system, please use Ubuntu, Debian, or Centos system." && exit
fi

v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
}

if [ ! -f acyg_update ]; then
green "First-time installing Acme script required dependencies..."
if [[ x"${release}" == x"alpine" ]]; then
apk add wget curl tar jq tzdata openssl expect git socat iproute2 virt-what
else
if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install socat -y
apt install cron -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install socat -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install socat -y
fi
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if ! command -v "cronie" &> /dev/null; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie
fi
fi
if ! command -v "dig" &> /dev/null; then
if [ -x "$(command -v yum)" ]; then
yum install -y bind-utils
elif [ -x "$(command -v dnf)" ]; then
dnf install -y bind-utils
fi
fi
fi

packages=("curl" "openssl" "lsof" "socat" "dig" "tar" "wget")
inspackages=("curl" "openssl" "lsof" "socat" "dnsutils" "tar" "wget")
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
touch acyg_update
fi

if [[ -z $(curl -s4m5 icanhazip.com -k) ]]; then
yellow "Detected pure IPv6 VPS, adding NAT64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
sleep 2
fi

acme2(){
if [[ -n $(lsof -i :80|grep -v "PID") ]]; then
yellow "Detected port 80 is in use, now releasing port 80"
sleep 2
lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh >/dev/null 2>&1
green "Port 80 release complete!"
sleep 2
fi
}
acme3(){
readp "Enter email for registration (press Enter to auto-generate virtual gmail):" Aemail
if [ -z $Aemail ]; then
auto=`date +%s%N |md5sum | cut -c 1-6`
Aemail=$auto@gmail.com
fi
yellow "Current registered email: $Aemail"
green "Starting acme.sh certificate script installation"
bash ~/.acme.sh/acme.sh --uninstall >/dev/null 2>&1
rm -rf ~/.acme.sh acme.sh
uncronac
wget -N https://github.com/Neilpang/acme.sh/archive/master.tar.gz >/dev/null 2>&1
tar -zxvf master.tar.gz >/dev/null 2>&1
cd acme.sh-master >/dev/null 2>&1
./acme.sh --install >/dev/null 2>&1
cd
curl https://get.acme.sh | sh -s email=$Aemail
if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
green "acme.sh certificate program installed successfully"
bash ~/.acme.sh/acme.sh --upgrade --use-wget --auto-upgrade
else
red "acme.sh certificate program installation failed" && exit
fi
}

checktls(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]] && [[ -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
cronac
green "Domain certificate applied successfully or already exists! Domain certificate (cert.crt) and key (private.key) saved to /root/ygkkkca folder" 
yellow "Public key crt path as follows, can be directly copied"
green "/root/ygkkkca/cert.crt"
yellow "Private key key path as follows, can be directly copied"
green "/root/ygkkkca/private.key"
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
if [[ -f '/etc/hysteria/config.json' ]]; then
blue "Detected Hysteria-1 proxy protocol, if you installed the Hysteria script, please apply/change certificate in Hysteria script, this certificate will be automatically applied"
fi
if [[ -f '/etc/caddy/Caddyfile' ]]; then
blue "Detected Naiveproxy proxy protocol, if you installed the Naiveproxy script, please apply/change certificate in Naiveproxy script, this certificate will be automatically applied"
fi
if [[ -f '/etc/tuic/tuic.json' ]]; then
blue "Detected Tuic proxy protocol, if you installed the Tuic script, please apply/change certificate in Tuic script, this certificate will be automatically applied"
fi
if [[ -f '/usr/bin/x-ui' ]]; then
blue "Detected x-ui (xray proxy protocol), if you installed the x-ui script, enable tls option, this certificate will be automatically applied"
fi
if [[ -f '/etc/s-box/sb.json' ]]; then
blue "Detected Sing-box kernel proxy, if you installed the Sing-box script, please apply/change certificate in Sing-box script, this certificate will be automatically applied"
fi
else
bash ~/.acme.sh/acme.sh --uninstall >/dev/null 2>&1
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
uncronac
red "Unfortunately, domain certificate application failed, suggestions:"
yellow "1. If the resolved IP starts with 104.2 or 172, please ensure CDN orange cloud is disabled in CF, the resolved IP must be the VPS local IP"
echo
yellow "2. Change the subdomain custom name and try running the reinstall script again (important)"
green "Example: Original subdomain x.ygkkk.eu.org or x.ygkkk.cf, rename x in Cloudflare"
echo
yellow "3. Due to rate limiting for certificate applications from the same IP, wait some time before reinstalling the script" && exit
fi
}

installCA(){
bash ~/.acme.sh/acme.sh --install-cert -d ${ym} --key-file /root/ygkkkca/private.key --fullchain-file /root/ygkkkca/cert.crt --ecc
}

checkip(){
v4v6
if [[ -z $v4 ]]; then
vpsip=$v6
elif [[ -n $v4 && -n $v6 ]]; then
vpsip="$v6 or $v4"
else
vpsip=$v4
fi
domainIP=$(dig @8.8.8.8 +time=2 +short "$ym" 2>/dev/null | grep -m1 '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$')
if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]]; then
domainIP=$(dig @2001:4860:4860::8888 +time=2 aaaa +short "$ym" 2>/dev/null | grep -m1 ':')
fi
if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]] ; then
red "No IP resolved, please check if domain is entered correctly" 
yellow "Try manual IP matching?"
yellow "1: Yes! Enter the domain resolved IP"
yellow "2: No! Exit script"
readp "Please select:" menu
if [ "$menu" = "1" ] ; then
green "VPS local IP: $vpsip"
readp "Enter the domain resolved IP, must match VPS local IP ($vpsip):" domainIP
else
exit
fi
elif [[ -n $(echo $domainIP | grep ":") ]]; then
green "Current domain resolved to IPv6 address: $domainIP"
else
green "Current domain resolved to IPv4 address: $domainIP"
fi
if [[ ! $domainIP =~ $v4 ]] && [[ ! $domainIP =~ $v6 ]]; then
yellow "Current VPS local IP: $vpsip"
red "Current domain resolved IP does not match VPS local IP!!!"
green "Suggestions:"
if [[ "$v6" == "2a09"* || "$v4" == "104.28"* ]]; then
yellow "WARP failed to close automatically, please close manually! Or use the WARP script that supports automatic on/off"
else
yellow "1. Please ensure CDN gray cloud is disabled (DNS only), same for other domain resolution websites"
yellow "2. Please check if the IP set in domain resolution website is correct"
fi
exit 
else
green "IP match correct, starting certificate application..."
fi
}

checkacmeca(){
if [[ "${ym}" == *ip6.arpa* ]]; then
red "ip6.arpa domain certificate application not supported" && exit
fi
nowca=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
if [[ $nowca == $ym ]]; then
red "Detected that the entered domain already has a certificate application record, no need to apply again"
red "Certificate application record as follows:"
bash ~/.acme.sh/acme.sh --list
yellow "If you must reapply, please first execute the delete certificate option" && exit
fi
}

ACMEstandaloneDNS(){
v4v6
readp "Enter the resolved domain:" ym
green "Entered domain: $ym" && sleep 1
checkacmeca
checkip
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
installCA
checktls
}

ACMEDNS(){
readp "Enter the resolved domain:" ym
green "Entered domain: $ym" && sleep 1
checkacmeca
freenom=`echo $ym | awk -F '.' '{print $NF}'`
if [[ $freenom =~ tk|ga|gq|ml|cf ]]; then
red "Detected freenom free domain, current DNS API mode not supported, script exiting" && exit 
fi
if [[ -n $(echo $ym | grep \*) ]]; then
green "Detected wildcard domain certificate application," && sleep 2
else
green "Detected single domain certificate application," && sleep 2
fi
checkacmeca
checkip
echo
ab="Select domain DNS provider:\n1.Cloudflare\n2.Tencent Cloud DNSPod\n3.Alibaba Cloud Aliyun\n Please select:"
readp "$ab" cd
case "$cd" in 
1 )
readp "Copy Cloudflare Global API Key:" GAK
export CF_Key="$GAK"
readp "Enter Cloudflare registered email address:" CFemail
export CF_Email="$CFemail"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
;;
2 )
readp "Copy Tencent Cloud DNSPod DP_Id:" DPID
export DP_Id="$DPID"
readp "Copy Tencent Cloud DNSPod DP_Key:" DPKEY
export DP_Key="$DPKEY"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
;;
3 )
readp "Copy Alibaba Cloud Ali_Key:" ALKEY
export Ali_Key="$ALKEY"
readp "Copy Alibaba Cloud Ali_Secret:" ALSER
export Ali_Secret="$ALSER"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
esac
installCA
checktls
}

ACMEDNScheck(){
wgcfv6=$(curl -s6m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ACMEDNS
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ACMEDNS
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

ACMEstandaloneDNScheck(){
wgcfv6=$(curl -s6m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ACMEstandaloneDNS
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ACMEstandaloneDNS
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

acme(){
mkdir -p /root/ygkkkca
ab="1. Select standalone port 80 mode for certificate (only needs domain, recommended for beginners), port 80 will be released during installation\n2. Select DNS API mode for certificate (needs domain, ID, Key), auto-detects single domain and wildcard domain\n0. Return to previous menu\n Please select:"
readp "$ab" cd
case "$cd" in 
1 ) acme2 && acme3 && ACMEstandaloneDNScheck;;
2 ) acme3 && ACMEDNScheck;;
0 ) start_menu;;
esac
}

Certificate(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh not installed, cannot execute" && exit 
green "The domain shown under Main_Domain is the successfully applied domain certificate, Renew shows the corresponding domain certificate auto-renewal time"
bash ~/.acme.sh/acme.sh --list
}

acmeshow(){
if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
caacme1=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
if [[ -n $caacme1 && ! $caacme1 == "Main_Domain" ]] && [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
caacme=$caacme1
else
caacme='No certificate application record'
fi
else
caacme='acme not installed'
fi
}
cronac(){
uncronac
crontab -l > /tmp/crontab.tmp
echo "0 0 * * * root bash ~/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}
uncronac(){
crontab -l > /tmp/crontab.tmp
sed -i '/--cron/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}
acmerenew(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh not installed, cannot execute" && exit 
green "The domain shown below is the successfully applied domain certificate"
bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'
echo
green "Starting certificate renewal..." && sleep 3
bash ~/.acme.sh/acme.sh --cron -f
checktls
}
uninstall(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh not installed, cannot execute" && exit 
curl https://get.acme.sh | sh
bash ~/.acme.sh/acme.sh --uninstall
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
sed -i '/acme.sh.env/d' ~/.bashrc 
source ~/.bashrc
uncronac
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh uninstall complete" || red "acme.sh uninstall failed"
}

clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Acme-yg Script - Full English Version"
white "GitHub Project: https://github.com/anyagixx/proxme2"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
green "Acme-yg script version V2023.12.18 (English Translation)"
yellow "Notes:"
yellow "1. Script does not support multi-IP VPS, SSH login IP and VPS public IP must be the same"
yellow "2. Port 80 mode only supports single domain certificate application, supports auto-renewal when port 80 is not occupied"
yellow "3. DNS API mode does not support freenom free domain application, supports single domain and wildcard domain certificate application, unconditional auto-renewal"
yellow "4. Before wildcard domain application, must set a DNS record with * character (format: *.primary/secondary-domain)"
yellow "Public key crt save path: /root/ygkkkca/cert.crt"
yellow "Private key key save path: /root/ygkkkca/private.key"
echo
red "========================================================================="
acmeshow
blue "Currently applied certificate (domain format):"
yellow "$caacme"
echo
red "========================================================================="
green " 1. acme.sh apply letsencrypt ECC certificate (supports port 80 mode and DNS API mode) "
green " 2. Query applied domain and auto-renewal time "
green " 3. Manual one-click certificate renewal "
green " 4. Delete certificate and uninstall ACME certificate script "
green " 0. Exit "
echo
readp "Enter number:" NumberInput
case "$NumberInput" in     
1 ) acme;;
2 ) Certificate;;
3 ) acmerenew;;
4 ) uninstall;;
* ) exit      
esac