#!/bin/bash

readonly DEFAULT_CONSUL_PATH="/etc/consul.d"
readonly DEFAULT_CONSUL_CONFIG="consul.hcl"
readonly DEFAULT_VAULT_PATH="/etc/vault.d"
readonly DEFAULT_VAULT_CONFIG="vault.hcl"
readonly DEFAULT_CONSUL_SERVICE_NAME="consul"

function main {
  local adv_adr="${1}"
  local rtj_wan="${2}"
  local dc="${3}"
  # local v_service="${4}"
  cat << EOF >> ${DEFAULT_CONSUL_PATH}/${DEFAULT_CONSUL_CONFIG}

advertise_addr = "${adv_adr}"
datacenter = "${dc}"
retry_join_wan = ["${rtj_wan}"]

EOF
  # sudo sed -i "s/service[[:space:]]\+=[[:space:]]\+\"vault\"/service[[:space:]]\+=[[:space:]]\+\"${v_service}\"/" ${DEFAULT_VAULT_PATH}/${DEFAULT_VAULT_CONFIG}

}

sudo systemctl enable ${DEFAULT_CONSUL_SERVICE_NAME}

main "$@"
