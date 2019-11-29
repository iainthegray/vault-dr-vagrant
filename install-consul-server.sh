#!/bin/bash
# This script is used to install Consul as per the deployment guide:
# https://learn.hashicorp.com/consul/advanced/day-1-operations/deployment-guide

# operating systems tested on:
#
# 1. Ubuntu 18.04
# https://aws.amazon.com/marketplace/pp/B07CQ33QKV

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
readonly DEFAULT_CONSUL_VER="1.5.1"
readonly CLUSTER_SIZ="1"
readonly CONSUL_CLIENT="0"

function print_usage {
  echo
  echo "Usage: install-consul [OPTIONS]"
  echo "Options:"
  echo "In Order: version, client, ip_addr cluster_size"
  echo
  echo -e "  version\t\t The Consul version to download."
  echo
  echo -e "  client\t\t Should Consul be a client. Args 1 or 0. Required"
  echo
  echo -e "  cluster size\t\t The expected number of servers in the Consul cluster."
  echo
}

function log {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [${SCRIPT_NAME}:${func}] ${message}"
}

function assert_not_empty {
  local func="assert_not_empty"
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log "ERROR" "${func}" "The value for '${arg_name}' cannot be empty"
    print_usage
    exit 1
  fi
}

function has_yum {
  [[ -n "$(command -v yum)" ]]
}

function has_apt_get {
  [[ -n "$(command -v apt-get)" ]]
}

function install_dependencies {
  local func="install_dependencies"
  log "INFO" ${func} "Installing dependencies"

  if has_apt_get; then
    sudo apt-get update
    sudo apt-get install -y jq curl unzip
  else
    log "ERROR" ${func} "Could not find apt-get. Cannot install dependencies on this OS."
    exit 1
  fi
}

function user_exists {
  local -r username="$1"
  id "${username}" >/dev/null 2>&1
}

function create_consul_user {
  local func="create_consul_user"
  local -r username="$1"

  if  user_exists "${username}"  ; then
    log "INFO" ${func} "User ${username} already exists. Will not create again."
  else
    log "INFO" ${func} "Creating user named ${username}"
    sudo useradd --system --home /etc/consul.d --shell /bin/false ${username}
  fi
}

function get_consul_binary {
  # if there is no version then we are going to get binary from S3
  # else we download from Consul site. This is set by type varaiable of 1 or 0
  # if type == 1 then we get bin from S3
  #  else we get bin from download

  local func="get_consul_binary"
  local -r bin="$1"
  local -r type="$2"
  local -r zip="${TMP_ZIP}"
  # get from download
  if [[ ${type} != 1 ]]; then
    ver="${bin}"
    assert_not_empty "--version" ${ver}
    log "INFO" ${func} "Copying Consul version ${ver} binary to local"
    cd ${TMP_DIR} || ( log "ERROR" ${func} "Cannot cd to ${TMP_DIR}" && exit )
    curl -O https://releases.hashicorp.com/consul/${ver}/consul_${ver}_linux_amd64.zip
    curl -Os https://releases.hashicorp.com/consul/${ver}/consul_${ver}_SHA256SUMS
    curl -Os https://releases.hashicorp.com/consul/${ver}/consul_${ver}_SHA256SUMS.sig
    shasum -a 256 -c consul_${ver}_SHA256SUMS 2> /dev/null |grep consul_${ver}_linux_amd64.zip| grep OK
    ex_c=$?
    if [[ ${ex_c} -ne 0 ]]; then
      log "ERROR" ${func} "The copy of the Consul binary failed"
      exit
    else
      log "INFO" ${func} "Copy of Consul binary successful"
    fi
    mv consul_${ver}_linux_amd64.zip "${zip}"
    unzip -tqq ${TMP_DIR}/${zip}
    if [[ $? -ne 0 ]]; then
      log "ERROR" ${func} "Supplied Consul binary is not a zip file"
      exit
    fi
  else
    assert_not_empty "--consul-bin" "${bin}"

    unzip -tqq "/vagrant/${zip}"
    if [[ $? -ne 0 ]]; then
      log "ERROR" ${func} "Supplied Consul binary is not a zip file"
      exit
    fi
  fi
}

# This function creates the paths and sets up the consul HCL

function install_consul {
  local func="install_consul"
  local -r loc="$1"
  local -r tmp="$2"
  local -r zip="$3"

  log "INFO" ${func} "Installing Consul"
  cd ${tmp} && unzip -q ${zip}
  sudo chown root:root consul
  sudo cp consul ${loc}
}

function configure_consul {
  local func="configure_consul"
  local -r path="$1"
  local -r username="$2"
  local -r config="$3"
  local -r opt="$4"
  local -r client="$5"
  local -r bs_exp="$6"
  log "INFO" ${func} "path = ${path} username=${username} config = ${config} opt = ${opt} client = ${client} bs = ${bs_exp}"

  log "INFO" ${func} "Creating install dirs for Consul at ${path}"
  if [[ ! -d "${path}" ]]; then
    sudo mkdir -p "${path}"
  fi
  sudo mkdir -p "${opt}"

  cat << EOF > ${TMP_DIR}/outy

data_dir = "${opt}"
performance {
  raft_multiplier = 1
}
addresses {
  http = "0.0.0.0"
}
ports {
  dns = 7600
  http = 7500
  serf_lan = 7301
  serf_wan = 7302
  server = 7300
}
bind_addr = "0.0.0.0"

EOF
  if [[ ${client} -eq 0 ]]; then
    log "INFO" $func "Installing a Consul server"
    cat << EOF >> ${TMP_DIR}/outy
server = true
bootstrap_expect = ${bs_exp}
ui = true
EOF

  else
    log "INFO" ${func} "Installing a Consul client"
  fi
sudo cp ${TMP_DIR}/outy ${path}/${config}
sudo chmod 640 ${path}/${config}
log "INFO" $func "Changing ownership of ${path} to ${username}"
sudo chown -R "${username}:${username}" "${path}"
sudo chown -R "${username}:${username}" "${opt}"
}

function create_consul_service {
  local func="create_consul_service"
  local -r service="$1"

  log "INFO" ${func} "Creating Consul service"
  cat <<EOF > /tmp/outy
  [Unit]
  Description="HashiCorp Consul - A service mesh solution"
  Documentation=https://www.consul.io/
  Requires=network-online.target
  After=network-online.target
  ConditionFileNotEmpty=${DEFAULT_CONSUL_PATH}/${DEFAULT_CONSUL_CONFIG}

  [Service]
  User=${DEFAULT_CONSUL_USER}
  Group=${DEFAULT_CONSUL_USER}
  ExecStart=${DEFAULT_INSTALL_PATH} agent -config-file=${DEFAULT_CONSUL_PATH}/${DEFAULT_CONSUL_CONFIG}
  ExecReload=${DEFAULT_INSTALL_PATH} reload
  KillMode=process
  Restart=on-failure
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
EOF

  sudo cp /tmp/outy ${service}
  # sudo systemctl enable ${DEFAULT_CONSUL_SERVICE_NAME}

}

function main {
  local func="main"
  sudo rm -rf ${TMP_DIR}
  mkdir ${TMP_DIR}
  # 4 arguments in order
  local version="${1}"
  local client="${2}"
  local cluster_siz="${3}"

  if [ "X${version}" != "X" ]; then
    CONSUL_VER="${version}"
    log "INFO" ${func} "Installing passed version $CONSUL_VER"
  else
    CONSUL_VER=${DEFAULT_CONSUL_VER}
    log "INFO" ${func} "Installing default version $CONSUL_VER"
  fi

  log "INFO" ${func} "Starting Consul install"
  create_consul_user "${DEFAULT_CONSUL_USER}"
  get_consul_binary "${CONSUL_VER}" 0
  install_consul "${DEFAULT_INSTALL_PATH}" "${TMP_DIR}" "${TMP_ZIP}"
  configure_consul "${DEFAULT_CONSUL_PATH}" "${DEFAULT_CONSUL_USER}" "${DEFAULT_CONSUL_CONFIG}" "${DEFAULT_CONSUL_OPT}" "${client}" "${cluster_siz}"
  create_consul_service "${DEFAULT_CONSUL_SERVICE}"
  log "INFO" ${func} "Consul install complete!"
  # sudo rm -rf ${TMP_DIR}
}

main "$@"
