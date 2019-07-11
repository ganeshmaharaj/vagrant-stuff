# K8s Vagrant
Small setup that creates a k8s cluster using scripts initially created towards ClearLinux.

## Supported OS
* Ubuntu
* Centos

## Defaults
* OS:        Ubuntu
* Instances: 3
* CPUS:      4
* Memory:    4096MB
* Disks:     1
* IPs:       2

## Overrides
There are two ways to override these variables. (Listed in the order of priority)
1. Enviornment variables. These variables will be taken into account
    ```
    OS
    CPUS
    MEMORY
    DISKS
    ```
2. Create `.config.rb` file in the folder where Vagrantfile is and it will be taken into account.
