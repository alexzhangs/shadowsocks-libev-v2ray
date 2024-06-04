[![License](https://img.shields.io/github/license/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/)
[![GitHub last commit](https://img.shields.io/github/last-commit/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/alexzhangs/shadowsocks-libev-v2ray.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/pulls)
[![GitHub tag](https://img.shields.io/github/v/tag/alexzhangs/shadowsocks-libev-v2ray?sort=date)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/tags)

[![GitHub Actions - CI Docker Build and Push](https://github.com/alexzhangs/shadowsocks-libev-v2ray/actions/workflows/ci-docker.yml/badge.svg)](https://github.com/alexzhangs/shadowsocks-libev-v2ray/actions/workflows/ci-docker.yml)
[![Docker Image Version](https://img.shields.io/docker/v/alexzhangs/shadowsocks-libev-v2ray?label=docker%20image)](https://hub.docker.com/r/alexzhangs/shadowsocks-libev-v2ray)

# shadowsocks-libev-v2ray
A v2ray-plugin ready shadowsocks-libev Docker image, using acme.sh to automate certificate provision and renewal.

## Dependencies
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [v2ray-plugin](https://github.com/shadowsocks/v2ray-plugin)
- [acme.sh](https://github.com/acmesh-official/acme.sh)

## Usage

Start a shadowsocks manager (ss-manager) service with v2ray-plugin enabled (automated verification with name.com), no live port:


```sh
MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=aes-256-gcm DOMAIN=v2ray.ss.example.com

DNS=dns_namecom DNS_ENV=Namecom_Username=your_username,Namecom_Token=your_token

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

acme.sh always sets up a daily cron job to check and renew the certificates automatically.

```sh
# crontab -l | grep acme.sh
10 21 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null
```

For now, acme.sh certificates have a maximum 90-day validity period, and will be renewed automatically on the 60th day.

This project sets up a renew hook command `reboot` at the certificate issue time, as long as the `ss-server` and `ss-manager` commands handle the `SIGINT` signal properly, and combined with the `--restart=always` option, the container will be restarted automatically after the certificate renewal.

As a result, the container handles the certificate renewal automatically without interfering with the host.

However, if you are running the container with the `ss-manager` command, after the container is restarted, all the ports created by the multi-user API will be lost, and you are responsible for re-creating them. The project [shadowsocks-manager](https://github.com/alexzhangs/shadowsocks-manager) uses heartbeat to monitor the `ss-manager` service and re-create the ports automatically.


## Certificate Management

List all the certificates inside the container:

```sh
acme.sh --list
```

Run below command to check the certificate details inside the container:

```sh
openssl x509 -text -in /root/.acme.sh/$DOMAIN/fullchain.cer
```

## CI/CD

Github Actions is currently used for the CI/CD.

The CI/CD workflows are defined in the `.github/workflows` directory.

* ci-docker.yml: Build and push the docker image to Docker Hub. It can be triggered by the Github release.
