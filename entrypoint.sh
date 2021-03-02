#!/bin/bash

stream_servers=("twitch" "youtube" "facebook")
if [ -z "$stream_key" ]; then
    stream_key=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c${1:-32})
    echo "Stream key is\t $stream_key"
fi

rtmp_port=${rtmp_port-1935}

for stream_server in "${stream_servers[@]}"; do
    if [ ! -z "${!stream_server}" ]; then
        echo $stream_server stream key detected ${!stream_server}
    fi
done

if ["$port" =~ $port_regex]; then
    if (lsof -i :$port | grep TCP); then
        echo "$cl_red Port already usage. Please select another port.$cl_nc"
        exit 1
    else
        echo "Selected port $port/tcp"
        break
    fi
else
    echo "$cl_red Port is must be between 0-65535$cl_nc"
    exit 1
fi

if [ ! -z "$clien_addr" ]; then
    if [[ "$clien_addr" =~ $ip_regex ]] || [[ "$clien_addr" =~ $ip6_regex ]]; then
        echo "Client addr is setted to \"$clien_addr\"\n other requests will be deny"
        config_nginx_client_addr="
        allow publish $clien_addr;
        deny publish all;
    "
    else
        echo "$cl_red Client addr must be IPv4 or IPv6 address \"$client_addr\"$cl_nc"
        exit 1
    fi
fi

####
#   Static variables
####

# Regexes
port_regex="^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([1-9][0-9]{3})|([1-9][0-9]{2})|([1-9][0-9])|([1-9]))$"
ip_regex="^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){3})(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\/([0-9]$|[1-2][0-9]$|3[0-2])|$)"
ip6_regex="^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(/[1-9][0-9])?$"

# Colors
cl_red='\033[0;31m'
cl_nc='\033[0m'
