[![License](https://img.shields.io/github/license/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/)
[![GitHub last commit](https://img.shields.io/github/last-commit/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/pulls)
[![GitHub tag](https://img.shields.io/github/v/tag/alexzhangs/shadowsocks-libev-v2ray?sort=date)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/tags)

[![GitHub Actions - CI Docker Build and Push](https://github.com/alexzhangs/shadowsocks-libev-v2ray/actions/workflows/ci-docker.yml/badge.svg)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/actions/workflows/ci-docker.yml)
[![Docker Image Version](https://img.shields.io/docker/v/alexzhangs/shadowsocks-libev-v2ray?label=docker%20image)](https://hub.docker.com/r/alexzhangs/shadowsocks-libev-v2ray)

# shadowsocks-libev-v2ray
A v2ray-plugin ready shadowsocks-libev Docker image, using acme.sh to automate certificate provision and renew

## Dependencies
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [v2ray-plugin](https://github.com/shadowsocks/v2ray-plugin)
- [acme.sh](https://github.com/acmesh-official/acme.sh)

## Usage

Start a shadowsocks manager service with v2ray-plugin enabled (automated verfication with name.com), no live port:


```sh
MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=aes-256-cfb DOMAIN=v2ray.ss.yourdomain.com

DNS=dns_namecom DNS_ENV=Namecom_Username=your_username,Namecom_Token=your_password

docker run -e V2RAY=1 -e DOMAIN=$DOMAIN \
  -e DNS=$DNS -e DNS_ENV=$DNS_ENV \
  --restart=always -d -p $MGR_PORT:$MGR_PORT/UDP -p $SS_PORTS:$SS_PORTS \
  --name ss-manager-v2ray alexzhangs/shadowsocks-libev-v2ray \
  ss-manager --manager-address 0.0.0.0:$MGR_PORT \
    --executable /usr/local/bin/ss-server -m $ENCRYPT -s 0.0.0.0 \
    --plugin v2ray-plugin --plugin-opts "server;tls;host=$DOMAIN"
```

More usage examples can be found in the [Dockerfile](Dockerfile) and the [docker-entrypoint.sh](docker-entrypoint.sh).

## Certificates Renewal

The docker file is not configured to renew certificates automatically. Since the renewal process requires the ss-server or ss-manager to restart to be aware of the new certificates, thus the more appropriate way to renew certificates is to restart the container.

A new certificate will be issued if the container is restarted. To automate the renewal process, you can use a cron job to restart the container periodically.

For now, acme.sh certificates have a maximum 90-day validity period.

Run below command to check the certificate details inside the container:

```sh
openssl x509 -text -in /root/.acme.sh/$DOMAIN/fullchain.cer
```

## CI/CD

Github Actions is currently used for the CI/CD.

The CI/CD workflows are defined in the `.github/workflows` directory.

* ci-docker.yml: Build and push the docker image to Docker Hub. It can be triggered by the Github release.
