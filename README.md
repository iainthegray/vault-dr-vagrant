# vault-dr-vagrant
vagrant 2 vault cluster for DR testing

export VAULT_ADDR=http://127.0.0.1:8200
export CONSUL_HTTP_ADDR=http://127.0.0.1:7500
vault operator init -key-shares=1 -key-threshold=1


Vault-1 server
Unseal Key 1:
Initial Root Token:

Vault-2 server
Unseal Key 1:
Initial Root Token:


**Put your vault enterprise binary in the vagrant directory**
Enable DR
On primary
- vault write -f sys/replication/dr/primary/enable
- vault write sys/replication/dr/primary/secondary-token id="secondary"
- Save the wrapping Token

On secondary
- vault write sys/replication/dr/secondary/enable token="..."


vault read -format=json sys/replication/dr/status
