# This is a simple vagrant file that should install devstack inside a vagrant
# VM where the system is behind a proxy.
# Author: Ganesh Maharaj Mahalingam

# Setup VM details and network if you are using multiple nodes
# Stolen with pride from https://github.com/swiftstack/vagrant-swift-all-in-one
require 'ipaddr'
base_ip = IPAddr.new(ENV['IP'] || "172.16.0.10")
hosts = {
	'devstack' => base_ip.to_s
}

extra_vms = Integer(ENV['EXTRA_VMS'] || 0)
(1..extra_vms).each do |i|
  base_ip = base_ip.succ
  hosts["devstack#{i}"] = base_ip.to_s
end

# Static Values
host_port = 8000
proxy_ip_list = ""
# Start the vagrant box with some configs
Vagrant.configure("2") do |config|
  if ENV['HTTP_PROXY'] || ENV['http_proxy']
    system "vagrant plugin install vagrant-proxyconf" unless Vagrant.has_plugin?("vagrant-proxyconf")
  end
  # Enable caching to speed up package installation on second run
  # vagrant-cachier
  system "vagrant plugin install vagrant-cachier" unless Vagrant.has_plugin?("vagrant-cachier")
  config.vm.box = "ubuntu/trusty64"
  config.cache.scope = :box

  # Create all no_proxy IP list
  hosts.each do|vm_name, ip|
    proxy_ip_list = ("#{proxy_ip_list},#{ip}")
  end
  hosts.each do|vm_name, ip|
    config.vm.define vm_name do |devstack|
      devstack.vm.hostname = vm_name
        if Vagrant.has_plugin?("vagrant-proxyconf")
          devstack.proxy.http = (ENV['HTTP_PROXY'] || ENV['http_proxy'])
          devstack.proxy.https = (ENV['HTTPS_PROXY'] || ENV['https_proxy'])
          devstack.proxy.no_proxy = (ENV['NO_PROXY']+",#{hostname},#{proxy_ip_list}" || 'localhost,127.0.0.1,#{hostname},#{proxy_ip_list}')
        end
        devstack.vm.network :private_network, ip: ip
    # Setup port forwarding in case you wish to see horizon
        devstack.vm.network :forwarded_port, guest: 80, host: host_port+=1
        devstack.vm.provider :virtualbox do |vb|
          vb.cpus = Integer(ENV['VAGRANT_CPUS'] || 2)
          vb.memory = Integer(ENV['VAGRANT_MEM'] || 5120)
        end

    # Run ansible for misc provisioning
        devstack.vm.provision 'ansible' do |ansible|
          ansible.verbose = 'vvv'
          ansible.playbook = 'provision.yml'
        end
    end
  end
end
