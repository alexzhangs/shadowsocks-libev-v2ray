#!/usr/bin/env bash

#? Description:
#?   This script is the entry point for the Docker container.
#?
#? Usage:
#?   docker-entrypoint.sh <ss-manager|ss-server|...> [OPTIONS]
#?
#? Options:
#?   <ss-manager|ss-server|...>
#?
#?   Specify the service to start.
#?
#?   [OPTIONS]
#?
#?   Specify the options for the service.
#?   The options are passed to the service as is, no more, no less.
#?
#? Environment:
#?   The following environment variables are used by this script:
#?
#?   - V2RAY=1
#?
#?     Optional, default is unset.
#?     If set, the following steps will be taken before to execute CMD:
#?       * Register an account with acme.sh
#?       * Issue a certificate for the domain with acme.sh
#?
#?   - DOMAIN=v2ray.ss.yourdomain.com
#?
#?     Required if env `V2RAY` is set, default is unset.
#?     The domain name for the V2Ray service.
#?     Please replace `v2ray.ss.yourdomain.com` with your actual domain name.
#?     And make sure the domain name matches the value used for `--plugin-opts` option.
#?   
#?   - DNS=<dns_hook>
#?
#?     Optional, used if env `V2RAY` is set, default is unset.
#?     Specify the <dns_hook> for your domain to automate domain owner verification.
#?     The <dns_hook> won't be verified until the domain owner verification is triggered.
#?     For the list of supported <dns_hook>, please refer to:
#?     * https://github.com/acmesh-official/acme.sh/wiki/dnsapi
#?
#?     If goes without `DNS`, the manual step will be required for the domain owner verification.
#?
#?   - DNS_ENV=<name>=<value>[,...]
#?
#?     Required if env `DNS` is set, default is unset.
#?     Specify the environment variables required by the <dns_hook>, usually for the username and token.
#?     The <name> and <value> are separated by `=`, and multiple pairs are separated by `,`.
#?     The <name> and <value> are case-sensitive.
#?     The <name> and <value> won't be verified until the domain owner verification is triggered.
#?     For the required <name> and <value>, please refer to:
#?     * https://github.com/acmesh-official/acme.sh/wiki/dnsapi
#?

# exit on any error
set -e -o pipefail

function usage () {
    awk '/^#\?/ {sub("^[ ]*#\\?[ ]?", ""); print}' "$0" \
        | awk '{gsub(/^[^ ]+.*/, "\033[1m&\033[0m"); print}'
}

function issue-tls-cert () {
    # Check if the required environment variables are set
    if [[ -z $DOMAIN ]]; then
        echo "FATAL: environment variable DOMAIN is not set." >&2
        exit 255
    fi

    declare done_file=~/.issue-tls-cert-done

    if [[ -f $done_file ]]; then
        echo "INFO: TLS certificate has been issued for the domain $DOMAIN."
        return
    fi

    acme.sh --version

    # Register an account with acme.sh
    acme.sh --register-account -m "acme@$DOMAIN"

    declare -a acme_common_opts=(--force-color --domain "$DOMAIN")
    declare -a acme_issue_opts=("${acme_common_opts[@]}" --renew-hook reboot --dns)

    # Setup DNS hook if DNS is set
    if [[ -n $DNS ]]; then
        # Check if the required environment variables are set
        if [[ -z $DNS_ENV ]]; then
            echo "WARNING: environment variable DNS_ENV is not set." >&2
        fi

        declare -a DNS_ENVS
        # Read the DNS_ENV into an array
        IFS=',' read -r -a DNS_ENVS <<< "$DNS_ENV"

        declare expr
        # Export the DNS_ENVS
        for expr in "${DNS_ENVS[@]}"; do
            export "${expr:?}"
        done

        # Issue a certificate for the domain with acme.sh, using DNS hook
        acme.sh --issue "${acme_issue_opts[@]}" "$DNS"
    else
        # Issue a certificate for the domain with acme.sh, using manual mode, ignoring the non-zero exit code
        acme.sh --issue "${acme_issue_opts[@]}" --yes-I-know-dns-manual-mode-enough-go-ahead-please || :

        while true; do
            echo "Sleeping for 60 seconds to allow the DNS record to propagate ..."
            sleep 60

            # Verify the domain owner
            if acme.sh --renew "${acme_common_opts[@]}" --yes-I-know-dns-manual-mode-enough-go-ahead-please; then
                break
            fi
        done
    fi

    # Create a symbolic link for the certificate directory, v2ray-plugin seaches only the path without the _ecc suffix
    ln -s "${DOMAIN}_ecc" "/root/.acme.sh/${DOMAIN}"

    # Create the cert done file
    touch "$done_file"
}

function main () {

    if [[ $# -eq 0 ]]; then
        usage
        exit 255
    fi

    if [[ $V2RAY -eq 1 ]]; then
        # Issue a TLS certificate
        issue-tls-cert
    fi

    exec "$@"
}

main "$@"

exit
