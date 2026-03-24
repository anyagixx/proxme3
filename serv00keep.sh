#!/bin/bash
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }
export LC_ALL=C
export UUID=${UUID:-''}  
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}   
export ARGO_AUTH=${ARGO_AUTH:-''}     
export vless_port=${vless_port:-''}    
export vmess_port=${vmess_port:-''}  
export hy2_port=${hy2_port:-''}       
export IP=${IP:-''}                  
export reym=${reym:-''}
export reset=${reset:-''}
export resport=${resport:-''}
devil binexec on >/dev/null 2>&1
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
HOSTNAME=$(hostname)
snb=$(hostname | cut -d. -f1)
nb=$(hostname | cut -d '.' -f 1 | tr -d 's')
if [[ "$reset" =~ ^[Yy]$ ]]; then
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
devil www list | awk 'NR > 1 && NF {print $1}' | xargs -I {} devil www del {} > /dev/null 2>&1
sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' "${HOME}/.bashrc" >/dev/null 2>&1
source "${HOME}/.bashrc" >/dev/null 2>&1
find ~ -type f -exec chmod 644 {} \; 2>/dev/null
find ~ -type d -exec chmod 755 {} \; 2>/dev/null
find ~ -type f -exec rm -f {} \; 2>/dev/null
find ~ -type d -empty -exec rmdir {} \; 2>/dev/null
find ~ -exec rm -rf {} \; 2>/dev/null
echo "System reset completed"
fi
devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"
WORKDIR="${HOME}/domains/${USERNAME}.serv00.net/logs"
[ -d "$FILE_PATH" ] || mkdir -p "$FILE_PATH"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")
keep_path="${HOME}/domains/${snb}.${USERNAME}.serv00.net/public_nodejs"
[ -d "$keep_path" ] || mkdir -p "$keep_path"

if [[ -z "$ARGO_AUTH" ]] && [[ -f "$WORKDIR/ARGO_AUTH.log" ]]; then
ARGO_AUTH=$(cat "$WORKDIR/ARGO_AUTH.log" 2>/dev/null)
elif [[ -z "$ARGO_AUTH" ]] && [[ ! -f "$WORKDIR/ARGO_AUTH.log" ]]; then
echo "$ARGO_AUTH" > $WORKDIR/ARGO_AUTH.log
else
echo "$ARGO_AUTH" > $WORKDIR/ARGO_AUTH.log
ARGO_AUTH=$(cat "$WORKDIR/ARGO_AUTH.log" 2>/dev/null)
fi
if [[ -z "$ARGO_DOMAIN" ]] && [[ -f "$WORKDIR/ARGO_DOMAIN.log" ]]; then
ARGO_DOMAIN=$(cat "$WORKDIR/ARGO_DOMAIN.log" 2>/dev/null)
elif [[ -z "$ARGO_DOMAIN" ]] && [[ ! -f "$WORKDIR/ARGO_DOMAIN.log" ]]; then
echo "$ARGO_DOMAIN" > $WORKDIR/ARGO_DOMAIN.log
else
echo "$ARGO_DOMAIN" > $WORKDIR/ARGO_DOMAIN.log
ARGO_DOMAIN=$(cat "$WORKDIR/ARGO_DOMAIN.log" 2>/dev/null)
fi

if [[ -z "$UUID" ]] && [[ -f "$WORKDIR/UUID.txt" ]]; then
UUID=$(cat "$WORKDIR/UUID.txt" 2>/dev/null)
elif [[ -z "$UUID" ]] && [[ ! -f "$WORKDIR/UUID.txt" ]]; then
UUID=$(uuidgen -r)
echo "$UUID" > $WORKDIR/UUID.txt
else
echo "$UUID" > $WORKDIR/UUID.txt
UUID=$(cat "$WORKDIR/UUID.txt" 2>/dev/null)
fi
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/app.js -o "$keep_path"/app.js
sed -i '' "15s/name/$snb/g" "$keep_path"/app.js
sed -i '' "59s/key/$UUID/g" "$keep_path"/app.js
sed -i '' "90s/name/$USERNAME/g" "$keep_path"/app.js
sed -i '' "90s/where/$snb/g" "$keep_path"/app.js
if [[ -z "$reym" ]] && [[ -f "$WORKDIR/reym.txt" ]]; then
reym=$(cat "$WORKDIR/reym.txt" 2>/dev/null)
elif [[ -z "$reym" ]] && [[ ! -f "$WORKDIR/reym.txt" ]]; then
reym=$USERNAME.serv00.net
echo "$reym" > $WORKDIR/reym.txt
else
echo "$reym" > $WORKDIR/reym.txt
reym=$(cat "$WORKDIR/reym.txt" 2>/dev/null)
fi

resallport(){
portlist=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')
if [[ -z "$portlist" ]]; then
yellow "No ports"
else
while read -r line; do
port=$(echo "$line" | awk '{print $1}')
port_type=$(echo "$line" | awk '{print $2}')
yellow "Deleting port $port ($port_type)"
devil port del "$port_type" "$port"
done <<< "$portlist"
fi
check_port
hyp=$(jq -r '.inbounds[0].listen_port' $WORKDIR/config.json)
vlp=$(jq -r '.inbounds[3].listen_port' $WORKDIR/config.json)
vmp=$(jq -r '.inbounds[4].listen_port' $WORKDIR/config.json)
sed -i '' "12s/$hyp/$hy2_port/g" $WORKDIR/config.json
sed -i '' "33s/$hyp/$hy2_port/g" $WORKDIR/config.json
sed -i '' "54s/$hyp/$hy2_port/g" $WORKDIR/config.json
sed -i '' "75s/$vlp/$vless_port/g" $WORKDIR/config.json
sed -i '' "102s/$vmp/$vmess_port/g" $WORKDIR/config.json
sed -i '' -e "17s|'$vlp'|'$vless_port'|" serv00keep.sh
sed -i '' -e "18s|'$vmp'|'$vmess_port'|" serv00keep.sh
sed -i '' -e "19s|'$hyp'|'$hy2_port'|" serv00keep.sh
ps aux | grep '[r]un -c con' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
sleep 1
curl -sk "http://${snb}.${USERNAME}.serv00.net/up" > /dev/null 2>&1
sleep 5
}

okip(){
    IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))
    API_URL="https://status.eooce.com/api"
    IP=""
    THIRD_IP=${IP_LIST[2]}
    RESPONSE=$(curl -s --max-time 2 "${API_URL}/${THIRD_IP}")
    if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
        IP=$THIRD_IP
    else
        FIRST_IP=${IP_LIST[0]}
        RESPONSE=$(curl -s --max-time 2 "${API_URL}/${FIRST_IP}")
        
        if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
            IP=$FIRST_IP
        else
            IP=${IP_LIST[1]}
        fi
    fi
    echo "$IP"
    }

check_port(){
port_list=$(devil port list)
tcp_ports=$(echo "$port_list" | grep -c "tcp")
udp_ports=$(echo "$port_list" | grep -c "udp")
if [[ $tcp_ports -ne 2 || $udp_ports -ne 1 ]]; then
    echo "Port count does not meet requirements, adjusting..."

    if [[ $tcp_ports -gt 2 ]]; then
        tcp_to_delete=$((tcp_ports - 2))
        echo "$port_list" | awk '/tcp/ {print $1, $2}' | head -n $tcp_to_delete | while read port type; do
            devil port del $type $port
            echo "TCP port deleted: $port"
        done
    fi

    if [[ $udp_ports -gt 1 ]]; then
        udp_to_delete=$((udp_ports - 1))
        echo "$port_list" | awk '/udp/ {print $1, $2}' | head -n $udp_to_delete | while read port type; do
            devil port del $type $port
            echo "UDP port deleted: $port"
        done
    fi

    if [[ $tcp_ports -lt 2 ]]; then
        tcp_ports_to_add=$((2 - tcp_ports))
        tcp_ports_added=0
        while [[ $tcp_ports_added -lt $tcp_ports_to_add ]]; do
            tcp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add tcp $tcp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                echo "TCP port added: $tcp_port"
                if [[ $tcp_ports_added -eq 0 ]]; then
                    tcp_port1=$tcp_port
                else
                    tcp_port2=$tcp_port
                fi
                tcp_ports_added=$((tcp_ports_added + 1))
            else
                echo "Port $tcp_port unavailable, trying other ports..."
            fi
        done
    fi

    if [[ $udp_ports -lt 1 ]]; then
        while true; do
            udp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add udp $udp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                echo "UDP port added: $udp_port"
                break
            else
                echo "Port $udp_port unavailable, trying other ports..."
            fi
        done
    fi
    sleep 3
    port_list=$(devil port list)
    tcp_ports=$(echo "$port_list" | grep -c "tcp")
    udp_ports=$(echo "$port_list" | grep -c "udp")
    tcp_ports=$(echo "$port_list" | awk '/tcp/ {print $1}')
    tcp_port1=$(echo "$tcp_ports" | sed -n '1p')
    tcp_port2=$(echo "$tcp_ports" | sed -n '2p')
    udp_port=$(echo "$port_list" | awk '/udp/ {print $1}')
    purple "Current TCP ports: $tcp_port1 and $tcp_port2"
    purple "Current UDP port: $udp_port"
else
    tcp_ports=$(echo "$port_list" | awk '/tcp/ {print $1}')
    tcp_port1=$(echo "$tcp_ports" | sed -n '1p')
    tcp_port2=$(echo "$tcp_ports" | sed -n '2p')
    udp_port=$(echo "$port_list" | awk '/udp/ {print $1}')
    echo "Your vless-reality TCP port: $tcp_port1" 
    echo "Your vmess TCP port (set Argo fixed domain port): $tcp_port2"
    echo "Your hysteria2 UDP port: $udp_port"
fi
export vless_port=$tcp_port1
export vmess_port=$tcp_port2
export hy2_port=$udp_port
}

get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN" > ARGO_DOMAIN.log
    echo "$ARGO_DOMAIN"
  else
    local retry=0
    local max_retries=6
    local argodomain=""
    while [[ $retry -lt $max_retries ]]; do
    ((retry++)) 
    argodomain=$(cat boot.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
      if [[ -n $argodomain ]]; then
        break
      fi
      sleep 2
    done  
    if [ -z ${argodomain} ]; then
    argodomain="Argo temporary domain temporarily unavailable, Argo nodes temporarily unavailable (will auto-recover during keep-alive), other nodes still available"
    fi
    echo "$argodomain"
  fi
}

if [ ! -f serv00keep.sh ]; then
curl -sSL https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00keep.sh -o serv00keep.sh && chmod +x serv00keep.sh
echo '#!/bin/bash
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
USERNAME=$(whoami | tr '\''[:upper:]'\'' '\''[:lower:]'\'')
WORKDIR="${HOME}/domains/${USERNAME}.serv00.net/logs"
snb=$(hostname | cut -d. -f1)
' > webport.sh
declare -f resallport >> webport.sh
declare -f check_port >> webport.sh
echo 'resallport' >> webport.sh
chmod +x webport.sh
green "Starting multi-function homepage installation, please wait..."
devil www del ${snb}.${USERNAME}.serv00.net > /dev/null 2>&1
devil www add ${USERNAME}.serv00.net php > /dev/null 2>&1
devil www add ${snb}.${USERNAME}.serv00.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
rm -rf $HOME/.npmrc > /dev/null 2>&1
cd "$keep_path"
npm install basic-auth express dotenv axios --silent > /dev/null 2>&1
rm $HOME/domains/${snb}.${USERNAME}.serv00.net/public_nodejs/public/index.html > /dev/null 2>&1
devil www restart ${snb}.${USERNAME}.serv00.net
green "Installation complete, multi-function homepage address: http://${snb}.${USERNAME}.serv00.net"
fi

if [[ "$resport" =~ ^[Yy]$ ]]; then
portlist=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')
if [[ -z "$portlist" ]]; then
yellow "No ports"
else
while read -r line; do
port=$(echo "$line" | awk '{print $1}')
port_type=$(echo "$line" | awk '{print $2}')
yellow "Deleting port $port ($port_type)"
devil port del "$port_type" "$port"
done <<< "$portlist"
fi
check_port
fi
rm -rf $HOME/domains/${snb}.${USERNAME}.serv00.net/logs/*

cd $WORKDIR
ym=("$HOSTNAME" "cache$nb.serv00.com" "web$nb.serv00.com")
rm -rf ip.txt
for host in "${ym[@]}"; do
response=$(curl -sL --connect-timeout 5 --max-time 7 "https://ss.fkj.pp.ua/api/getip?host=$host")
if [[ "$response" =~ (unknown|not|error) ]]; then
dig @8.8.8.8 +time=5 +short $host | sort -u >> ip.txt
sleep 1  
else
while IFS='|' read -r ip status; do
if [[ $status == "Accessible" ]]; then
echo "$ip: Available" >> ip.txt
else
echo "$ip: Blocked (Argo and CDN origin nodes, proxyip still valid)" >> ip.txt
fi	
done <<< "$response"
fi
done
if [[ ! "$response" =~ (unknown|not|error) ]]; then
grep ':' $WORKDIR/ip.txt | sort -u -o $WORKDIR/ip.txt
fi
if [[ -z "$IP" ]]; then
IP=$(grep -m 1 "Available" ip.txt | awk -F ':' '{print $1}')
if [ -z "$IP" ]; then
IP=$(okip)
if [ -z "$IP" ]; then
IP=$(head -n 1 ip.txt | awk -F ':' '{print $1}')
fi
fi
fi

if [[ -z "$vless_port" ]] || [[ -z "$vmess_port" ]] || [[ -z "$hy2_port" ]]; then
check_port
fi

if [ ! -s sb.txt ] && [ ! -s ag.txt ]; then
DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
FILE_INFO=("https://github.com/yonggekkk/Cloudflare_vless_trojan/releases/download/serv00/sb web" "https://github.com/yonggekkk/Cloudflare_vless_trojan/releases/download/serv00/server bot")
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

download_with_fallback() {
    local URL=$1
    local NEW_FILENAME=$2
    curl -L -sS --max-time 2 -o "$NEW_FILENAME" "$URL" &
    CURL_PID=$!
    CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    sleep 1
    CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
        kill $CURL_PID 2>/dev/null
        wait $CURL_PID 2>/dev/null
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $NEW_FILENAME by wget\e[0m"
    else
        wait $CURL_PID
        echo -e "\e[1;32mDownloading $NEW_FILENAME by curl\e[0m"
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    if [ -e "$NEW_FILENAME" ]; then
        echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
    else
        download_with_fallback "$URL" "$NEW_FILENAME"
    fi
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait
fi

if [ ! -e private_key.txt ]; then
output=$(./"$(basename ${FILE_MAP[web]})" generate reality-keypair)
private_key=$(echo "${output}" | awk '/PrivateKey:/ {print $2}')
public_key=$(echo "${output}" | awk '/PublicKey:/ {print $2}')
echo "${private_key}" > private_key.txt
echo "${public_key}" > public_key.txt
fi
private_key=$(<private_key.txt)
public_key=$(<public_key.txt)
openssl ecparam -genkey -name prime256v1 -out "private.key"
openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

if ! ps aux | grep '[r]un -c con' > /dev/null; then
ps aux | grep '[r]un -c con' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
if [ -e "$(basename "${FILE_MAP[web]}")" ]; then
   echo "$(basename "${FILE_MAP[web]}")" > sb.txt
   sbb=$(cat sb.txt)   
    nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
    sleep 5
if pgrep -x "$sbb" > /dev/null; then
    green "$sbb main process started"
else
    red "$sbb main process not started, restarting..."
    pkill -x "$sbb"
    nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
    sleep 2
    purple "$sbb main process restarted"
fi
else
    sbb=$(cat sb.txt)   
    nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
    sleep 5
if pgrep -x "$sbb" > /dev/null; then
    green "$sbb main process started"
else
    red "$sbb main process not started, restarting..."
    pkill -x "$sbb"
    nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
    sleep 2
    purple "$sbb main process restarted"
fi
fi
else
green "Main process already started"
fi

cfgo() {
rm -rf boot.log
if [ -e "$(basename "${FILE_MAP[bot]}")" ]; then
   echo "$(basename "${FILE_MAP[bot]}")" > ag.txt
   agg=$(cat ag.txt)
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --no-autoupdate run --token ${ARGO_AUTH}"
    else
     args="tunnel --url http://localhost:$vmess_port --no-autoupdate --logfile boot.log --loglevel info"
    fi
    nohup ./"$agg" $args >/dev/null 2>&1 &
    sleep 10
if pgrep -x "$agg" > /dev/null; then
    green "$agg Argo process started"
else
    red "$agg Argo process not started, restarting..."
    pkill -x "$agg"
    nohup ./"$agg" "${args}" >/dev/null 2>&1 &
    sleep 5
    purple "$agg Argo process restarted"
fi
else
   agg=$(cat ag.txt)
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --no-autoupdate run --token ${ARGO_AUTH}"
    else
     args="tunnel --url http://localhost:$vmess_port --no-autoupdate --logfile boot.log --loglevel info"
    fi
    pkill -x "$agg"
    nohup ./"$agg" $args >/dev/null 2>&1 &
    sleep 10
if pgrep -x "$agg" > /dev/null; then
    green "$agg Argo process started"
else
    red "$agg Argo process not started, restarting..."
    pkill -x "$agg"
    nohup ./"$agg" "${args}" >/dev/null 2>&1 &
    sleep 5
    purple "$agg Argo process restarted"
fi
fi
}

if [ -f "$WORKDIR/boot.log" ]; then
argosl=$(cat "$WORKDIR/boot.log" 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
checkhttp=$(curl -o /dev/null -s -w "%{http_code}\n" "https://$argosl")
fi
if ([ -z "$ARGO_DOMAIN" ] && ! ps aux | grep '[t]unnel --u' > /dev/null) || [[ "$checkhttp" != 404 ]]; then
ps aux | grep '[t]unnel --u' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
cfgo
elif [ -n "$ARGO_DOMAIN" ] && ! ps aux | grep '[t]unnel --n' > /dev/null; then
ps aux | grep '[t]unnel --n' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
cfgo
else
green "Argo process already started"
fi
sleep 2
if ! pgrep -x "$(cat sb.txt)" > /dev/null; then
red "Main process not started, troubleshoot according to the following situations"
yellow "1. REP select y to reset random ports once, leave three port parameters empty, then change to n (important)"
yellow "2. RES select y to run system reset once, then change to n (important)"
yellow "3. Current Serv00 server down? Try again later"
red "4. Tried all above, just wait for process keep-alive, check again later"
fi

argodomain=$(get_argodomain)
rm -rf ${FILE_PATH}/*.txt
echo -e "\e[1;32mArgo domain:\e[1;35m${argodomain}\e[0m\n"
a=$(dig @8.8.8.8 +time=5 +short "web$nb.serv00.com" | sort -u)
b=$(dig @8.8.8.8 +time=5 +short "$HOSTNAME" | sort -u)
c=$(dig @8.8.8.8 +time=5 +short "cache$nb.serv00.com" | sort -u)

vl_link="vless://$UUID@$IP:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome&pbk=$public_key&type=tcp&headerType=none#$snb-reality-$USERNAME"
echo "$vl_link" > jh.txt
vmws_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-$USERNAME\", \"add\": \"$IP\", \"port\": \"$vmess_port\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmws_link" >> jh.txt
vmatls_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-tls-argo-$USERNAME\", \"add\": \"www.visa.com.hk\", \"port\": \"8443\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link" >> jh.txt
vma_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME\", \"add\": \"www.visa.com.hk\", \"port\": \"8880\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link" >> jh.txt
hy2_link="hysteria2://$UUID@$IP:$hy2_port?security=tls&sni=www.bing.com&alpn=h3&insecure=1#$snb-hy2-$USERNAME"
echo "$hy2_link" >> jh.txt

v2sub=$(cat jh.txt)
echo "$v2sub" > ${FILE_PATH}/${UUID}_v2sub.txt
baseurl=$(base64 -w 0 < jh.txt)

V2rayN_LINK="https://${USERNAME}.serv00.net/${UUID}_v2sub.txt"
Clashmeta_LINK="https://${USERNAME}.serv00.net/${UUID}_clashmeta.txt"
Singbox_LINK="https://${USERNAME}.serv00.net/${UUID}_singbox.txt"

cat > list.txt <<EOF
=================================================================================================

Current IP used by client: $IP
If default node IP is blocked, you can switch to one of the following IPs in client
$a
$b
$c

Current ports used by each protocol:
vless-reality port: $vless_port
Vmess-ws port (set Argo fixed domain port): $vmess_port
Hysteria2 port: $hy2_port

UUID password: $UUID

Argo domain: ${argodomain}

-------------------------------------------------------------------------------------------------

1. Vless-reality share link:
$vl_link

2. Vmess-ws share link:
$vmws_link

3. Vmess-ws-tls_Argo share link:
$vmatls_link

4. Vmess-ws_Argo share link:
$vma_link

5. HY2 share link:
$hy2_link

-------------------------------------------------------------------------------------------------

Subscription share link:
$V2rayN_LINK

Copy share code:
$baseurl

-------------------------------------------------------------------------------------------------

Clash-meta subscription share link:
$Clashmeta_LINK

Sing-box subscription share link:
$Singbox_LINK

Multi-function homepage address: http://${snb}.${USERNAME}.serv00.net

=================================================================================================

EOF
cat list.txt
sleep 2
rm -rf sb.log core tunnel.yml tunnel.json
cd
