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
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
snb=$(hostname | cut -d. -f1)
nb=$(hostname | cut -d '.' -f 1 | tr -d 's')
HOSTNAME=$(hostname)
hona=$(hostname | cut -d. -f2)
if [ "$hona" = "serv00" ]; then
address="serv00.net"
keep_path="${HOME}/domains/${snb}.${USERNAME}.serv00.net/public_nodejs"
[ -d "$keep_path" ] || mkdir -p "$keep_path"
else
address="useruno.com"
fi
WORKDIR="${HOME}/domains/${USERNAME}.${address}/logs"
devil www add ${USERNAME}.${address} php > /dev/null 2>&1
FILE_PATH="${HOME}/domains/${USERNAME}.${address}/public_html"
[ -d "$FILE_PATH" ] || mkdir -p "$FILE_PATH"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")
devil binexec on >/dev/null 2>&1
curl -sk "http://${snb}.${USERNAME}.${hona}.net/up" > /dev/null 2>&1

read_ip() {
cat ip.txt
reading "Please enter one of the three IPs above (press Enter for default auto-select available IP): " IP
if [[ -z "$IP" ]]; then
IP=$(grep -m 1 "Available" ip.txt | awk -F ':' '{print $1}')
if [ -z "$IP" ]; then
IP=$(okip)
if [ -z "$IP" ]; then
IP=$(head -n 1 ip.txt | awk -F ':' '{print $1}')
fi
fi
fi
echo "$IP" > $WORKDIR/ipone.txt
IP=$(<$WORKDIR/ipone.txt)
green "Your selected IP: $IP"
}

read_uuid() {
reading "Please enter unified UUID password (press Enter for random): " UUID
if [[ -z "$UUID" ]]; then
UUID=$(uuidgen -r)
fi
echo "$UUID" > $WORKDIR/UUID.txt
UUID=$(<$WORKDIR/UUID.txt)
green "Your UUID: $UUID"
}

read_reym() {
yellow "Option 1: (Recommended) Use Serv00/Hostuno built-in domain, does not support proxyip: press Enter"
yellow "Option 2: Use CF domain (blog.cloudflare.com), supports proxyip + non-standard port reverse proxy: enter s"
yellow "Option 3: Supports other domains, note must comply with reality domain rules: enter domain"
reading "Please enter reality domain [Enter or s or enter domain]: " reym
if [[ -z "$reym" ]]; then
reym=$USERNAME.${address}
elif [[ "$reym" == "s" || "$reym" == "S" ]]; then
reym=blog.cloudflare.com
fi
echo "$reym" > $WORKDIR/reym.txt
reym=$(<$WORKDIR/reym.txt)
green "Your reality domain: $reym"
}

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
if [[ -e $WORKDIR/config.json ]]; then
hyp=$(jq -r '.inbounds[0].listen_port' $WORKDIR/config.json)
vlp=$(jq -r '.inbounds[3].listen_port' $WORKDIR/config.json)
vmp=$(jq -r '.inbounds[4].listen_port' $WORKDIR/config.json)
purple "Detected Serv00/Hostuno-sb-yg script already installed, executing port replacement, please wait..."
sed -i '' "12s/$hyp/$hy2_port/g" $WORKDIR/config.json
sed -i '' "33s/$hyp/$hy2_port/g" $WORKDIR/config.json
sed -i '' "54s/$hyp/$hy2_port/g" $WORKDIR/config.json
sed -i '' "75s/$vlp/$vless_port/g" $WORKDIR/config.json
sed -i '' "102s/$vmp/$vmess_port/g" $WORKDIR/config.json
if [ "$hona" = "serv00" ]; then
sed -i '' -e "17s|'$vlp'|'$vless_port'|" serv00keep.sh
sed -i '' -e "18s|'$vmp'|'$vmess_port'|" serv00keep.sh
sed -i '' -e "19s|'$hyp'|'$hy2_port'|" serv00keep.sh
fi
resservsb
green "Port replacement completed!"
ps aux | grep '[r]un -c con' > /dev/null && green "Main process started successfully, single-node users modify client three-protocol ports" || yellow "Sing-box main process startup failed"
if [ -f "$WORKDIR/boot.log" ]; then
ps aux | grep '[t]unnel --u' > /dev/null && green "Argo temporary tunnel started, temporary domain may have changed" || yellow "Argo temporary tunnel startup failed"
else
ps aux | grep '[t]unnel --n' > /dev/null && green "Argo fixed tunnel started" || yellow "Argo fixed tunnel startup failed, please change tunnel port in CF first: $vmess_port, then restart Argo tunnel"
fi
cd $WORKDIR
showchangelist
cd
fi
}

check_port () {
port_list=$(devil port list)
tcp_ports=$(echo "$port_list" | grep -c "tcp")
udp_ports=$(echo "$port_list" | grep -c "udp")
if [[ $tcp_ports -ne 2 || $udp_ports -ne 1 ]]; then
    red "Port count does not meet requirements, adjusting..."

    if [[ $tcp_ports -gt 2 ]]; then
        tcp_to_delete=$((tcp_ports - 2))
        echo "$port_list" | awk '/tcp/ {print $1, $2}' | head -n $tcp_to_delete | while read port type; do
            devil port del $type $port
            green "TCP port deleted: $port"
        done
    fi
    if [[ $udp_ports -gt 1 ]]; then
        udp_to_delete=$((udp_ports - 1))
        echo "$port_list" | awk '/udp/ {print $1, $2}' | head -n $udp_to_delete | while read port type; do
            devil port del $type $port
            green "UDP port deleted: $port"
        done
    fi
    if [[ $tcp_ports -lt 2 ]]; then
        tcp_ports_to_add=$((2 - tcp_ports))
        tcp_ports_added=0
        while [[ $tcp_ports_added -lt $tcp_ports_to_add ]]; do
            tcp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add tcp $tcp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                green "TCP port added: $tcp_port"
                if [[ $tcp_ports_added -eq 0 ]]; then
                    tcp_port1=$tcp_port
                else
                    tcp_port2=$tcp_port
                fi
                tcp_ports_added=$((tcp_ports_added + 1))
            else
                yellow "Port $tcp_port unavailable, trying other ports..."
            fi
        done
    fi
    if [[ $udp_ports -lt 1 ]]; then
        while true; do
            udp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add udp $udp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                green "UDP port added: $udp_port"
                break
            else
                yellow "Port $udp_port unavailable, trying other ports..."
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
    purple "Current TCP ports: $tcp_port1 and $tcp_port2"
    purple "Current UDP port: $udp_port"
fi
export vless_port=$tcp_port1
export vmess_port=$tcp_port2
export hy2_port=$udp_port
green "Your vless-reality port: $vless_port"
green "Your vmess-ws port (set Argo fixed domain port): $vmess_port"
green "Your hysteria2 port: $hy2_port"
}

install_singbox() {
if [[ -e $WORKDIR/list.txt ]]; then
yellow "Sing-box already installed, please select 2 to uninstall first, then install" && exit
fi
sleep 2
        cd $WORKDIR
	echo
	read_ip
  	echo
        read_reym
	echo
	read_uuid
        echo
        check_port
	echo
        sleep 2
        argo_configure
	echo
        download_and_run_singbox
	cd
        fastrun
	green "Shortcut created: sb"
	echo
        if [ "$hona" = "serv00" ]; then
	servkeep
        fi
        cd $WORKDIR
        echo
        get_links
	cd
        purple "************************************************************"
        purple "Serv00/Hostuno-sb-yg script installation completed"
	purple "Exit SSH"
	purple "Please reconnect SSH to view main menu, enter shortcut: sb"
	purple "************************************************************"
        sleep 2
        kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
}

uninstall_singbox() {
  reading "\nAre you sure you want to uninstall? [y/n]: " choice
    case "$choice" in
       [Yy])
	  bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
          rm -rf bin domains serv00keep.sh webport.sh
	  devil www list | awk 'NR > 1 && NF {print $1}' | xargs -I {} devil www del {} > /dev/null 2>&1
	  sed -i '' '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
          source ~/.bashrc
          purple "************************************************************"
          purple "Serv00/Hostuno-sb-yg uninstall completed!"
          purple "Welcome to continue using the script: bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00.sh)"
          purple "************************************************************"
          ;;
        [Nn]) exit 0 ;;
    	*) red "Invalid selection, please enter y or n" && menu ;;
    esac
}

kill_all_tasks() {
reading "\nWarning!!! This will clear all processes and all installation content, will exit SSH connection. Continue? [y/n]: " choice
  case "$choice" in
    [Yy]) 
    bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
    devil www list | awk 'NR > 1 && NF {print $1}' | xargs -I {} devil www del {} > /dev/null 2>&1
    sed -i '' '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
    source ~/.bashrc
    purple "************************************************************"
    purple "Serv00/Hostuno-sb-yg cleanup reset completed!"
    purple "Welcome to continue using the script: bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00.sh)"
    purple "************************************************************"
    find ~ -type f -exec chmod 644 {} \; 2>/dev/null
    find ~ -type d -exec chmod 755 {} \; 2>/dev/null
    find ~ -type f -exec rm -f {} \; 2>/dev/null
    find ~ -type d -empty -exec rmdir {} \; 2>/dev/null
    find ~ -exec rm -rf {} \; 2>/dev/null
    killall -9 -u $(whoami)
    ;;
    *) menu ;;
  esac
}

argo_configure() {
  while true; do
    yellow "Option 1: (Recommended) No domain needed Argo temporary tunnel: press Enter"
    yellow "Option 2: Domain required Argo fixed tunnel (need CF settings to extract Token): enter g"
    reading "[Please select g or Enter]: " argo_choice
    if [[ "$argo_choice" != "g" && "$argo_choice" != "G" && -n "$argo_choice" ]]; then
        red "Invalid selection, please enter g or Enter"
        continue
    fi
    if [[ "$argo_choice" == "g" || "$argo_choice" == "G" ]]; then
        reading "Please enter argo fixed tunnel domain: " ARGO_DOMAIN
	echo "$ARGO_DOMAIN" | tee ARGO_DOMAIN.log ARGO_DOMAIN_show.log > /dev/null
        green "Your argo fixed tunnel domain: $ARGO_DOMAIN"
        reading "Please enter argo fixed tunnel key (when pasting Token, must start with ey): " ARGO_AUTH
	echo "$ARGO_AUTH" | tee ARGO_AUTH.log ARGO_AUTH_show.log > /dev/null
        green "Your argo fixed tunnel key: $ARGO_AUTH"
	rm -rf boot.log
    else
        green "Using Argo temporary tunnel"
	rm -rf ARGO_AUTH.log ARGO_DOMAIN.log
    fi
    break
done
}

download_and_run_singbox() {
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
openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.${address}"
  cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
    "inbounds": [
    {
       "tag": "hysteria-in1",
       "type": "hysteria2",
       "listen": "$(dig @8.8.8.8 +time=5 +short "web$nb.${hona}.com" | sort -u)",
       "listen_port": $hy2_port,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://www.bing.com",
     "ignore_client_bandwidth":false,
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
        {
       "tag": "hysteria-in2",
       "type": "hysteria2",
       "listen": "$(dig @8.8.8.8 +time=5 +short "$HOSTNAME" | sort -u)",
       "listen_port": $hy2_port,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://www.bing.com",
     "ignore_client_bandwidth":false,
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
        {
       "tag": "hysteria-in3",
       "type": "hysteria2",
       "listen": "$(dig @8.8.8.8 +time=5 +short "cache$nb.${hona}.com" | sort -u)",
       "listen_port": $hy2_port,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://www.bing.com",
     "ignore_client_bandwidth":false,
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
    {
        "tag": "vless-reality-vesion",
        "type": "vless",
        "listen": "::",
        "listen_port": $vless_port,
        "users": [
            {
              "uuid": "$UUID",
              "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "$reym",
            "reality": {
                "enabled": true,
                "handshake": {
                    "server": "$reym",
                    "server_port": 443
                },
                "private_key": "$private_key",
                "short_id": [
                  ""
                ]
            }
        }
    },
{
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": $vmess_port,
      "users": [
      {
        "uuid": "$UUID"
      }
    ],
    "transport": {
      "type": "ws",
      "path": "$UUID-vm",
      "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
 ],
     "outbounds": [
     {
        "type": "wireguard",
        "tag": "wg",
        "server": "162.159.192.200",
        "server_port": 4500,
        "local_address": [
                "172.16.0.2/32",
                "2606:4700:110:8f77:1ca9:f086:846c:5f9e/128"
        ],
        "private_key": "wIxszdR2nMdA7a2Ul3XQcniSfSZqdqjPb6w6opvf5AU=",
        "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
        "reserved": [
            126,
            246,
            173
        ]
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
   "route": {
EOF
if [[ "$nb" =~ 14|15 ]]; then
cat >> config.json <<EOF 
    "rules": [
    {
     "domain": [
     "jnn-pa.googleapis.com"
      ],
     "outbound": "wg"
     }
    ],
    "final": "direct"
    }  
}
EOF
else
  cat >> config.json <<EOF
    "final": "direct"
    }  
}
EOF
fi

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
else
argogd=$(cat $WORKDIR/ARGO_DOMAIN.log 2>/dev/null)
checkhttp=$(curl --max-time 2 -o /dev/null -s -w "%{http_code}\n" "https://$argogd")
fi
if ([ -z "$ARGO_DOMAIN" ] && ! ps aux | grep '[t]unnel --u' > /dev/null) || [ "$checkhttp" -ne 404 ]; then
ps aux | grep '[t]unnel --u' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
cfgo
elif ([ -n "$ARGO_DOMAIN" ] && ! ps aux | grep '[t]unnel --n' > /dev/null) || [ "$checkhttp" -ne 404 ]; then
ps aux | grep '[t]unnel --n' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
cfgo
else
green "Argo process already started"
fi
sleep 2
if ! pgrep -x "$(cat sb.txt)" > /dev/null; then
red "Main process not started, troubleshoot according to the following situations"
yellow "1. Select 8 to reset ports, auto-generate random available ports (important)"
yellow "2. Select 9 to reset"
yellow "3. Current Serv00/Hostuno server down? Try again later"
red "4. Tried all above, just wait for process keep-alive, check again later"
sleep 6
fi
}

get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
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

get_links(){
argodomain=$(get_argodomain)
echo -e "\e[1;32mArgo domain:\e[1;35m${argodomain}\e[0m\n"
a=$(dig @8.8.8.8 +time=5 +short "web$nb.${hona}.com" | sort -u)
b=$(dig @8.8.8.8 +time=5 +short "$HOSTNAME" | sort -u)
c=$(dig @8.8.8.8 +time=5 +short "cache$nb.${hona}.com" | sort -u)
if [[ "$IP" == "$a" ]]; then
CIP1=$b; CIP2=$c
elif [[ "$IP" == "$b" ]]; then
CIP1=$a; CIP2=$c
elif [[ "$IP" == "$c" ]]; then
CIP1=$a; CIP2=$b
else
red "Execution error, please uninstall and reinstall the script"
fi
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
vl_link1="vless://$UUID@$CIP1:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome&pbk=$public_key&type=tcp&headerType=none#$snb-reality-$USERNAME-$CIP1"
echo "$vl_link1" >> jh.txt
vmws_link1="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-$USERNAME-$CIP1\", \"add\": \"$CIP1\", \"port\": \"$vmess_port\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmws_link1" >> jh.txt
hy2_link1="hysteria2://$UUID@$CIP1:$hy2_port?security=tls&sni=www.bing.com&alpn=h3&insecure=1#$snb-hy2-$USERNAME-$CIP1"
echo "$hy2_link1" >> jh.txt
vl_link2="vless://$UUID@$CIP2:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome&pbk=$public_key&type=tcp&headerType=none#$snb-reality-$USERNAME-$CIP2"
echo "$vl_link2" >> jh.txt
vmws_link2="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-$USERNAME-$CIP2\", \"add\": \"$CIP2\", \"port\": \"$vmess_port\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmws_link2" >> jh.txt
hy2_link2="hysteria2://$UUID@$CIP2:$hy2_port?security=tls&sni=www.bing.com&alpn=h3&insecure=1#$snb-hy2-$USERNAME-$CIP2"
echo "$hy2_link2" >> jh.txt

argosl=$(cat "$WORKDIR/boot.log" 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
checkhttp1=$(curl -o /dev/null -s -w "%{http_code}\n" "https://$argosl")
argogd=$(cat $WORKDIR/ARGO_DOMAIN.log 2>/dev/null)
checkhttp2=$(curl --max-time 2 -o /dev/null -s -w "%{http_code}\n" "https://$argogd")
if [[ "$checkhttp1" == 404 ]] || [[ "$checkhttp2" == 404 ]]; then
vmatls_link1="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-tls-argo-$USERNAME-443\", \"add\": \"104.16.0.0\", \"port\": \"443\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link1" >> jh.txt
vmatls_link2="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-tls-argo-$USERNAME-2053\", \"add\": \"104.17.0.0\", \"port\": \"2053\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link2" >> jh.txt
vmatls_link3="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-tls-argo-$USERNAME-2083\", \"add\": \"104.18.0.0\", \"port\": \"2083\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link3" >> jh.txt
vmatls_link4="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-tls-argo-$USERNAME-2087\", \"add\": \"104.19.0.0\", \"port\": \"2087\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link4" >> jh.txt
vmatls_link5="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-tls-argo-$USERNAME-2096\", \"add\": \"104.20.0.0\", \"port\": \"2096\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)"
echo "$vmatls_link5" >> jh.txt
vma_link6="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME-80\", \"add\": \"104.21.0.0\", \"port\": \"80\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link6" >> jh.txt
vma_link7="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME-8080\", \"add\": \"104.22.0.0\", \"port\": \"8080\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link7" >> jh.txt
vma_link8="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME-2052\", \"add\": \"104.24.0.0\", \"port\": \"2052\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link8" >> jh.txt
vma_link9="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME-2082\", \"add\": \"104.25.0.0\", \"port\": \"2082\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link9" >> jh.txt
vma_link10="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME-2086\", \"add\": \"104.26.0.0\", \"port\": \"2086\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link10" >> jh.txt
vma_link11="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$snb-vmess-ws-argo-$USERNAME-2095\", \"add\": \"104.27.0.0\", \"port\": \"2095\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$UUID-vm?ed=2048\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link11" >> jh.txt
fi
v2sub=$(cat jh.txt)
echo "$v2sub" > ${FILE_PATH}/${UUID}_v2sub.txt
baseurl=$(base64 -w 0 < jh.txt)

cat > list.txt <<EOF
=================================================================================================

Current IP used by client: $IP
If default node IP is blocked, you can switch to one of the following IPs in client
$a
$b
$c

Current ports used by each protocol:
vless-reality port: $vlp
Vmess-ws port (set Argo fixed domain port): $vmp
Hysteria2 port: $hyp

UUID password: $showuuid

Argo domain: ${argodomain}
-------------------------------------------------------------------------------------------------

1. Vless-reality share link:
$vl_link

Note: If you entered CF domain as reality domain earlier, the following features will be activated:
Can be applied in https://github.com/anyagixx/proxme3 project to create CF vless/trojan nodes
1. Proxyip (with port) info:
Method 1 global application: set variable name: proxyip    set variable value: $IP:$vless_port  
Method 2 single node application: change path to: /pyip=$IP:$vless_port
CF node TLS can be on or off
CF node lands to CF website region: $IP region

2. Non-standard port reverse proxy IP info:
Client optimized IP address: $IP, port: $vless_port
CF node TLS must be on
CF node lands to non-CF website region: $IP region

Note: If Serv00/Hostuno IP is blocked, proxyip still works, but non-standard port reverse proxy IP for client address will be unavailable
Note: Some experts may scan Serv00/Hostuno reverse proxy IPs for shared IP libraries or sale, please be cautious when setting reality domain to CF domain
-------------------------------------------------------------------------------------------------


2. Vmess-ws share links in three forms:

1. Vmess-ws main node share link:
(This node does not support CDN by default, if set to CDN origin (needs domain): client address can modify optimized IP/domain, 7 port-80 ports can be changed, still works if blocked!)
$vmws_link

2. Vmess-ws-tls_Argo share link: 
(This node is CDN optimized IP node, client address can modify optimized IP/domain, 6 port-443 ports can be changed, still works if blocked!)
$vmatls_link

3. Vmess-ws_Argo share link:
(This node is CDN optimized IP node, client address can modify optimized IP/domain, 7 port-80 ports can be changed, still works if blocked!)
$vma_link
-------------------------------------------------------------------------------------------------


3. HY2 share link:
$hy2_link
-------------------------------------------------------------------------------------------------


4. Aggregated universal nodes, total 22 nodes:
3 IPs full coverage: 3 reality, 3 vmess+ws, 3 hy2
13 argo nodes full coverage (CF immortal IPs added): 7 non-TLS port-80 nodes, 6 TLS port-443 nodes

Subscription share link:
$V2rayN_LINK

Copy share code:
$baseurl
-------------------------------------------------------------------------------------------------


5. View Sing-box and Clash-meta subscription config files, please enter main menu select 4

Clash-meta subscription share link:
$Clashmeta_LINK

Sing-box subscription share link:
$Singbox_LINK
-------------------------------------------------------------------------------------------------

================================================================================================

EOF
cat list.txt
sleep 2
rm -rf sb.log core tunnel.yml tunnel.json fake_useragent_0.2.0.json
}

showlist(){
if [[ -e $WORKDIR/list.txt ]]; then
green "Viewing node, subscription, reverse proxy IP, ProxyIP info! Updating, please wait..."
sleep 3
cat $WORKDIR/list.txt
else
red "Script not installed, please select 1 to install" && exit
fi
}

showsbclash(){
if [[ -e $WORKDIR/sing_box.json ]]; then
green "Viewing clash and singbox config in plain text! Updating, please wait..."
sleep 3
green "Sing_box config file below, can upload to subscription clients:"
yellow "Argo nodes are CDN optimized IP nodes, server address can be modified for optimized IP/domain, still works if blocked!"
sleep 2
cat $WORKDIR/sing_box.json 
echo
echo
green "Clash_meta config file below, can upload to subscription clients:"
yellow "Argo nodes are CDN optimized IP nodes, server address can be modified for optimized IP/domain, still works if blocked!"
sleep 2
cat $WORKDIR/clash_meta.yaml
echo
else
red "Script not installed, please select 1 to install" && exit
fi
}

servkeep() {
sed -i '' -e "14s|''|'$UUID'|" serv00keep.sh
sed -i '' -e "17s|''|'$vless_port'|" serv00keep.sh
sed -i '' -e "18s|''|'$vmess_port'|" serv00keep.sh
sed -i '' -e "19s|''|'$hy2_port'|" serv00keep.sh
sed -i '' -e "20s|''|'$IP'|" serv00keep.sh
sed -i '' -e "21s|''|'$reym'|" serv00keep.sh
if [ ! -f "$WORKDIR/boot.log" ]; then
sed -i '' -e "15s|''|'${ARGO_DOMAIN}'|" serv00keep.sh
sed -i '' -e "16s|''|'${ARGO_AUTH}'|" serv00keep.sh
fi
echo '#!/bin/bash
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
USERNAME=$(whoami | tr '\''[:upper:]'\'' '\''[:lower:]'\'')
WORKDIR="${HOME}/domains/${USERNAME}.serv00.net/logs"
snb=$(hostname | cut -d. -f1)
hona=$(hostname | cut -d. -f2)
' > webport.sh
declare -f resallport >> webport.sh
declare -f check_port >> webport.sh
declare -f resservsb >> webport.sh
echo 'resallport' >> webport.sh
chmod +x webport.sh
green "Starting multi-function homepage installation, please wait..."
devil www del ${snb}.${USERNAME}.${hona}.net > /dev/null 2>&1
devil www add ${USERNAME}.${hona}.net php > /dev/null 2>&1
devil www add ${snb}.${USERNAME}.${hona}.net nodejs /usr/local/bin/node18 > /dev/null 2>&1
ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
rm -rf $HOME/.npmrc > /dev/null 2>&1
cd "$keep_path"
npm install basic-auth express dotenv axios --silent > /dev/null 2>&1
rm $HOME/domains/${snb}.${USERNAME}.${hona}.net/public_nodejs/public/index.html > /dev/null 2>&1
devil www restart ${snb}.${USERNAME}.${hona}.net
curl -sk "http://${snb}.${USERNAME}.${hona}.net/up" > /dev/null 2>&1
green "Installation complete, multi-function homepage address: http://${snb}.${USERNAME}.${hona}.net" && sleep 2
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

fastrun(){
if [[ -e $WORKDIR/config.json ]]; then
  COMMAND="sb"
  SCRIPT_PATH="$HOME/bin/$COMMAND"
  mkdir -p "$HOME/bin"
  curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00.sh > "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    grep -qxF 'source ~/.bashrc' ~/.bash_profile 2>/dev/null || echo 'source ~/.bashrc' >> ~/.bash_profile
    source ~/.bashrc
fi
if [ "$hona" = "serv00" ]; then
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/app.js -o "$keep_path"/app.js
sed -i '' "15s/name/$snb/g" "$keep_path"/app.js
sed -i '' "59s/key/$UUID/g" "$keep_path"/app.js
sed -i '' "90s/name/$USERNAME/g" "$keep_path"/app.js
sed -i '' "90s/where/$snb/g" "$keep_path"/app.js
curl -sSL https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00keep.sh -o serv00keep.sh && chmod +x serv00keep.sh
fi
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/index.html -o "$FILE_PATH"/index.html
curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/sversion | awk -F "Update content" '{print $1}' | head -n 1 > $WORKDIR/v
else
red "Script not installed, please select 1 to install" && exit
fi
}

resservsb(){
if [[ -e $WORKDIR/config.json ]]; then
yellow "Restarting... please wait..."
cd $WORKDIR
ps aux | grep '[r]un -c con' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
if [ "$hona" = "serv00" ]; then
curl -sk "http://${snb}.${USERNAME}.${hona}.net/up" > /dev/null 2>&1
sleep 5
else
sbb=$(cat sb.txt)
nohup ./"$sbb" run -c config.json >/dev/null 2>&1 &
sleep 1
fi
if pgrep -x "$sbb" > /dev/null; then
green "$sbb main process restarted successfully"
else
red "$sbb main process restart failed"
fi
cd
else
red "Script not installed, please select 1 to install" && exit
fi
}

resargo(){
if [[ -e $WORKDIR/config.json ]]; then
cd $WORKDIR
argoport=$(jq -r '.inbounds[4].listen_port' config.json)
yellow "You can reset temporary tunnel; continue using previous fixed tunnel; or change fixed tunnel domain or token"
argogdshow(){
echo
if [ -f ARGO_AUTH_show.log ]; then
purple "Previous Argo fixed domain: $(cat ARGO_DOMAIN_show.log 2>/dev/null)"
purple "Previous fixed tunnel Token: $(cat ARGO_AUTH_show.log 2>/dev/null)"
purple "Currently checking CF website Argo fixed tunnel port: $argoport"
fi
echo
}
if [ -f boot.log ]; then
green "Currently using Argo temporary tunnel"
argogdshow
else
green "Currently using Argo fixed tunnel"
argogdshow
fi
argo_configure
ps aux | grep '[t]unnel --u' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
ps aux | grep '[t]unnel --n' | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
agg=$(cat ag.txt)
if [[ "$argo_choice" =~ (G|g) ]]; then
if [ "$hona" = "serv00" ]; then
sed -i '' -e "15s|''|'$(cat ARGO_DOMAIN_show.log 2>/dev/null)'|" ~/serv00keep.sh
sed -i '' -e "16s|''|'$(cat ARGO_AUTH_show.log 2>/dev/null)'|" ~/serv00keep.sh
fi
args="tunnel --no-autoupdate run --token $(cat ARGO_AUTH_show.log)"
else
rm -rf boot.log
if [ "$hona" = "serv00" ]; then
sed -i '' -e "15s|'$(cat ARGO_DOMAIN_show.log 2>/dev/null)'|''|" ~/serv00keep.sh
sed -i '' -e "16s|'$(cat ARGO_AUTH_show.log 2>/dev/null)'|''|" ~/serv00keep.sh
fi
args="tunnel --url http://localhost:$argoport --no-autoupdate --logfile boot.log --loglevel info"
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
showchangelist
cd
else
red "Script not installed, please select 1 to install" && exit
fi
}

showchangelist(){
IP=$(<$WORKDIR/ipone.txt)
UUID=$(<$WORKDIR/UUID.txt)
reym=$(<$WORKDIR/reym.txt)
ARGO_DOMAIN=$(cat "$WORKDIR/ARGO_DOMAIN.log" 2>/dev/null)
ARGO_AUTH=$(cat "$WORKDIR/ARGO_AUTH.log" 2>/dev/null)
check_port >/dev/null 2>&1
download_and_run_singbox >/dev/null 2>&1
get_links
}

menu() {
   clear
   echo "============================================================"
green "GitHub Project: github.com/anyagixx/proxme3"
green "Original Author Blog: ygkkk.blogspot.com"
green "Original Author YouTube: www.youtube.com/@ygkkk"
   green "Serv00/Hostuno Three-Protocol Coexistence Script: vless-reality/Vmess-ws(Argo)/Hy2"
   green "Script shortcut: sb"
   echo   "============================================================"
   green  "1. One-click install Serv00/Hostuno-sb-yg"
   echo   "------------------------------------------------------------"
   yellow "2. Uninstall Serv00/Hostuno-sb-yg"
   echo   "------------------------------------------------------------"
   green  "3. Restart main process (fix main nodes)"
   echo   "------------------------------------------------------------"
   green  "4. Argo reset (switch between temporary and fixed tunnel, change fixed domain)"
   echo   "------------------------------------------------------------"
   green  "5. Update script"
   echo   "------------------------------------------------------------"
   green  "6. View node shares/sing-box and clash subscription links/reverse proxy IP/ProxyIP"
   echo   "------------------------------------------------------------"
   green  "7. View sing-box and clash config files"
   echo   "------------------------------------------------------------"
   yellow "8. Port reset and randomly generate new ports"
   echo   "------------------------------------------------------------"
   red    "9. Clear all service processes and files (system initialization)"
   echo   "------------------------------------------------------------"
   red    "0. Exit script"
   echo   "============================================================"
ym=("$HOSTNAME" "cache$nb.${hona}.com" "web$nb.${hona}.com")
rm -rf $WORKDIR/ip.txt
for host in "${ym[@]}"; do
response=$(curl -sL --connect-timeout 5 --max-time 7 "https://ss.fkj.pp.ua/api/getip?host=$host")
if [[ "$response" =~ (unknown|not|error) ]]; then
dig @8.8.8.8 +time=5 +short $host | sort -u >> $WORKDIR/ip.txt
sleep 1  
else
while IFS='|' read -r ip status; do
if [[ $status == "Accessible" ]]; then
echo "$ip: Available" >> $WORKDIR/ip.txt
else
echo "$ip: Blocked (Argo and CDN origin nodes, proxyip still valid)" >> $WORKDIR/ip.txt
fi	
done <<< "$response"
fi
done
if [[ ! "$response" =~ (unknown|not|error) ]]; then
grep ':' $WORKDIR/ip.txt | sort -u -o $WORKDIR/ip.txt
fi
if [ "$hona" = "serv00" ]; then
red "Currently free Serv00 using proxy scripts may risk account ban, please be aware!!!"
fi
green "${hona} server name: ${snb}"
echo
green "Current available IPs:"
cat $WORKDIR/ip.txt
echo
portlist=$(devil port list | grep -E '^[0-9]+[[:space:]]+[a-zA-Z]+' | sed 's/^[[:space:]]*//')
if [[ -n $portlist ]]; then
green "Current ports set:"
echo -e "$portlist"
else
yellow "No ports set"
fi
echo
insV=$(cat $WORKDIR/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/sversion | awk -F "Update content" '{print $1}' | head -n 1)
if [ -f $WORKDIR/v ]; then
if [ "$insV" = "$latestV" ]; then
echo -e "Current Serv00/Hostuno-sb-yg script latest version: ${purple}${insV}${re} (installed)"
else
echo -e "Current Serv00/Hostuno-sb-yg script version: ${purple}${insV}${re}"
echo -e "Detected latest Serv00/Hostuno-sb-yg script version: ${yellow}${latestV}${re} (select 5 to update)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/anyagixx/proxme3/main/sversion)${re}"
fi
echo -e "========================================================="
sbb=$(cat $WORKDIR/sb.txt 2>/dev/null)
if pgrep -x "$sbb" > /dev/null; then
green "Sing-box main process running normally"
else
yellow "Sing-box main process startup failed, suggest select 3 to restart first, if still failed select 8 to reset ports, then select 9 to uninstall and reinstall"
fi
if [ -f "$WORKDIR/boot.log" ]; then
argosl=$(cat "$WORKDIR/boot.log" 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
checkhttp=$(curl -o /dev/null -s -w "%{http_code}\n" "https://$argosl")
[[ "$checkhttp" == 404 ]] && check="Domain valid" || check="Temporary domain temporarily invalid, if keep-alive enabled, will auto-recover later"
green "Argo temporary domain: $argosl  $check"
else
argogd=$(cat $WORKDIR/ARGO_DOMAIN.log 2>/dev/null)
checkhttp=$(curl --max-time 2 -o /dev/null -s -w "%{http_code}\n" "https://$argogd")
if [[ "$checkhttp" == 404 ]]; then
check="Domain valid"
elif [[ "$argogd" =~ ddns|cloudns|dynamic|cloud-ip ]]; then
check="Domain may be valid, please check if argo nodes are available yourself"
else
check="Fixed domain invalid, please check if domain, port, token are entered correctly"
fi
green "Argo fixed domain: $argogd $check"
fi
if [ "$hona" = "serv00" ]; then
green "Multi-function homepage (supports keep-alive, restart, reset ports, view processes, query nodes)"
purple "http://${snb}.${USERNAME}.${hona}.net"
fi
else
echo -e "Current Serv00/Hostuno-sb-yg script version: ${purple}${latestV}${re}"
yellow "Serv00/Hostuno-sb-yg script not installed! Please select 1 to install"
fi
   echo -e "========================================================="
   reading "Please enter selection [0-9]: " choice
   echo
    case "${choice}" in
        1) install_singbox ;;
        2) uninstall_singbox ;; 
	3) resservsb ;;
        4) resargo ;;
	5) fastrun && green "Script updated successfully" && sleep 2 && sb ;; 
        6) showlist ;;
	7) showsbclash ;;
        8) resallport ;;
        9) kill_all_tasks ;;
	0) exit 0 ;;
        *) red "Invalid option, please enter 0 to 9" ;;
    esac
}
menu
