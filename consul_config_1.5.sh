#!/bin/bash

readonly DEFAULT_INSTALL_PATH="/usr/local/bin/consul"
readonly DEFAULT_CONSUL_USER="consul"
readonly DEFAULT_CONSUL_PATH="/etc/consul.d"
readonly DEFAULT_CONSUL_OPT="/opt/consul-storage/"
readonly DEFAULT_CONSUL_CONFIG="consul.hcl"
readonly DEFAULT_CONSUL_SERVICE="/etc/systemd/system/consul.service"
readonly DEFAULT_CONSUL_SERVICE_NAME="consul"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TMP_DIR="/tmp/install"
readonly TMP_ZIP="consul.zip"
readonly SCRIPT_NAME="$(basename "$0")"
# Set the Script variables
# One of
readonly CONSUL_BIN=""
readonly CLUSTER_SIZ="1"
readonly CONSUL_CLIENT="0"


CONSUL_ADDR="http://127.0.0.1:8500"
# Strip acl config
echo "Add ACL Config"
cat << EOF >> ${DEFAULT_CONSUL_PATH}/${DEFAULT_CONSUL_CONFIG}

primary_datacenter = "dc1"
acl {
  enabled = true
  default_policy = "deny"
  down_policy = "extend-cache"
}
EOF

# Restart Consul
echo "restart Consul"
sudo systemctl stop consul
sleep 5
sudo systemctl start consul
sleep 5
CONSUL_TOKEN=`curl --request PUT ${CONSUL_ADDR}/v1/acl/bootstrap |cut -d'"' -f4`
echo "CONSUL_TOKEN == ${CONSUL_TOKEN}"
AT=`curl  --request PUT  --header "X-Consul-Token: ${CONSUL_TOKEN}" --data '{"Name": "Agent Token", "Type": "client", "Rules": "node \"\" { policy = \"write\" } service \"\" { policy = \"read\" }"}' ${CONSUL_ADDR}/v1/acl/create | cut -d'"' -f4`
echo "AGENT TOKEN == ${AT}"
echo "Add agent token"
sed -i'' -Ez "s/(down_policy = \"extend-cache\"\n\s*)\}/\1  tokens \{\n    agent = \"${AT}\"\n  \}\n\}/g" ${DEFAULT_CONSUL_PATH}/${DEFAULT_CONSUL_CONFIG}
sudo systemctl stop consul
sleep 5
sudo systemctl start consul
sleep 5
echo "GET VAULT TOKEN"

VT=`curl --request PUT  --header "X-Consul-Token: ${CONSUL_TOKEN}" --data '{"Name": "Vault Token", "Type": "client", "Rules": "node \"\" { policy = \"write\" } service \"vault\" { policy = \"write\" } agent \"\" { policy = \"write\" }  key \"vault\" { policy = \"write\" } session \"\" { policy = \"write\" } "}' ${CONSUL_ADDR}/v1/acl/create | cut -d'"' -f4`
echo "VT == ${VT}"
# sudo sed -i'' "s/{{ vault_token }}/${at}/" /etc/vault.d/vault.hcl
