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

# To enable proxy at build time, use:
# docker build --build-arg https_proxy=http://host.docker.internal:$PROXY_HTTP_PORT_ON_HOST ...
ARG http_proxy https_proxy all_proxy

### First stage: build environment
# Pinned by digest for reproducible builds (alpine:latest as of 2026-06-11).
# Bump deliberately (e.g. via Dependabot/Renovate Docker digest updates).
FROM alpine@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4 as builder

# Instal file, git, curl
RUN apk --no-cache add file git curl

# v2ray-plugin requires Go 1.16
ENV GO_VERSION=1.16.10

# Install Go
RUN <<EOF
    set -ex
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)
            GO_BINARY_URL="https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz"
            GO_SHA256="414cd18ce1d193769b9e97d2401ad718755ab47816e13b2a1cde203d263b55cf"
            ;;
        aarch64)
            GO_BINARY_URL="https://dl.google.com/go/go${GO_VERSION}.linux-arm64.tar.gz"
            GO_SHA256="bfe1d4b82626c742b4690a832ca59a21e3d702161556f3c0ed26dffb368927e9"
            ;;
        *)
            echo "${ARCH}: Unsupported architecture"
            exit 1
            ;;
    esac
    GO_TARBALL=$(basename "${GO_BINARY_URL}")
    curl -LO "${GO_BINARY_URL}"
    # Verify the official checksum before trusting the tarball.
    echo "${GO_SHA256}  ${GO_TARBALL}" | sha256sum -c -
    tar -C /usr/local -xzf "${GO_TARBALL}"

    # Workaround to fix error: go: not found
    # Use `file $(which go)` to debug the missing library
    case ${ARCH} in
        x86_64)
            mkdir /lib64
            ln -s /lib/ld-musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
            ;;
        aarch64)
            ln -s ld-musl-aarch64.so.1 /lib/ld-linux-aarch64.so.1
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
    # Pinned to a release tag (commit ddd7ab46b4aeee0ca8b272efed9d7da3e3a6e52c)
    # instead of the default-branch HEAD.
    git clone --depth 1 --branch v1.3.2 https://github.com/shadowsocks/v2ray-plugin
    (cd v2ray-plugin && go build && /bin/cp -a v2ray-plugin /usr/bin/v2ray-plugin)
EOF

# Verify that v2ray-plugin is installed
RUN v2ray-plugin -version


### Second stage: final image
# Pinned by digest (shadowsocks/shadowsocks-libev:edge as of 2026-06-11).
# Bump deliberately to pick up upstream edge updates.
FROM shadowsocks/shadowsocks-libev@sha256:84166166fcd7feb8dca8a268cd32cd954ca4c3d086b9f748fac8edfea5a0dcac

# Copy the v2ray-plugin binary from the builder stage
COPY --from=builder /usr/bin/v2ray-plugin /usr/bin/v2ray-plugin

# Link the missing library
RUN <<EOF
    # Workaround to fix error: v2ray-plugin: not found
    # Use `file $(which v2ray-plugin)` to debug the missing library
    set -ex
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)
            mkdir /lib64
            ln -s /lib/ld-musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
            ;;
        aarch64)
            ln -s ld-musl-aarch64.so.1 /lib/ld-linux-aarch64.so.1
            ;;
    esac
EOF

# Verify that v2ray-plugin is installed
RUN v2ray-plugin -version

# Instal file, curl, openssl, bash, python3, py3-pip
RUN apk --no-cache add file \
        # used by acme.sh (git: install acme.sh from a pinned tag)
        curl openssl git \
        # used by docker-entrypoint.sh
        bash \
        # used by dns-lexicon and its dependencies
        python3 py3-pip gcc linux-headers libc-dev python3-dev libffi-dev && \
    if [[ ! -e /usr/bin/python ]]; then ln -s python3 /usr/bin/python ; fi && \
    if [[ ! -e /usr/bin/pip ]]; then ln -s pip3 /usr/bin/pip ; fi

# Install dns-lexicon
RUN pip install dns-lexicon

# Install acme.sh, pinned to a release tag instead of `curl | sh` of the
# rolling online installer (get.acme.sh runs --install-online from a branch).
RUN git clone --depth 1 --branch 3.1.3 https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh \
    && (cd /tmp/acme.sh && ./acme.sh --install --home /root/.acme.sh) \
    && rm -rf /tmp/acme.sh

# Set the PATH for acme.sh
ENV PATH=$PATH:/root/.acme.sh

# Verify that acme.sh is installed
RUN acme.sh --version

# Set work directory
WORKDIR /shadowsocks-libev-v2ray

# Copy the current directory contents at local into the container
COPY . .

RUN chmod +x docker-entrypoint.sh

# Use the entrypoint script from this repository over the one from shadowsocks/shadowsocks-libev:edge
ENTRYPOINT [ "./docker-entrypoint.sh" ]

CMD [ "ss-server", "-p", "8388", "-k", "password", "-m", "aes-256-cfb" ]