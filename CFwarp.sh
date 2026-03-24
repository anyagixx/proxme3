#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export LANG=en_US.UTF-8
endpoint=
red='\033[0;31m'
bblue='\033[0;34m'
yellow='\033[0;33m'
green='\033[0;32m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
bblue(){ echo -e "\033[34m\033[01m$1\033[0m";}
rred(){ echo -e "\033[35m\033[01m$1\033[0m";}
readtp(){ read -t5 -n26 -p "$(yellow "$1")" $2;}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "Please run script as root" && exit
if [[ -f /etc/redhat-release ]]; then
release="Centos"
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
red "Script does not support current system, please use Ubuntu, Debian, or Centos system." && exit
fi
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
version=$(uname -r | cut -d "-" -f1)
main=$(uname -r | cut -d "." -f1)
minor=$(uname -r | cut -d "." -f2)
vi=$(systemd-detect-virt)
case "$release" in
"Centos") yumapt='yum -y';;
"Ubuntu"|"Debian") yumapt="apt-get -y";;
esac
cpujg(){
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "Script does not currently support $(uname -m) architecture" && exit;;
esac
}

cfwarpshow(){
insV=$(cat /root/warpip/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/warp-version | awk -F "Update content" '{print $1}' | head -n 1)
if [[ -f /root/warpip/v ]]; then
if [ "$insV" = "$latestV" ]; then
echo -e " Current CFwarp script version: ${bblue}${insV}${plain} (latest version)"
else
echo -e " Current CFwarp script version: ${bblue}${insV}${plain}"
echo -e " Latest CFwarp script version detected: ${yellow}${latestV}${plain} (select 8 to update)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/warp-version)${plain}"
fi
else
echo -e " Current CFwarp script version: ${bblue}${latestV}${plain}"
echo -e " Please select option (1, 2, 3) to install desired WARP mode"
fi
}

tun(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "Detected TUN not enabled, attempting to add TUN support" && sleep 4
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
}

nf4(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
result=$(curl -4fsL --user-agent "${UA_Browser}" --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/70143836" 2>&1)
if [[ "$result" == "404" ]]; then 
NF="Unfortunately, current IP only unlocks Netflix originals"
elif [[ "$result" == "403" ]]; then
NF="Sorry, current IP cannot watch Netflix"
elif [[ "$result" == "200" ]]; then
NF="Congratulations, current IP fully unlocks Netflix non-originals"
else
NF="Netflix does not serve current IP region"
fi
}

nf6(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
result=$(curl -6fsL --user-agent "${UA_Browser}" --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/70143836" 2>&1)
if [[ "$result" == "404" ]]; then 
NF="Unfortunately, current IP only unlocks Netflix originals"
elif [[ "$result" == "403" ]]; then
NF="Sorry, current IP cannot watch Netflix"
elif [[ "$result" == "200" ]]; then
NF="Congratulations, current IP fully unlocks Netflix non-originals"
else
NF="Netflix does not serve current IP region"
fi
}

nfs5() {
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
result=$(curl --user-agent "${UA_Browser}" --write-out %{http_code} --output /dev/null --max-time 10 -sx socks5h://localhost:$mport -4sL "https://www.netflix.com/title/70143836" 2>&1)
if [[ "$result" == "404" ]]; then 
NF="Unfortunately, current IP only unlocks Netflix originals"
elif [[ "$result" == "403" ]]; then
NF="Sorry, current IP cannot watch Netflix"
elif [[ "$result" == "200" ]]; then
NF="Congratulations, current IP fully unlocks Netflix non-originals"
else
NF="Netflix does not serve current IP region"
fi
}

v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
}

checkwgcf(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
}

warpip(){
mkdir -p /root/warpip
v4v6
if [[ -z $v4 ]]; then
endpoint=[2606:4700:d0::a29f:c001]:2408
else
endpoint=162.159.192.1:2408
fi
}

dig9(){
if [[ -n $(grep 'DiG 9' /etc/hosts) ]]; then
echo -e "search blue.kundencontroller.de\noptions rotate\nnameserver 2a02:180:6:5::1c\nnameserver 2a02:180:6:5::4\nnameserver 2a02:180:6:5::1e\nnameserver 2a02:180:6:5::1d" > /etc/resolv.conf
fi
}

mtuwarp(){
v4v6
yellow "Starting automatic WARP MTU optimal throughput setting to optimize WARP network!"
MTUy=1500
MTUc=10
if [[ -n $v6 && -z $v4 ]]; then
ping='ping6'
IP1='2606:4700:4700::1111'
IP2='2001:4860:4860::8888'
else
ping='ping'
IP1='1.1.1.1'
IP2='8.8.8.8'
fi
while true; do
if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
MTUc=1
MTUy=$((${MTUy} + ${MTUc}))
else
MTUy=$((${MTUy} - ${MTUc}))
[[ ${MTUc} = 1 ]] && break
fi
[[ ${MTUy} -le 1360 ]] && MTUy='1360' && break
done
MTU=$((${MTUy} - 80))
green "MTU optimal throughput value = $MTU setting complete"
}

WGproxy(){
curl -sSL https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/acwarp.sh -o acwarp.sh && chmod +x acwarp.sh && bash acwarp.sh
}

xyz(){
if [[ -n $(screen -ls | grep '(Attached)' | awk '{print $1}' | awk -F "." '{print $1}') ]]; then
until [[ -z $(screen -ls | grep '(Attached)' | awk '{print $1}' | awk -F "." '{print $1}' | awk 'NR==1{print}') ]] 
do
Attached=`screen -ls | grep '(Attached)' | awk '{print $1}' | awk -F "." '{print $1}' | awk 'NR==1{print}'`
screen -d $Attached
done
fi
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
rm -rf /root/WARP-UP.sh
cat>/root/WARP-UP.sh<<-\EOF
#!/bin/bash
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
sleep 2
checkwgcf(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
}
warpclose(){
wg-quick down wgcf >/dev/null 2>&1;systemctl stop wg-quick@wgcf >/dev/null 2>&1;systemctl disable wg-quick@wgcf >/dev/null 2>&1;kill -15 $(pgrep warp-go) >/dev/null 2>&1;systemctl stop warp-go >/dev/null 2>&1;systemctl disable warp-go >/dev/null 2>&1
}
warpopen(){
wg-quick down wgcf >/dev/null 2>&1;systemctl enable wg-quick@wgcf >/dev/null 2>&1;systemctl start wg-quick@wgcf >/dev/null 2>&1;systemctl restart wg-quick@wgcf >/dev/null 2>&1;kill -15 $(pgrep warp-go) >/dev/null 2>&1;systemctl stop warp-go >/dev/null 2>&1;systemctl enable warp-go >/dev/null 2>&1;systemctl start warp-go >/dev/null 2>&1;systemctl restart warp-go >/dev/null 2>&1
}
warpre(){
i=0
while [ $i -le 4 ]; do let i++
warpopen
checkwgcf
if [[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]]; then
green "WARP IP obtained successfully after interruption!" 
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] WARP IP obtained successfully after interruption!" >> /root/warpip/warp_log.txt
break
else 
red "WARP IP obtained failed after interruption!"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] WARP IP obtained failed after interruption!" >> /root/warpip/warp_log.txt
fi
done
checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
warpclose
red "After 5 failed attempts to obtain WARP IP, now executing stop and close WARP, VPS restored to original IP state"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] After 5 failed attempts to obtain WARP IP, now executing stop and close WARP, VPS restored to original IP state" >> /root/warpip/warp_log.txt
fi
}
while true; do
green "Checking if WARP is running..."
wp=$(cat /root/warpip/wp.log)
if [[ $wp = w4 ]]; then
checkwgcf
if [[ $wgcfv4 =~ on|plus ]]; then
green "Congratulations! WARP IPV4 status is running! Next check will execute automatically in 600 seconds"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Congratulations! WARP IPV4 status is running! Next check will execute automatically in 600 seconds" >> /root/warpip/warp_log.txt
sleep 600s
else
warpre ; green "Next check will execute automatically in 500 seconds"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Next check will execute automatically in 500 seconds" >> /root/warpip/warp_log.txt
sleep 500s
fi
elif [[ $wp = w6 ]]; then
checkwgcf
if [[ $wgcfv6 =~ on|plus ]]; then
green "Congratulations! WARP IPV6 status is running! Next check will execute automatically in 600 seconds"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Congratulations! WARP IPV6 status is running! Next check will execute automatically in 600 seconds" >> /root/warpip/warp_log.txt
sleep 600s
else
warpre ; green "Next check will execute automatically in 500 seconds"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Next check will execute automatically in 500 seconds" >> /root/warpip/warp_log.txt
sleep 500s
fi
else
checkwgcf
if [[ $wgcfv4 =~ on|plus && $wgcfv6 =~ on|plus ]]; then
green "Congratulations! WARP IPV4+IPV6 status is running! Next check will execute automatically in 600 seconds"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Congratulations! WARP IPV4+IPV6 status is running! Next check will execute automatically in 600 seconds" >> /root/warpip/warp_log.txt
sleep 600s
else
warpre ; green "Next check will execute automatically in 500 seconds"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] Next check will execute automatically in 500 seconds" >> /root/warpip/warp_log.txt
sleep 500s
fi
fi
done
EOF
[[ -e /root/WARP-UP.sh ]] && screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null ; screen -UdmS up bash -c '/bin/bash /root/WARP-UP.sh'
}

first4(){
[[ -e /etc/gai.conf ]] && grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf 2>/dev/null
}

docker(){
if [[ -n $(ip a | grep docker) ]]; then
red "Detected Docker installed on VPS, please ensure Docker is running in host mode, otherwise Docker will not work" && sleep 3s
echo
yellow "Continuing with Option 1 WARP installation in 6 seconds, press Ctrl+c to exit" && sleep 6s
fi
}

lncf(){
curl -sSL -o /usr/bin/cf -L https://raw.githubusercontent.com/anyagixx/proxme3/main/CFwarp.sh
chmod +x /usr/bin/cf
}

UPwpyg(){
if [[ ! -f '/usr/bin/cf' ]]; then
red "CFwarp script not installed properly!" && exit
fi
lncf
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/warp-version | awk -F "Update content" '{print $1}' | head -n 1 > /root/warpip/v
green "CFwarp script updated successfully" && cf
}

restwarpgo(){
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
}

cso(){
warp-cli --accept-tos disconnect >/dev/null 2>&1
warp-cli --accept-tos disable-always-on >/dev/null 2>&1
warp-cli --accept-tos delete >/dev/null 2>&1
if [[ $release = Centos ]]; then
yum autoremove cloudflare-warp -y
else
apt purge cloudflare-warp -y
rm -f /etc/apt/sources.list.d/cloudflare-client.list /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
fi
$yumapt autoremove
}

WARPtools(){
wppluskey(){
if [[ $cpu = amd64 ]]; then
curl -sSL -o warpplus.sh --insecure https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/warp_plus.sh >/dev/null 2>&1
elif [[ $cpu = arm64 ]]; then
curl -sSL -o warpplus.sh --insecure https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/warpplusa.sh >/dev/null 2>&1
fi
chmod +x warpplus.sh
timeout 60s ./warpplus.sh
}
green "1. Real-time view of WARP online monitoring (Note: to exit and continue monitoring: ctrl+a+d, to exit and stop monitoring: ctrl+c)"
green "2. Restart WARP online monitoring function"
green "3. Reset and customize WARP online monitoring interval"
green "4. View today's WARP online monitoring log"
echo "-----------------------------------------------"
green "5. Change Socks5+WARP port"
echo "-----------------------------------------------"
green "6. Use your own WARP key to slowly generate WARP+ traffic"
green "7. One-click generate WARP+ key with 20+ million GB traffic"
echo "-----------------------------------------------"
green "0. Exit"
readp "Please select:" warptools
if [[ $warptools == 1 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "Option 1 not installed, script exiting" && exit
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
if [[ $name =~ "up" ]]; then
screen -Ur up
else
red "WARP monitoring not started, please select 2 to restart" && WARPtools
fi
elif [[ $warptools == 2 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "Option 1 not installed, script exiting" && exit
xyz
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && green "WARP online monitoring started successfully" || red "WARP online monitoring failed to start, check if screen is installed"
elif [[ $warptools == 3 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "Option 1 not installed, script exiting" && exit
xyz
readp "WARP status running, re-check WARP status interval (Enter default 600 seconds), enter interval (e.g. 50 seconds, enter 50):" stop
[[ -n $stop ]] && sed -i "s/600s/${stop}s/g;s/600 seconds/${stop} seconds/g" /root/WARP-UP.sh || green "Default interval 600 seconds"
readp "WARP status interrupted (5 consecutive failures auto-close WARP, restore original VPS IP), continue check WARP status interval (Enter default 500 seconds), enter interval (e.g. 50 seconds, enter 50):" goon
[[ -n $goon ]] && sed -i "s/500s/${goon}s/g;s/500 seconds/${goon} seconds/g" /root/WARP-UP.sh || green "Default interval 500 seconds"
[[ -e /root/WARP-UP.sh ]] && screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null ; screen -UdmS up bash -c '/bin/bash /root/WARP-UP.sh'
green "Setting complete, can view monitoring interval in option 1"
elif [[ $warptools == 4 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "Option 1 not installed, script exiting" && exit
cat /root/warpip/warp_log.txt
elif [[ $warptools == 6 ]]; then
green "You can also generate online: https://replit.com/@ygkkkk/Warp" && sleep 2
wget -N https://gitlab.com/rwkgyg/CFwarp/raw/main/wp-plus.py 
sed -i "27 s/[(][^)]*[)]//g" wp-plus.py
readp "Client config ID (36 characters):" ID
sed -i "27 s/input/'$ID'/" wp-plus.py
python3 wp-plus.py
elif [[ $warptools == 5 ]]; then
SOCKS5WARPPORT
elif [[ $warptools == 7 ]]; then
wppluskey && rm -rf warpplus.sh
green "Current script accumulated generated WARP+ keys placed in /root/WARP+Keys.txt file"
green "Each new key re-executed will be placed at the end of the file (including Option 1 and Option 2)"
blue "$(cat /root/WARP+Keys.txt)"
echo
else
cf
fi
}

chatgpt4(){
gpt1=$(curl -s4 https://chat.openai.com 2>&1)
gpt2=$(curl -s4 https://ios.chat.openai.com 2>&1)
}
chatgpt6(){
gpt1=$(curl -s6 https://chat.openai.com 2>&1)
gpt2=$(curl -s6 https://ios.chat.openai.com 2>&1)
}
checkgpt(){
if [[ $gpt2 == *VPN* ]]; then
chat='Unfortunately, current IP only unlocks ChatGPT web, not client'
elif [[ $gpt2 == *Request* ]]; then
chat='Congratulations, current IP fully unlocks ChatGPT (web+client)'
else
chat='Sorry, current IP cannot unlock ChatGPT service'
fi
}

ShowSOCKS5(){
if [[ $(systemctl is-active warp-svc) = active ]]; then
mport=`warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}'`
s5ip=`curl -sx socks5h://localhost:$mport icanhazip.com -k`
nfs5
gpt1=$(curl -sx socks5h://localhost:$mport https://chat.openai.com 2>&1)
gpt2=$(curl -sx socks5h://localhost:$mport https://android.chat.openai.com 2>&1)
checkgpt
nonf=$(curl -sx socks5h://localhost:$mport --user-agent "${UA_Browser}" http://ip-api.com/json/$s5ip?lang=en -k | cut -f2 -d"," | cut -f4 -d '"')
country=$nonf
socks5=$(curl -sx socks5h://localhost:$mport www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 2 | grep warp | cut -d= -f2) 
case ${socks5} in 
plus) 
S5Status=$(white "Socks5 WARP+ status: " ; rred "Running, WARP+ account (remaining WARP+ traffic: $((`warp-cli --accept-tos account | grep Quota | awk '{ print $(NF) }'`/1000000000)) GB)" ; white " Socks5 port: " ; rred "$mport" ; white " Provider Cloudflare obtained IPV4 address: " ; rred "$s5ip  $country" ; white " Netflix unlock status: " ; rred "$NF" ; white " ChatGPT unlock status: " ; rred "$chat");;  
on) 
S5Status=$(white "Socks5 WARP status: " ; green "Running, WARP free account (unlimited WARP traffic)" ; white " Socks5 port: " ; green "$mport" ; white " Provider Cloudflare obtained IPV4 address: " ; green "$s5ip  $country" ; white " Netflix unlock status: " ; green "$NF" ; white " ChatGPT unlock status: " ; green "$chat");;  
*) 
S5Status=$(white "Socks5 WARP status: " ; yellow "Socks5-WARP client installed, but port is closed")
esac 
else
S5Status=$(white "Socks5 WARP status: " ; red "Socks5-WARP client not installed")
fi
}

SOCKS5ins(){
yellow "Checking Socks5-WARP installation environment..."
if [[ $release = Centos ]]; then
[[ ! ${vsid} =~ 8 ]] && yellow "Current system version: Centos $vsid \nSocks5-WARP only supports Centos 8 " && exit 
elif [[ $release = Ubuntu ]]; then
[[ ! ${vsid} =~ 20|22|24 ]] && yellow "Current system version: Ubuntu $vsid \nSocks5-WARP only supports Ubuntu 20.04/22.04/24.04 systems " && exit 
elif [[ $release = Debian ]]; then
[[ ! ${vsid} =~ 10|11|12|13 ]] && yellow "Current system version: Debian $vsid \nSocks5-WARP only supports Debian 10/11/12/13 systems " && exit 
fi
[[ $(warp-cli --accept-tos status 2>/dev/null) =~ 'Connected' ]] && red "Socks5-WARP is currently running" && cf

systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4v6
if [[ -n $v6 && -z $v4 ]]; then
systemctl start wg-quick@wgcf >/dev/null 2>&1
restwarpgo
red "Pure IPV6 VPS currently does not support Socks5-WARP installation" && sleep 2 && exit
else
systemctl start wg-quick@wgcf >/dev/null 2>&1
restwarpgo
fi
if [[ $release = Centos ]]; then 
yum -y install epel-release && yum -y install net-tools
curl -fsSl https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | tee /etc/yum.repos.d/cloudflare-warp.repo
yum update
yum -y install cloudflare-warp
fi
if [[ $release = Debian ]]; then
[[ ! $(type -P gpg) ]] && apt update && apt install gnupg -y
[[ ! $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && apt update && apt install apt-transport-https -y
fi
if [[ $release != Centos ]]; then 
apt install net-tools -y
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install cloudflare-warp
fi
warpip
echo y | warp-cli registration new
warp-cli mode proxy 
warp-cli proxy port 40000
warp-cli connect
green "Installation complete, returning to menu"
sleep 2 && lncf && reswarp && cf
}

SOCKS5WARPUP(){
[[ ! $(type -P warp-cli) ]] && red "Socks5-WARP not installed, cannot upgrade to Socks5-WARP+ account" && exit
[[ $(warp-cli --accept-tos account) =~ 'Limited' ]] && red "Already Socks5-WARP+ account, no need to upgrade" && exit
readp "Enter license key (26 characters):" ID
[[ -n $ID ]] && warp-cli --accept-tos set-license $ID >/dev/null 2>&1 || (red "License key not entered (26 characters)" && exit)
yellow "If Error: Too many devices, may have exceeded 5 device limit or key entered incorrectly"
if [[ $(warp-cli --accept-tos account) =~ 'Limited' ]]; then
green "Upgraded to Socks5-WARP+ account\nSocks5-WARP+ account remaining traffic: $((`warp-cli --accept-tos account | grep Quota | awk '{ print $(NF) }'`/1000000000)) GB"
else
red "Socks5-WARP+ account upgrade failed" && exit
fi
sleep 2 && ShowSOCKS5 && S5menu
}

SOCKS5WARPPORT(){
[[ ! $(type -P warp-cli) ]] && red "Socks5-WARP(+) not installed, cannot change port" && exit
readp "Enter custom socks5 port [2000-65535] (Enter for random port between 2000-65535):" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nPort in use, please re-enter port" && readp "Custom socks5 port:" port
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nPort in use, please re-enter port" && readp "Custom socks5 port:" port
done
fi
[[ -n $port ]] && warp-cli --accept-tos set-proxy-port $port >/dev/null 2>&1
green "Current socks5 port: $port"
sleep 2 && ShowSOCKS5 && S5menu
}

WGCFmenu(){
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && keepup="WARP monitoring enabled" || keepup="WARP monitoring disabled"
white "------------------------------------------------------------------------------------"
white " Option 1: Current IPV4 outbound status ($keepup)"
white " ${WARPIPv4Status}"
white "------------------------------------------------------------------------------------"
white " Option 1: Current IPV6 outbound status ($keepup)"
white " ${WARPIPv6Status}"
white "------------------------------------------------------------------------------------"
if [[ "$WARPIPv4Status" == *not exist* && "$WARPIPv6Status" == *not exist* ]]; then
yellow "Both IPV4 and IPV6 do not exist, suggestions:"
red "1. If previously installed wgcf, select 9 to switch to warp-go and reinstall WARP"
red "2. If previously installed warp-go, select 10 to switch to wgcf and reinstall WARP"
red "Note: If still failing, suggest uninstalling and rebooting VPS, then reinstall Option 1"
fi
}
S5menu(){
white "------------------------------------------------------------------------------------------------"
white " Option 2: Current Socks5-WARP official client local proxy status"
blue " ${S5Status}"
white "------------------------------------------------------------------------------------------------"
}

reswarp(){
unreswarp
crontab -l > /tmp/crontab.tmp
echo "0 4 * * * systemctl stop warp-go;systemctl restart warp-go;systemctl restart wg-quick@wgcf;systemctl restart warp-svc" >> /tmp/crontab.tmp
echo "@reboot screen -UdmS up /bin/bash /root/WARP-UP.sh" >> /tmp/crontab.tmp
echo "0 0 * * * rm -f /root/warpip/warp_log.txt" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

unreswarp(){
crontab -l > /tmp/crontab.tmp
sed -i '/systemctl stop warp-go;systemctl restart warp-go;systemctl restart wg-quick@wgcf;systemctl restart warp-svc/d' /tmp/crontab.tmp
sed -i '/@reboot screen/d' /tmp/crontab.tmp
sed -i '/warp_log.txt/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

ONEWARPGO(){
if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
red "Script does not support current $op system, please use Ubuntu, Debian, or Centos system." && exit
fi
yellow "\n Please wait, current WARP-GO kernel installation mode, checking endpoint IP and outbound status..."
warpip

wgo1='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0#g" /usr/local/bin/warp.conf'
wgo2='sed -i "s#.*AllowedIPs.*#AllowedIPs = ::/0#g" /usr/local/bin/warp.conf'
wgo3='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0,::/0#g" /usr/local/bin/warp.conf'
wgo4='sed -i "/Endpoint6/d" /usr/local/bin/warp.conf && sed -i "/Endpoint/s/.*/Endpoint = '"$endpoint"'/" /usr/local/bin/warp.conf'
wgo5='sed -i "/Endpoint6/d" /usr/local/bin/warp.conf && sed -i "/Endpoint/s/.*/Endpoint = '"$endpoint"'/" /usr/local/bin/warp.conf'
wgo6='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf'
wgo7='sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf'
wgo8='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf'

STOPwgcf(){
if [[ -n $(type -P warp-cli) ]]; then
red "Socks5-WARP installed, current WARP installation option not supported" 
systemctl restart warp-go && cf
fi
}

ShowWGCF(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
v4v6
warppflow=$((`grep -oP '"quota":\K\d+' <<< $(curl -sm4 "https://api.cloudflareclient.com/v0a884/reg/$(grep 'Device' /usr/local/bin/warp.conf 2>/dev/null | cut -d= -f2 | sed 's# ##g')" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $(grep 'Token' /usr/local/bin/warp.conf 2>/dev/null | cut -d= -f2 | sed 's# ##g')")`))
flow=`echo "scale=2; $warppflow/1000000000" | bc`
[[ -e /usr/local/bin/warpplus.log ]] && cfplus="WARP+ account (limited WARP+ traffic: $flow GB), device name: $(sed -n 1p /usr/local/bin/warpplus.log)" || cfplus="WARP+ Teams account (unlimited WARP+ traffic)"
if [[ -n $v4 ]]; then
nf4
chatgpt4
checkgpt
wgcfv4=$(curl -s4 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
isp4a=`curl -sm3 --user-agent "${UA_Browser}" http://ip-api.com/json/$v4?lang=en -k | cut -f13 -d ":" | cut -f2 -d '"'`
isp4b=`curl -sm3 --user-agent "${UA_Browser}" https://api.ip.sb/geoip/$v4 -k | awk -F "isp" '{print $2}' | awk -F "offset" '{print $1}' | sed "s/[,\":]//g"`
[[ -n $isp4a ]] && isp4=$isp4a || isp4=$isp4b
nonf=$(curl -sm3 --user-agent "${UA_Browser}" http://ip-api.com/json/$v4?lang=en -k | cut -f2 -d"," | cut -f4 -d '"')
country=$nonf
case ${wgcfv4} in 
plus) 
WARPIPv4Status=$(white "WARP+ status: " ; rred "Running, $cfplus" ; white " Provider Cloudflare obtained IPV4 address: " ; rred "$v4  $country" ; white " Netflix unlock status: " ; rred "$NF" ; white " ChatGPT unlock status: " ; rred "$chat");;  
on) 
WARPIPv4Status=$(white "WARP status: " ; green "Running, WARP free account (unlimited WARP traffic)" ; white " Provider Cloudflare obtained IPV4 address: " ; green "$v4  $country" ; white " Netflix unlock status: " ; green "$NF" ; white " ChatGPT unlock status: " ; green "$chat");;
off) 
WARPIPv4Status=$(white "WARP status: " ; yellow "Disabled" ; white " Provider $isp4 obtained IPV4 address: " ; yellow "$v4  $country" ; white " Netflix unlock status: " ; yellow "$NF" ; white " ChatGPT unlock status: " ; yellow "$chat");; 
esac 
else
WARPIPv4Status=$(white "IPV4 status: " ; red "IPV4 address does not exist ")
fi 
if [[ -n $v6 ]]; then
nf6
chatgpt6
checkgpt
wgcfv6=$(curl -s6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
isp6a=`curl -sm3 --user-agent "${UA_Browser}" http://ip-api.com/json/$v6?lang=en -k | cut -f13 -d":" | cut -f2 -d '"'`
isp6b=`curl -sm3 --user-agent "${UA_Browser}" https://api.ip.sb/geoip/$v6 -k | awk -F "isp" '{print $2}' | awk -F "offset" '{print $1}' | sed "s/[,\":]//g"`
[[ -n $isp6a ]] && isp6=$isp6a || isp6=$isp6b
nonf=$(curl -sm3 --user-agent "${UA_Browser}" http://ip-api.com/json/$v6?lang=en -k | cut -f2 -d"," | cut -f4 -d '"')
country=$nonf
case ${wgcfv6} in 
plus) 
WARPIPv6Status=$(white "WARP+ status: " ; rred "Running, $cfplus" ; white " Provider Cloudflare obtained IPV6 address: " ; rred "$v6  $country" ; white " Netflix unlock status: " ; rred "$NF" ; white " ChatGPT unlock status: " ; rred "$chat");;  
on) 
WARPIPv6Status=$(white "WARP status: " ; green "Running, WARP free account (unlimited WARP traffic)" ; white " Provider Cloudflare obtained IPV6 address: " ; green "$v6  $country" ; white " Netflix unlock status: " ; green "$NF" ; white " ChatGPT unlock status: " ; green "$chat");;
off) 
WARPIPv6Status=$(white "WARP status: " ; yellow "Disabled" ; white " Provider $isp6 obtained IPV6 address: " ; yellow "$v6  $country" ; white " Netflix unlock status: " ; yellow "$NF" ; white " ChatGPT unlock status: " ; yellow "$chat");;
esac 
else
WARPIPv6Status=$(white "IPV6 status: " ; red "IPV6 address does not exist ")
fi 
}

CheckWARP(){
i=0
while [ $i -le 9 ]; do let i++
yellow "Total 10 attempts, attempt $i to obtain WARP IP..."
restwarpgo
checkwgcf
if [[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]]; then
green "Congratulations! WARP IP obtained successfully!" && dns
break
else
red "Unfortunately! WARP IP obtained failed"
fi
done
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
red "WARP installation failed, restoring VPS, uninstalling WARP"
cwg
echo
[[ $release = Centos && ${vsid} -lt 7 ]] && yellow "Current system version: Centos $vsid \nRecommended Centos 7 or above " 
[[ $release = Ubuntu && ${vsid} -lt 18 ]] && yellow "Current system version: Ubuntu $vsid \nRecommended Ubuntu 18 or above " 
[[ $release = Debian && ${vsid} -lt 10 ]] && yellow "Current system version: Debian $vsid \nRecommended Debian 10 or above "
yellow "Note:"
red "You may use Option 2 or Option 3 to implement WARP"
red "You can also select WGCF kernel to install WARP Option 1"
exit
else 
green "OK" && systemctl restart warp-go
fi
}

nat4(){
[[ -n $(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+') ]] && wpgo4=$wgo6 || wpgo4=echo
}

WGCFv4(){
yellow "Wait 3 seconds, checking VPS WARP environment"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Current native v4+v6 dual-stack VPS first time WARP-GO installation\nNow adding WARP IPV4 (IP outbound: native IPV6 + WARP IPV4)" && sleep 2
wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo8 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "Current native v6 single-stack VPS first time WARP-GO installation\nNow adding WARP IPV4 (IP outbound: native IPV6 + WARP IPV4)" && sleep 2
wpgo1=$wgo1 && wpgo2=$wgo5 && wpgo3=$wgo7 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "Current native v4 single-stack VPS first time WARP-GO installation\nNow adding WARP IPV4 (IP outbound: WARP IPV4 only)" && sleep 2
wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo6 && WGCFins
fi
echo 'w4' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
kill -15 $(pgrep warp-go) >/dev/null 2>&1
sleep 2 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Current native v4+v6 dual-stack VPS WARP-GO installed\nNow quick switching WARP IPV4 (IP outbound: native IPV6 + WARP IPV4)" && sleep 2
wpgo1=$wgo1 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "Current native v6 single-stack VPS WARP-GO installed\nNow quick switching WARP IPV4 (IP outbound: native IPV6 + WARP IPV4)" && sleep 2
wpgo1=$wgo1 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "Current native v4 single-stack VPS WARP-GO installed\nNow quick switching WARP IPV4 (IP outbound: WARP IPV4 only)" && sleep 2
wpgo1=$wgo1 && ABC
fi
echo 'w4' > /root/warpip/wp.log
cat /usr/local/bin/warp.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

WGCFv6(){
yellow "Wait 3 seconds, checking VPS WARP environment"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Current native v4+v6 dual-stack VPS first time WARP-GO installation\nNow adding WARP IPV6 (IP outbound: native IPV4 + WARP IPV6)" && sleep 2
wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo8 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "Current native v6 single-stack VPS first time WARP-GO installation\nNow adding WARP IPV6 (IP outbound: WARP IPV6 only)" && sleep 2
wpgo1=$wgo2 && wpgo2=$wgo5 && wpgo3=$wgo7 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "Current native v4 single-stack VPS first time WARP-GO installation\nNow adding WARP IPV6 (IP outbound: native IPV4 + WARP IPV6)" && sleep 2
wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo6 && WGCFins
fi
echo 'w6' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
kill -15 $(pgrep warp-go) >/dev/null 2>&1
sleep 2 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Current native v4+v6 dual-stack VPS WARP-GO installed\nNow quick switching WARP IPV6 (IP outbound: native IPV4 + WARP IPV6)" && sleep 2
wpgo1=$wgo2 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "Current native v6 single-stack VPS WARP-GO installed\nNow quick switching WARP IPV6 (IP outbound: WARP IPV6 only)" && sleep 2
wpgo1=$wgo2 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "Current native v4 single-stack VPS WARP-GO installed\nNow quick switching WARP IPV6 (IP outbound: native IPV4 + WARP IPV6)" && sleep 2
wpgo1=$wgo2 && ABC
fi
echo 'w6' > /root/warpip/wp.log
cat /usr/local/bin/warp.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

WGCFv4v6(){
yellow "Wait 3 seconds, checking VPS WARP environment"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Current native v4+v6 dual-stack VPS first time WARP-GO installation\nNow adding WARP IPV4+IPV6 (IP outbound: WARP dual-stack IPV4 + IPV6)" && sleep 2
wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo8 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "Current native v6 single-stack VPS first time WARP-GO installation\nNow adding WARP IPV4+IPV6 (IP outbound: WARP dual-stack IPV4 + IPV6)" && sleep 2
wpgo1=$wgo3 && wpgo2=$wgo5 && wpgo3=$wgo7 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "Current native v4 single-stack VPS first time WARP-GO installation\nNow adding WARP IPV4+IPV6 (IP outbound: WARP dual-stack IPV4 + IPV6)" && sleep 2
wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo6 && WGCFins
fi
echo 'w64' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
kill -15 $(pgrep warp-go) >/dev/null 2>&1
sleep 2 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Current native v4+v6 dual-stack VPS WARP-GO installed\nNow quick switching WARP IPV4+IPV6 (IP outbound: WARP dual-stack IPV4 + IPV6)" && sleep 2
wpgo1=$wgo3 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "Current native v6 single-stack VPS WARP-GO installed\nNow quick switching WARP IPV4+IPV6 (IP outbound: WARP dual-stack IPV4 + IPV6)" && sleep 2
wpgo1=$wgo3 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "Current native v4 single-stack VPS WARP-GO installed\nNow quick switching WARP IPV4+IPV6 (IP outbound: WARP dual-stack IPV4 + IPV6)" && sleep 2
wpgo1=$wgo3 && ABC
fi
echo 'w64' > /root/warpip/wp.log
cat /usr/local/bin/warp.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

ABC(){
echo $wpgo1 | sh
echo $wpgo2 | sh
echo $wpgo3 | sh
echo $wpgo4 | sh
}

dns(){
if [[ ! -f /etc/resolv.conf.bak ]]; then
mv /etc/resolv.conf /etc/resolv.conf.bak
rm -rf /etc/resolv.conf
cp -f /etc/resolv.conf.bak /etc/resolv.conf
chattr +i /etc/resolv.conf >/dev/null 2>&1
else
chattr +i /etc/resolv.conf >/dev/null 2>&1
fi
}

WGCFins(){
if [[ $release = Centos ]]; then
yum install epel-release -y;yum install iproute iputils -y
elif [[ $release = Debian ]]; then
apt install lsb-release -y
echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
apt update -y;apt install iproute2 openresolv dnsutils iputils-ping -y
elif [[ $release = Ubuntu ]]; then
apt update -y;apt install iproute2 openresolv dnsutils iputils-ping -y
fi
wget -N https://gitlab.com/rwkgyg/CFwarp/-/raw/main/warp-go_1.0.8_linux_${cpu} -O /usr/local/bin/warp-go && chmod +x /usr/local/bin/warp-go
yellow "Applying for WARP free account, please wait!"
if [[ ! -s /usr/local/bin/warp.conf ]]; then
cpujg
curl -L -o warpapi -# --retry 2 https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > /usr/local/bin/warp.conf <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.1:2408
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
chmod +x /usr/local/bin/warp.conf
sed -i '0,/AllowedIPs/{/AllowedIPs/d;}' /usr/local/bin/warp.conf
sed -i '/KeepAlive/a [Script]' /usr/local/bin/warp.conf
mtuwarp
sed -i "s/MTU.*/MTU = $MTU/g" /usr/local/bin/warp.conf
cat > /lib/systemd/system/warp-go.service << EOF
[Unit]
Description=warp-go service
After=network.target
Documentation=https://gitlab.com/ProjectWARP/warp-go
[Service]
WorkingDirectory=/root/
ExecStart=/usr/local/bin/warp-go --config=/usr/local/bin/warp.conf
Environment="LOG_LEVEL=verbose"
RemainAfterExit=yes
Restart=always
[Install]
WantedBy=multi-user.target
EOF
ABC
systemctl daemon-reload
systemctl enable warp-go
systemctl start warp-go
restwarpgo
cat /usr/local/bin/warp.conf && sleep 2
checkwgcf
if [[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]]; then
green "Congratulations! WARP IP obtained successfully!" && dns
else
CheckWARP
fi
ShowWGCF && lncf && reswarp
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/warp-version | awk -F "Update content" '{print $1}' | head -n 1 > /root/warpip/v
}

warpinscha(){
yellow "Note: VPS local outbound IP will be taken over by the WARP IP you selected, if VPS does not have that outbound IP, it will be taken over by another generated WARP IP"
echo
green "1. Install/Switch WARP single-stack IPV4 (Enter for default)"
green "2. Install/Switch WARP single-stack IPV6"
green "3. Install/Switch WARP dual-stack IPV4+IPV6"
readp "\nPlease select:" wgcfwarp
if [ -z "${wgcfwarp}" ] || [ $wgcfwarp == "1" ];then
WGCFv4
elif [ $wgcfwarp == "2" ];then
WGCFv6
elif [ $wgcfwarp == "3" ];then
WGCFv4v6
else 
red "Invalid input, please select again" && warpinscha
fi
echo
} 

WARPup(){
freewarp(){
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4v6
allowips=$(cat /usr/local/bin/warp.conf | grep AllowedIPs)
if [[ -n $v4 && -n $v6 ]]; then
endp=$wgo4
post=$wgo8
elif [[ -n $v6 && -z $v4 ]]; then
endp=$wgo5
[[ -n $(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+') ]] && post=$wgo8 || post=$wgo7
elif [[ -z $v6 && -n $v4 ]]; then
endp=$wgo4
post=$wgo6
fi
yellow "Current execution: Applying for WARP free account"
echo
yellow "Applying for WARP free account, please wait!"
rm -rf /usr/local/bin/warp.conf /usr/local/bin/warp.conf.bak /usr/local/bin/warpplus.log
curl -Ls -o /usr/local/bin/warp.conf --retry 2 https://api.zeroteam.top/warp?format=warp-go
if [[ ! -s /usr/local/bin/warp.conf ]]; then
cpujg
curl -Ls -o warpapi --retry 2 https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > /usr/local/bin/warp.conf <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.1:2408
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
chmod +x /usr/local/bin/warp.conf
sed -i '0,/AllowedIPs/{/AllowedIPs/d;}' /usr/local/bin/warp.conf
sed -i '/KeepAlive/a [Script]' /usr/local/bin/warp.conf
mtuwarp
sed -i "s/MTU.*/MTU = $MTU/g" /usr/local/bin/warp.conf
sed -i "s#.*AllowedIPs.*#$allowips#g" /usr/local/bin/warp.conf
echo $endp | sh
echo $post | sh
CheckWARP && ShowWGCF &&  WGCFmenu
}

green "1. WARP free account (unlimited traffic)"
green "2. WARP+ account (limited traffic)"
green "3. WARP Teams (Zero Trust) team account (unlimited traffic)"
green "4. Socks5+WARP+ account (limited traffic)"
readp "Select account type to switch:" warpup
if [[ $warpup == 1 ]]; then
freewarp
fi

if [[ $warpup == 4 ]]; then
SOCKS5WARPUP
fi

if [[ $warpup == 2 ]]; then
[[ ! $(type -P warp-go) ]] && red "warp-go not installed" && exit
green "Please copy mobile WARP client WARP+ license key or shared key (26 characters), current WARP-GO BUG issue, upgrade likely to fail"
readp "Enter WARP+ license key:" ID
if [[ -z $ID ]]; then
red "Nothing entered" && WARPup
fi
readp "Set device name, Enter for random:" dname
if [[ -z $dname ]]; then
dname=`date +%s%N |md5sum | cut -c 1-4`
fi
green "Device name is $dname"
/usr/local/bin/warp-go --update --config=/usr/local/bin/warp.conf --license=$ID --device-name=$dname
i=0
while [ $i -le 9 ]; do let i++
yellow "Total 10 attempts, attempt $i upgrading WARP+ account..." 
restwarpgo
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
rm -rf /usr/local/bin/warp.conf.bak /usr/local/bin/warpplus.log
echo "$dname" >> /usr/local/bin/warpplus.log && echo "$ID" >> /usr/local/bin/warpplus.log
green "WARP+ account upgrade successful!" && ShowWGCF && WGCFmenu && break
else
red "WARP+ account upgrade failed!" && sleep 1
fi
done
if [[ ! $wgcfv4 = plus && ! $wgcfv6 = plus ]]; then
green "Suggestions:"
yellow "1. Check if 1.1.1.1 APP WARP+ account or shared key has traffic"
yellow "2. Check if current WARP license key has more than 5 devices bound, please remove devices in mobile app and try upgrading WARP+ account again" && sleep 2
freewarp
fi
fi
    
if [[ $warpup == 3 ]]; then
[[ ! $(type -P warp-go) ]] && red "warp-go not installed" && exit
green "Zero Trust team token URL: https://web--public--warp-team-api--coia-mfs4.code.run/"
readp "Enter team account Token: " token
curl -Ls -o /usr/local/bin/warp.conf.bak --retry 2 https://api.zeroteam.top/warp?format=warp-go
if [[ ! -s /usr/local/bin/warp.conf.bak ]]; then
cpujg
curl -Ls -o warpapi --retry 2 https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > /usr/local/bin/warp.conf.bak <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.1:2408
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
/usr/local/bin/warp-go --register --config=/usr/local/bin/warp.conf.bak --team-config=$token --device-name=vps+warp+teams+$(date +%s%N |md5sum | cut -c 1-3)
sed -i "2s#.*#$(sed -ne 2p /usr/local/bin/warp.conf.bak)#;3s#.*#$(sed -ne 3p /usr/local/bin/warp.conf.bak)#" /usr/local/bin/warp.conf >/dev/null 2>&1
sed -i "4s#.*#$(sed -ne 4p /usr/local/bin/warp.conf.bak)#;5s#.*#$(sed -ne 5p /usr/local/bin/warp.conf.bak)#" /usr/local/bin/warp.conf >/dev/null 2>&1
i=0
while [ $i -le 9 ]; do let i++
yellow "Total 10 attempts, attempt $i to obtain WARP IP..."
restwarpgo
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
rm -rf /usr/local/bin/warp.conf.bak /usr/local/bin/warpplus.log
green "WARP Teams account upgrade successful!" && ShowWGCF && WGCFmenu && break
else
red "WARP Teams account upgrade failed!" && sleep 1
fi
done
if [[ ! $wgcfv4 = plus && ! $wgcfv6 = plus ]]; then
freewarp
fi
fi
}

WARPonoff(){
[[ ! $(type -P warp-go) ]] && red "WARP not installed, recommended to reinstall" && exit
readp "1. Disable WARP function (disable WARP online monitoring)\n2. Enable/Restart WARP function (start WARP online monitoring)\n0. Return to previous menu\n Please select:" unwp
if [ "$unwp" == "1" ]; then
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
systemctl disable warp-go
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
unreswarp
checkwgcf 
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && green "WARP disabled successfully" || red "WARP disable failed"
elif [ "$unwp" == "2" ]; then
CheckWARP
xyz
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && green "WARP online monitoring started successfully" || red "WARP online monitoring failed to start, check if screen is installed"
reswarp
checkwgcf 
[[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]] && green "WARP enabled successfully" || red "WARP enable failed"
else
cf
fi
}

cwg(){
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
systemctl disable warp-go >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 
chattr -i /etc/resolv.conf >/dev/null 2>&1
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf 2>/dev/null
rm -rf /usr/local/bin/warp-go /usr/local/bin/warpplus.log /usr/local/bin/warp.conf /usr/local/bin/wgwarp.conf /usr/local/bin/sbwarp.json /usr/bin/warp-go /lib/systemd/system/warp-go.service /root/WARP-UP.sh
rm -rf /root/warpip
}

changewarp(){
cwg && ONEWGCFWARP
}

upwarpgo(){
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
wget -N https://gitlab.com/rwkgyg/CFwarp/-/raw/main/warp-go_1.0.8_linux_${cpu} -O /usr/local/bin/warp-go && chmod +x /usr/local/bin/warp-go
restwarpgo
loVERSION="$(/usr/local/bin/warp-go -v | sed -n 1p | awk '{print $1}' | awk -F"/" '{print $NF}')"
green " Current WARP-GO installed kernel version: ${loVERSION}, already latest version"
}

start_menu(){
ShowWGCF;ShowSOCKS5
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
echo
white "CFwarp Script - Full English Version"
white "GitHub Project: https://github.com/anyagixx/proxme3"
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow " Select WARP solution that suits you (options 1, 2, 3, can be single or multiple coexistence)"
yellow " Script shortcut: cf"
white " ================================================================="
green "  1. Option 1: Install/Switch WARP-GO"
green "  2. Option 2: Install Socks5-WARP"
green "  3. Option 3: Generate WARP-Wireguard config file, QR code"
green "  4. Uninstall WARP"
white " -----------------------------------------------------------------"
green "  5. Disable, Enable/Restart WARP"
green "  6. WARP other options"
green "  7. WARP three account types upgrade/switch"
green "  8. Update CFwarp installation script"
green "  9. Update WARP-GO kernel"
green " 10. Replace current WARP-GO kernel with WGCF-WARP kernel"
green "  0. Exit script "
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
cfwarpshow
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white " VPS system information:"
white " System: $op"
white " Kernel: $version"
white " Architecture: $(uname -m)"
white " Virtualization: $vi"
white " BBR: $bbr"
echo
readp "Please enter number:" NumberInput
case "$NumberInput" in     
1 ) warpinscha;;
2 ) SOCKS5ins;;
3 ) WGproxy;;
4 ) WARPun;;
5 ) WARPonoff;;
6 ) WARPtools;;
7 ) WARPup;;
8 ) UPwpyg;;
9 ) upwarpgo;;
10 ) changewarp;;
* ) exit      
esac
}

cf(){
start_menu
}

bbr(){
if [[ $vi =~ lxc|openvz ]]; then
red "LXC/OpenVZ virtualization detected, BBR installation not supported"
yellow "Suggestion: Use Option 1 WARP to optimize network"
readp "Press Enter to return to main menu..."
cf
fi
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
}

ONEWGCFWARP(){
warpinscha
}

if [[ -f /etc/gai.conf ]]; then
grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
fi
clear
start_menu
