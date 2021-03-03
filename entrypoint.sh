#!/usr/bin/env bash

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
cl_cy='\e[36m'
cl_wh='\e[97m'
cl_lm='\e[95m'
cl_lg='\e[92m'

stream_servers=("twitch" "youtube")
if [ -z "$stream_key" ]; then
    stream_key=$(tr </dev/urandom -dc A-Za-z0-9 | head -c${1:-32})
    echo -e "\t${cl_cy}Multiplexer${cl_nc} stream key is:\t${cl_lg}${stream_key}${cl_nc}"
else
    echo -e "\t${cl_cy}Multiplexer${cl_nc} stream key specified by user:\t${cl_lg}${stream_key:0:4}...${stream_key:$((${#stream_key}-4))}${cl_nc}"
fi

rtmp_port=${rtmp_port-1935}
stream_count=0
for stream_server in "${stream_servers[@]}"; do
    if [ ! -z "${!stream_server}" ]; then
        remote_stream_key=${!stream_server}
        echo -e "\t${cl_cy}${stream_server}${cl_nc} stream key detected:\t${cl_lm}${remote_stream_key:0:4}...${remote_stream_key:$((${#remote_stream_key}-4))}${cl_nc}"
        stream_count=$((stream_count + 1))
    fi
done

unset remote_stream_key

if [ $stream_count -lt 1 ]; then
    echo -e "\t${cl_red}No stream key is defined.${cl_nc}"
    exit 1
fi

if [[ "$rtmp_port" =~ $port_regex ]]; then
    if (lsof -i :$rtmp_port | grep TCP); then
        echo -e "${cl_red}Port already usage. Please select another port.${cl_nc}"
        exit 1
    else
        echo -e "\tSelected port is $rtmp_port/tcp"
    fi
else
    echo -e "${cl_red}Port is must be between 0-65535${cl_nc}"
    exit 1
fi

if [ ! -z "$client_addr" ]; then
    if [[ "$client_addr" =~ $ip_regex ]] || [[ "$client_addr" =~ $ip6_regex ]]; then
        echo "Client addr is setted to \"$client_addr\"\n other requests will be deny"
        config_nginx_client_addr="
        allow publish $client_addr;
        deny publish all;
    "
    else
        echo -e "${cl_red}Client addr must be IPv4 or IPv6 address \"$client_addr\"${cl_nc}"
        exit 1
    fi
fi

### Nginx authorization server

echo "
 server {
        listen 127.0.0.1:80 default_server;
        #listen [::]:80 default_server;
        # Everything is a 404
        location / {
                return 404;
        }
        # You may need this to prevent return 404 recursion.
        location = /404.html {
                internal;
        }
        location /auth {
            if (\$arg_name = '$stream_key') {
                return 200;
            }
            return 401;
        }
}
" >/etc/nginx/conf.d/default.conf

### Begin of the rtmp configuration
echo "
rtmp {
        server {
                listen $rtmp_port;
                chunk_size 4096;
                notify_method get;

                application live {
                             # Auth
                             on_publish http://127.0.0.1/auth;
                             live on;
                             " >/etc/nginx/rtmp.conf

# Stream save location check, if it is avaible, set to nginx

# if [ -d "/record/" ]; then
#     echo "Save location found, your streams will be saved."
#     echo "
#                              record all;
#                              record_path /record/;
#                              record_unique on;" >>/etc/nginx/rtmp.conf
# fi

for stream_server in "${stream_servers[@]}"; do
    if [ ! -z "${!stream_server}" ]; then
        echo "                             push rtmp://127.0.0.1:$rtmp_port/${stream_server};" >>/etc/nginx/rtmp.conf
    fi
done

# End of the application live { section
echo "                }" >>/etc/nginx/rtmp.conf

# Twitch configuration
if [ ! -z "$twitch" ]; then
    echo "
                      # Twitch Stream Application
                      application twitch {
                          live on;
                          record off;
                          allow publish 127.0.0.1;
                          deny publish all;

                          # Push URL with the Twitch stream key
                          push rtmp://live-cdg.twitch.tv/app/$twitch;
                      }" >>/etc/nginx/rtmp.conf
fi

# # Facebook configuration ## alpine nginx rtmp does not have a ssl client support, it can be done ssl client upgrade with nginx stream
# if [ ! -z "$facebook" ]; then
#     echo "

#                       # Facebook Stream Application
#                       application facebook {
#                           live on;
#                           record off;
#                           allow publish 127.0.0.1;
#                           deny publish all;

#                           # Push URL with the Facebook stream key
#                           push rtmps://live-api-s.facebook.com:443/rtmp/$facebook;

#                       }
# " >>/etc/nginx/rtmp.conf
# fi

# Facebook configuration
if [ ! -z "$youtube" ]; then
    echo "

                      # YouTube Stream Application  
                      application youtube {
                          live on;
                          record off;
                          allow publish 127.0.0.1;
                          deny publish all;

                          # Push URL with the Facebook stream key
                          push rtmp://a.rtmp.youtube.com/live2/$youtube;

                      }
" >>/etc/nginx/rtmp.conf
fi

### RTMP server and RTMP Class end
echo "                  }
}
" >>/etc/nginx/rtmp.conf

exit_trap() {
    echo -e "\tStream server is closing"
    PGID=$(ps -o pgid= $$ | tr -d \ )
    kill -TERM -$PGID 2>/dev/null

    echo "Server is closed"
    exit 0
}
trap exit_trap INT EXIT
#Start nginx
nginx &
NGINX_PID=$!
wait $NGINX_PID
if [ $? -eq 1 ]; then
    echo -e "${cl_red}\tNginx shutdown is not done in gracefully${cl_nc}"
    exit 1
fi
