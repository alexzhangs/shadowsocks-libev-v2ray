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
#?     The Shell DNS library `acme.sh` is leveraged to achieve this.
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
#?     For the required <name> and <value>, please refer to:
#?     * https://github.com/acmesh-official/acme.sh/wiki/dnsapi
#?
#? File:
#?   The following files are created by this script:
#?
#?   - ~/.acme-account-done-{DOMAIN}
#?
#?     This file is created after the account registration with acme.sh.
#?     The account registration will be skipped if this file exists.
#?
#?   - ~/.acme-cert-done-{DOMAIN}
#?
#?     This file is created after the certificate is issued for the domain with acme.sh.
#?     The certificate issuance will be skipped if this file exists.
#?

# exit on any error
set -e -o pipefail

function usage () {
    awk '/^#\?/ {sub("^[ ]*#\\?[ ]?", ""); print}' "$0" \
        | awk '{gsub(/^[^ ]+.*/, "\033[1m&\033[0m"); print}'
}

function issue-tls-cert () {
    #? Description:
    #?   Issue a TLS certificate with acme.sh.
    #?
    #? Usage:
    #?   issue-tls-cert DOMAIN DNS DNS_ENV [--renew-hook "COMMAND"]
    #?

    declare domain=${1:?} dns=$2 dns_env=$3 renew_opts=("${@:4}")

    declare acme_account_done_file=~/.acme-account-done-${domain}
    declare acme_cert_done_file=~/.acme-cert-done-${domain}

    if [[ -f $acme_cert_done_file ]]; then
        echo "INFO: TLS certificate has been issued for the domain $domain."
        return
    fi

    acme.sh --version

    # Register an account with acme.sh if not done
    if [[ ! -f $acme_account_done_file ]]; then
        acme.sh --register-account -m "acme@$domain"
        touch "$acme_account_done_file"
    fi

    declare -a acme_common_opts=(--force-color --domain "$domain")
    declare -a acme_issue_opts=("${acme_common_opts[@]}" "${renew_opts[@]}" --dns)

    # Setup DNS hook if DNS_ENV is set
    if [[ -n $dns ]]; then
        # Check if the dns_env is set
        if [[ -z $dns_env ]]; then
            echo "WARNING: dns_env is not set." >&2
        fi

        declare -a dns_envs
        # Read the DNS_ENV into an array
        IFS=',' read -r -a dns_envs <<< "$dns_env"

        # Export the dns_envs
        export "${dns_envs[@]}"

        # Issue a certificate for the domain with acme.sh, using DNS hook
        acme.sh --issue "${acme_issue_opts[@]}" "$dns"
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
    ln -s "${domain}_ecc" "/root/.acme.sh/${domain}"

    # Create the cert done file
    touch "$acme_cert_done_file"
}

function main () {

    if [[ $# -eq 0 ]]; then
        usage
        exit 255
    fi

    if [[ $V2RAY -eq 1 ]]; then
        # Issue a TLS certificate
        # shellcheck disable=SC2153
        issue-tls-cert "$DOMAIN" "$DNS" "$DNS_ENV" --renew-hook reboot
    fi

    exec "$@"
}

main "$@"

exit
