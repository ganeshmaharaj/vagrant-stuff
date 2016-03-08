# This is a simple vagrant file that should install devstack inside a vagrant
# VM where the system is behind a proxy.
# Author: Ganesh Maharaj Mahalingam

# Install proxy plugins

# Start the vagrant box with some configs
Vagrant.configure("2") do |config|
  if ENV['HTTP_PROXY'] || ENV['http_proxy']
    system "vagrant plugin install vagrant-proxyconf" unless Vagrant.has_plugin?("vagrant-proxyconf")
  end
  config.vm.box = "ubuntu/trusty64"
  config.vm.define 'devstack' do |devstack|
    if Vagrant.has_plugin?("vagrant-proxyconf")
      devstack.proxy.http = (ENV['HTTP_PROXY'])
      devstack.proxy.https = (ENV['HTTPS_PROXY'])
      devstack.proxy.no_proxy = (ENV['NO_PROXY'] || 'localhost,127.0.0.1')
    end
# Setup port forwarding in case you wish to see horizon
    devstack.vm.network "forwarded_port", guest: 80, host: 8001
    devstack.vm.provider :virtualbox do |vb|
      vb.cpus = Integer(ENV['VAGRANT_CPUS'] || 4)
      vb.memory = Integer(ENV['VAGRANT_MEM'] || 8192)
    end

# Run ansible for misc provisioning
    devstack.vm.provision 'ansible' do |ansible|
      ansible.verbose = 'vvv'
      ansible.playbook = 'provision.yml'
    end
  end
end
