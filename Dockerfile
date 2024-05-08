# Description:
#   This Dockerfile is used to build a v2ray-plugin ready Docker image for shadowsocks-libev.
#   It sets up the necessary dependencies and configurations for running the shadowsocks-libev-v2ray.
#
#   - acme.sh
#   - v2ray-plugin
#
# Volume:
#   None
#
# Expose:
#   - 8388: The port for the shadowsocks service.
#
# Build:
#   docker build -t alexzhangs/shadowsocks-libev-v2ray .
#   docker build --platform linux/amd64 -t alexzhangs/shadowsocks-libev-v2ray .
#
# Run:
#
#   ### Start a shadowsocks port service without v2ray-plugin: ###
#
#   SS_PORT=8388 SS_PASSWORD=password ENCRYPT=aes-256-cfb
#
#   docker run --restart=always -d -p $SS_PORT:$SS_PORT \
#     --name ss-server alexzhangs/shadowsocks-libev-v2ray \
#     ss-server -p $SS_PORT -k $SS_PASSWORD -m $ENCRYPT
#
#
#   ### Start a shadowsocks port service with v2ray-plugin enabled (manual verification): ###
#
#   SS_PORT=8388 SS_PASSWORD=password ENCRYPT=aes-256-cfb DOMAIN=v2ray.ss.yourdomain.com
#
#   docker run -e V2RAY=1 -e DOMAIN=$DOMAIN \
#     --restart=always -d -p $SS_PORT:$SS_PORT \
#     --name ss-server-v2ray alexzhangs/shadowsocks-libev-v2ray \
#     ss-server -p $SS_PORT -k $SS_PASSWORD -m $ENCRYPT \
#       --plugin v2ray-plugin --plugin-opts "server;tls;host=$DOMAIN"
#
#
#   ### Start a shadowsocks manager service without v2ray-plugin, no live port: ###
#
#   MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=aes-256-cfb
#
#   docker run --restart=always -d -p $MGR_PORT:$MGR_PORT/UDP -p $SS_PORTS:$SS_PORTS \
#     --name ss-manager alexzhangs/shadowsocks-libev-v2ray \
#     ss-manager --manager-address 0.0.0.0:$MGR_PORT \
#       --executable /usr/local/bin/ss-server -m $ENCRYPT -s 0.0.0.0
#
#
#   ### Start a shadowsocks manager service with v2ray-plugin enabled (automated verfication with name.com), no live port: ###
#
#   MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=aes-256-cfb DOMAIN=v2ray.ss.yourdomain.com
#   DNS=dns_namecom DNS_ENV=Namecom_Username=your_username,Namecom_Token=your_password
#
#   docker run -e V2RAY=1 -e DOMAIN=$DOMAIN \
#     -e DNS=$DNS -e DNS_ENV=$DNS_ENV \
#     --restart=always -d -p $MGR_PORT:$MGR_PORT/UDP -p $SS_PORTS:$SS_PORTS \
#     --name ss-manager-v2ray alexzhangs/shadowsocks-libev-v2ray \
#     ss-manager --manager-address 0.0.0.0:$MGR_PORT \
#       --executable /usr/local/bin/ss-server -m $ENCRYPT -s 0.0.0.0 \
#       --plugin v2ray-plugin --plugin-opts "server;tls;host=$DOMAIN"
#
# For more information, please refer to the project repository:
#   https://github.com/alexzhangs/shadowsocks-libev-v2ray
#
FROM shadowsocks/shadowsocks-libev:edge

# Set work directory
WORKDIR /shadowsocks-libev-v2ray

# Copy the current directory contents at local into the container
COPY . .

RUN chmod +x docker-entrypoint.sh

# Instal file, git, curl, and openssl
RUN apk add file git curl openssl

# Install acme.sh
RUN curl -sL https://get.acme.sh | sh

# Set the PATH for acme.sh
ENV PATH=$PATH:/root/.acme.sh

# Verify that acme.sh is installed
RUN acme.sh --version

# Install Go 1.16 (v2ray-plugin requires Go 1.16)
RUN <<EOF
    set -ex
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)
            GO_BINARY_URL="https://dl.google.com/go/go1.16.10.linux-amd64.tar.gz"
            ;;
        aarch64)
            GO_BINARY_URL="https://dl.google.com/go/go1.16.10.linux-arm64.tar.gz"
            ;;
        *)
            echo "${ARCH}: Unsupported architecture"
            exit 1
            ;;
    esac
    curl -LO ${GO_BINARY_URL}
    tar -C /usr/local -xzf go1.16.10.linux-*.tar.gz

    # Workaround to fix error: go: not found
    # Use `file $(which go)` to debug the missing library
    case ${ARCH} in
        x86_64)
            mkdir /lib64
            ln -s /lib/ld-musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
            ;;
        aarch64)
            ln -s /lib/ld-musl-aarch64.so.1 /lib/ld-linux-aarch64.so.1
            ;;
    esac
EOF

# Set the PATH for Go
ENV PATH=$PATH:/usr/local/go/bin

# Verify that Go is installed
RUN go version && go env

# Install v2ray-plugin
RUN <<EOF
    set -ex
    git clone --depth 1 https://github.com/shadowsocks/v2ray-plugin
    (cd v2ray-plugin && go build && /bin/cp -a v2ray-plugin /usr/bin/v2ray-plugin)
EOF

# Verify that v2ray-plugin is installed
RUN v2ray-plugin -version

# Install Bash
RUN apk add bash

# Use the entrypoint script from this repository over the one from shadowsocks/shadowsocks-libev:edge
ENTRYPOINT [ "./docker-entrypoint.sh" ]

CMD [ "ss-server", "-p", "8388", "-k", "password", "-m", "aes-256-cfb" ]