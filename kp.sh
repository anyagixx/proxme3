#!/bin/bash
# Schedule setting: */10 * * * * /bin/bash /root/kp.sh Run every 10 minutes
# If you have already installed the Serv00 local SSH script, do not run this script for deployment anymore, as it will cause process overflow. You must choose one or the other!
# serv00 variable addition rules:
# If using keep-alive web page, please do not enable cron, to prevent cron and web keep-alive from running repeatedly and causing process overflow
# RES (required): n means do not reset deployment each time, y means reset deployment each time. REP (required): n means do not reset random ports (leave three ports empty), y means reset ports (leave three ports empty). SSH_USER (required) is the serv00 account name. SSH_PASS (required) is the serv00 password. REALITY is the reality domain (leave empty for serv00 official domain: your-serv00-account-name.serv00.net). SUUID is the uuid (leave empty for random uuid). TCP1_PORT is the vless tcp port (leave empty for random tcp port). TCP2_PORT is the vmess tcp port (leave empty for random tcp port). UDP_PORT is the hy2 udp port (leave empty for random udp port). HOST (required) is the login serv00 server domain. ARGO_DOMAIN is the argo fixed domain (leave empty for temporary domain). ARGO_AUTH is the argo fixed domain token (leave empty for temporary domain).
# Required variables: RES, REP, SSH_USER, SSH_PASS, HOST
# Note: Do not delete symbols like []"",: randomly, align according to the pattern
# Each line represents one {serv00 server}, one service is also fine, separate with comma at the end, the last server does not need comma at the end
ACCOUNTS='[
{"RES":"n", "REP":"n", "SSH_USER":"your-serv00-account-name", "SSH_PASS":"your-serv00-account-password", "REALITY":"your-serv00-account-name.serv00.net", "SUUID":"custom-UUID", "TCP1_PORT":"vless-tcp-port", "TCP2_PORT":"vmess-tcp-port", "UDP_PORT":"hy2-udp-port", "HOST":"s1.serv00.com", "ARGO_DOMAIN":"", "ARGO_AUTH":""},
{"RES":"y", "REP":"y", "SSH_USER":"123456", "SSH_PASS":"7890000", "REALITY":"time.is", "SUUID":"73203ee6-b3fa-4a3d-b5df-6bb2f55073ad", "TCP1_PORT":"", "TCP2_PORT":"", "UDP_PORT":"", "HOST":"s16.serv00.com", "ARGO_DOMAIN":"your-argo-fixed-domain", "ARGO_AUTH":"eyJhIjoiOTM3YzFjYWI88552NTFiYTM4ZTY0ZDQzRmlNelF0TkRBd1pUQTRNVEJqTUdVeCJ9"}
]'
run_remote_command() {
local RES=$1
local REP=$2
local SSH_USER=$3
local SSH_PASS=$4
local REALITY=${5}
local SUUID=$6
local TCP1_PORT=$7
local TCP2_PORT=$8
local UDP_PORT=$9
local HOST=${10}
local ARGO_DOMAIN=${11}
local ARGO_AUTH=${12}
  if [ -z "${ARGO_DOMAIN}" ]; then
    echo "Argo domain is empty, applying for Argo temporary domain"
  else
    echo "Argo has set fixed domain: ${ARGO_DOMAIN}"
  fi
  remote_command="export reym=$REALITY UUID=$SUUID vless_port=$TCP1_PORT vmess_port=$TCP2_PORT hy2_port=$UDP_PORT reset=$RES resport=$REP ARGO_DOMAIN=${ARGO_DOMAIN} ARGO_AUTH=${ARGO_AUTH} && bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxme3/main/serv00keep.sh)"
  echo "Executing remote command on $HOST as $SSH_USER with command: $remote_command"
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$remote_command"
}
if  cat /etc/issue /proc/version /etc/os-release 2>/dev/null | grep -q -E -i "openwrt"; then
opkg update
opkg install sshpass curl jq
else
    if [ -f /etc/debian_version ]; then
        package_manager="apt-get install -y"
        apt-get update >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        package_manager="yum install -y"
    elif [ -f /etc/fedora-release ]; then
        package_manager="dnf install -y"
    elif [ -f /etc/alpine-release ]; then
        package_manager="apk add"
    fi
    $package_manager sshpass curl jq cron >/dev/null 2>&1 &
fi
echo "*****************************************************"
echo "*****************************************************"
echo "GitHub Project: github.com/anyagixx/proxme3"
echo "Original Author Blog: ygkkk.blogspot.com"
echo "Original Author YouTube: www.youtube.com/@ygkkk"
echo "Auto Remote Deploy Serv00 Three-in-One Protocol Script [VPS+Router]"
echo "Version: V25.3.26"
echo "*****************************************************"
echo "*****************************************************"
              count=0  
           for account in $(echo "${ACCOUNTS}" | jq -c '.[]'); do
              count=$((count+1))
              RES=$(echo $account | jq -r '.RES')
              REP=$(echo $account | jq -r '.REP')              
              SSH_USER=$(echo $account | jq -r '.SSH_USER')
              SSH_PASS=$(echo $account | jq -r '.SSH_PASS')
              REALITY=$(echo $account | jq -r '.REALITY')
              SUUID=$(echo $account | jq -r '.SUUID')
              TCP1_PORT=$(echo $account | jq -r '.TCP1_PORT')
              TCP2_PORT=$(echo $account | jq -r '.TCP2_PORT')
              UDP_PORT=$(echo $account | jq -r '.UDP_PORT')
              HOST=$(echo $account | jq -r '.HOST')
              ARGO_DOMAIN=$(echo $account | jq -r '.ARGO_DOMAIN')
              ARGO_AUTH=$(echo $account | jq -r '.ARGO_AUTH') 
          if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" -q exit; then
            echo "Congratulations! Server #[$count] connected successfully! Server address: $HOST, Account name: $SSH_USER"   
          if [ -z "${ARGO_DOMAIN}" ]; then
           check_process="ps aux | grep '[c]onfig' > /dev/null && ps aux | grep [l]ocalhost:$TCP2_PORT > /dev/null"
            else
           check_process="ps aux | grep '[c]onfig' > /dev/null && ps aux | grep '[t]oken $ARGO_AUTH' > /dev/null"
           fi
          if ! sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$check_process" || [[ "$RES" =~ ^[Yy]$ ]]; then
            echo "Warning: Detected main process or argo process not started, or executing reset"
             echo "Warning: Starting repair or reset deployment... please wait"
             output=$(run_remote_command "$RES" "$REP" "$SSH_USER" "$SSH_PASS" "${REALITY}" "$SUUID" "$TCP1_PORT" "$TCP2_PORT" "$UDP_PORT" "$HOST" "${ARGO_DOMAIN}" "${ARGO_AUTH}")
            echo "Remote command execution result: $output"
          else
            echo "Congratulations! Detected all processes running normally"
            SSH_USER_LOWER=$(echo "$SSH_USER" | tr '[:upper:]' '[:lower:]')
            sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "
            echo \"Configuration display as follows:\"
            cat domains/${SSH_USER_LOWER}.serv00.net/logs/list.txt
            echo \"====================================================\""
            fi
           else
            echo "===================================================="
            echo "Unfortunate! Server #[$count] connection failed! Server address: $HOST, Account name: $SSH_USER"
            echo "Warning: Possible incorrect account name, password, server name, or current server is under maintenance"  
            echo "===================================================="
           fi
            done
