# BOX_IMAGE = "vault-consul-ent"
BOX_IMAGE = "bento/ubuntu-18.04"

Vagrant.configure("2") do |config|

  config.vm.define "vault-1-server" do |subconfig|
    subconfig.vm.box = BOX_IMAGE
    subconfig.vm.hostname = "vault-1"
    subconfig.vm.network "private_network", ip: "10.0.0.10"
    subconfig.vm.provision "shell", path: "install-vault.sh"
    subconfig.vm.provision "shell" do |s|
      s.path =  "install-consul-server.sh"
      s.args = ['1.5.1', '0', '1']
    end
    subconfig.vm.provision "shell" do |s|
      s.path =  "consul_config.sh"
      s.args = ['10.0.0.10', '10.0.0.11', 'dc1']
    end
  end
  config.vm.define "vault-2-server" do |subconfig|
    subconfig.vm.box = BOX_IMAGE
    subconfig.vm.hostname = "vault-2"
    subconfig.vm.network "private_network", ip: "10.0.0.11"
    subconfig.vm.provision "shell", path: "install-vault.sh"
    subconfig.vm.provision "shell" do |s|
      s.path =  "install-consul-server.sh"
      s.args = ['1.5.1', '0', '1']
    end
    subconfig.vm.provision "shell" do |s|
      s.path =  "consul_config.sh"
      s.args = ['10.0.0.11', '10.0.0.10', 'dc2']
    end
  end
end
