#!/bin/bash

#? Description:
#?   Build the Docker image and run the container for testing.
#?
#? Usage:
#?   build-and-run.sh
#?
#? Options:
#?   None
#?
#? Environment:
#?   The following environment variables are used by this script:
#?
#?   - XSH_AWS_CFN_VPN_DOMAIN
#?
#?     Required, default is unset.
#?     The domain name for the V2Ray service.
#?
#?   - Namecom_Username
#?
#?     Required, default is unset.
#?     The username for the Name.com API.
#?
#?   - Namecom_Token
#?
#?     Required, default is unset.
#?     The token for the Name.com API.
#?

set -e -o pipefail

declare tag
tag=dev-$(date +%Y%m%d-%H%M%S)
docker build -t "alexzhangs/shadowsocks-libev-v2ray:$tag" .

declare MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=aes-256-cfb DOMAIN=$XSH_AWS_CFN_VPN_DOMAIN
declare DNS=dns_namecom DNS_ENV="Namecom_Username=$Namecom_Username,Namecom_Token=$Namecom_Token"

docker run -e V2RAY=1 -e DOMAIN="$DOMAIN" \
  -e DNS="$DNS" -e DNS_ENV="$DNS_ENV" \
  --restart=always -d -p $MGR_PORT:$MGR_PORT/UDP -p $SS_PORTS:$SS_PORTS -p $SS_PORTS:$SS_PORTS/UDP\
  --name "ss-manager-v2ray-$tag" "alexzhangs/shadowsocks-libev-v2ray:$tag" \
  ss-manager --manager-address 0.0.0.0:$MGR_PORT \
    --executable /usr/local/bin/ss-server -m "$ENCRYPT" -s 0.0.0.0 -u \
    --plugin v2ray-plugin --plugin-opts "server;tls;host=$DOMAIN"