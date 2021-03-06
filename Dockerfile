FROM alpine
WORKDIR /stream-multiplexer
COPY . .
RUN apk add nginx nginx-mod-rtmp bash &&\
mkdir -p /run/nginx/ &&\
cp nginx.conf /etc/nginx/nginx.conf &&\
chmod +x /stream-multiplexer/entrypoint.sh

ENTRYPOINT ["/stream-multiplexer/entrypoint.sh"]
