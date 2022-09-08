#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

# Global Vars
kube_ver=$(curl -SsL https://storage.googleapis.com/kubernetes-release/release/stable.txt)
KUBE_VERSION=${KUBE_VERSION:-${kube_ver#v}-*}
crio_ver=$(curl -fsSLI -o /dev/null -w %{url_effective}  https://github.com/cri-o/cri-o/releases/latest | awk -F '/' '{print $8}')
CRIO_VERSION=${crio_ver:1:4}
#contd_ver=$(curl -q https://api.github.com/repos/containerd/containerd/releases | grep "tag_name" | awk -F '"' '{print $4}'  | sort -rV | head -1)
contd_ver=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/containerd/containerd/releases/latest | awk -F '/' '{print $8}')
: ${CONTD_VER:=${contd_ver#v}}
helm_ver=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/helm/helm/releases/latest | awk -F '/' '{print $8}')
: ${HELM_VER:=${helm_ver}}
runc_ver=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/opencontainers/runc/releases/latest | awk -F '/' '{print $8}')
: ${RUNC_VER:=${runc_ver}}
ARCH=$(arch)
#OS=$(source /etc/os-release && echo $NAME)
source /etc/os-release
ADD_NO_PROXY="10.244.0.0/16,10.96.0.0/12"
ADD_NO_PROXY+=",$(hostname -I | sed 's/[[:space:]]/,/g')"

function rpm_install()
{
  sudo -E yum -y update
  sudo -E yum -y install git bash-completion tar
  # Deps for k8s
  sudo -E yum -y install iproute-tc || true
  echo "source /etc/profile.d/bash_completion.sh" >> $HOME/.bashrc
}

function dnf_install()
{
  sudo -E dnf install -y git bash-completion
  sudo -E dnf install -y iproute-tc || true
  echo "source /etc/profile.d/bash_completion.sh" >> $HOME/.bashrc
}

function deb_k8s_install()
{
  echo "Install deb based K8s...."
  sudo -E apt update
  sudo -E apt install -y apt-transport-https curl gnupg2
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo -E apt-key add -
  sudo -E bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
  sudo -E apt update

  sudo -E apt install -y --allow-downgrades \
    kubelet=${KUBE_VERSION} \
    kubeadm=${KUBE_VERSION} \
    kubectl=${KUBE_VERSION}

}

function rpm_k8s_install()
{
  echo "Installing rpm based k8s..."
  sudo -E bash -c 'cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF'

  if [ "$(getenforce | tr [A-Z] [a-z])" != "disabled" ]; then
    sudo -E setenforce 0
    sudo -E sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  fi

  # Disable firewalld incase it is running
  if $(sudo systemctl is-active firewalld > /dev/null); then
    sudo systemctl disable --now firewalld
  fi

  # Adding GPG_TTY so that gpg key imports as part of this command does not end
  # up with exit code 147. Check
  # https://github.com/containers/libpod/issues/4431#issuecomment-580681084
  GPG_TTY=/dev/null sudo -E yum install -y \
    kubelet-${KUBE_VERSION} \
    kubeadm-${KUBE_VERSION} \
    kubectl-${KUBE_VERSION} \
    --disableexcludes=kubernetes
}

function dnf_k8s_install()
{
  echo "Installing dnf based k8s..."
  sudo -E bash -c 'cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
# https://github.com/containers/libpod/issues/4431 maybe causing a 141 error code
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF'

  if [ "$(getenforce) | tr [A-Z][a-z]" != "disabled" ]; then
    sudo -E setenforce 0
    sudo -E sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  fi

  # Disable firewalld incase it is running
  if $(sudo systemctl is-active firewalld > /dev/null); then
    sudo systemctl disable --now firewalld
  fi

  sudo -E dnf install -y \
    kubelet-${KUBE_VERSION} \
    kubeadm-${KUBE_VERSION} \
    kubectl-${KUBE_VERSION} \
    --disableexcludes=kubernetes
}

function deb_crio_install()
{
  sudo -E add-apt-repository -y ppa:projectatomic/ppa
  sudo -E apt update
  # cri-o ppa updates are delayed since release. Using a fall-back mechanism to
  # install the latest version available.
  while [ -z "`sudo -E apt-cache search cri-o-${CRIO_VERSION}`" ]; do
    CRIO_VERSION=$(echo ${CRIO_VERSION}-0.01 | bc)
  done
  sudo -E apt install -y cri-o-${CRIO_VERSION}

  # Add docker.io as a registry to crio
  sudo -E bash -c 'cat <<EOF > /etc/containers/registries.conf
[registries.search]
registries = ["docker.io"]
[registries.insecure]
registries = ["docker.io"]
EOF'
}

function deb_containerd_install()
{
  echo "Install containerd..."
  sudo -E apt install -y containerd
}

function rpm_containerd_pkg_install()
{
  sudo -E yum -y install yum-utils device-mapper-persistent-data lvm2
  sudo -E yum-config-manager -y \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  sudo -E yum install -y containerd.io
  sudo -E mkdir -p /etc/containerd
  sudo -E bash -c 'containerd config default > /etc/containerd/config.toml'
}

function dnf_containerd_pkg_install()
{
  sudo -E dnf -y install yum-utils device-mapper-persistent-data lvm2
  sudo -E yum-config-manager -y \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  sudo -E dnf install -y containerd.io
  sudo -E mkdir -p /etc/containerd
  sudo -E bash -c 'containerd config default > /etc/containerd/config.toml'
}

function containerd_bin_install()
{
    echo "NO package.. Installing prebuilt binaries..."
    while ! $(curl --output /dev/null --head --location https://github.com/containerd/containerd/releases/download/v${CONTD_VER}/cri-containerd-cni-${CONTD_VER}-linux-amd64.tar.gz); do
      CONTD_VER=${CONTD_VER%.*}.$((${CONTD_VER##*.}-1))
    done
    curl --location https://github.com/containerd/containerd/releases/download/v${CONTD_VER}/cri-containerd-cni-${CONTD_VER}-linux-amd64.tar.gz --output - | sudo -E tar -C / -zxvf -
}

function containerd_config_install()
{
  conf_file="/etc/containerd/config.toml"
  runc_runtime="plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc"
  runc_type="io.containerd.runc.v2"
  runc_options="${runc_runtime}.options"

  sudo -E mkdir -p /etc/containerd
  if [ -f ${conf_file} ]; then
    sudo cp ${conf_file} /etc/containerd/config.toml.orig

    if grep -q 'version' ${conf_file}; then
      sudo -E bash -c "sed -i 's/version.*/version = 2/g' ${conf_file}"
    else
      sudo -E bash -c "sed -i '1 i version = 2' ${conf_file}"
    fi

    if grep -q "\[${runc_runtime}\]" $conf_file; then
      echo "runc config exists. Over-writing values..."
      sudo -E sed -i "/\[${runc_runtime}\]/,+1s#runtime_type.*#runtime_type = \"${runc_type}\"#" ${conf_file}
    else
    sudo -E bash -c 'cat <<EOF >> '${conf_file}'
['"${runc_runtime}"']
  runtime_type = '${runc_type}'
EOF'
    fi

    if grep -q "\[${runc_options}\]" ${conf_file}; then
      echo  "runc options exists. over-writing values...."
      sudo -E sed -i "/\[${runc_options}\]/,+1s#SystemdCgroup.*#SystemdCgroup = true#" ${conf_file}
    else
      sudo -E bash -c 'cat <<EOF >> '${conf_file}'
  ['"${runc_options}"']
    SystemdCgroup = true
EOF'
    fi
  else
    sudo -E bash -c 'cat <<EOF> /etc/containerd/config.toml
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF'
  fi
}

function helm_bin_install()
{
  curl https://get.helm.sh/helm-${HELM_VER}-linux-amd64.tar.gz | sudo -E tar -C /usr/local/bin --strip-components=1 -zxvf -
}

function runc_bin_install()
{
  sudo -E bash -c "curl -L https://github.com/opencontainers/runc/releases/download/${RUNC_VER}/runc.amd64 --output /usr/local/sbin/runc"
  sudo -E chmod +x /usr/local/sbin/runc

}

containerd_bin_install
containerd_config_install
helm_bin_install

case "$ID" in
  "ubuntu"*)
    deb_k8s_install;;
  "debian"*)
    deb_k8s_install;
    runc_bin_install;;
  "centos")
    rpm_install;
    rpm_k8s_install;;
  "fedora"|"almalinux"|"rocky")
    dnf_install;
    dnf_k8s_install;;
  *)
    echo "Unknown OS. Exiting Install." && exit 1;;
esac

#######################
# Misc system configs
#######################
echo "Setup system...."
sudo -E mkdir -p /etc/sysconfig
sudo -E bash -c 'echo "CRIO_NETWORK_OPTIONS=\"--cgroup-manager cgroupfs\"" > /etc/sysconfig/crio'

if [ $(sudo -E grep '^/dev/\([0-9a-z]*\).*' /proc/swaps | wc -l) -gt 0 ]; then
  sudo -E systemctl mask $(sed -n -e 's#^/dev/\([0-9a-z]*\).*#dev-\1.swap#p' /proc/swaps) 2>/dev/null
fi
if [ $(sudo -E grep -c swap /etc/fstab) -gt 0 ]; then
  sudo -E sed -i 's/.*swap/#&/g' /etc/fstab
fi

sudo -E mkdir -p /etc/sysctl.d/
cat <<EOT | sudo -E bash -c "cat > /etc/sysctl.d/60-k8s.conf"
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.rp_filter         = 1
net.ipv4.conf.all.rp_filter         = 1
EOT
sudo -E systemctl restart systemd-sysctl

#Ensure the modules we need are preloaded
sudo -E mkdir -p /etc/modules-load.d/
cat <<EOT | sudo -E bash -c "cat > /etc/modules-load.d/k8s.conf"
br_netfilter
vhost_vsock
overlay
EOT

# Make sure /etc/hosts file exists
if [ ! -f /etc/hosts ]; then
  sudo -E touch /etc/hosts
fi
hostcount=$(grep "127.0.0.1\slocalhost\s$(hostname)" /etc/hosts | wc -l)
if [ "$hostcount" == "0" ]; then
	echo "127.0.0.1 localhost $(hostname)" | sudo -E bash -c "cat >> /etc/hosts"
else
	echo "/etc/hosts already configured"
fi

sudo -E systemctl daemon-reload
# This will fail at this point, but puts it into a retry loop that
# will therefore startup later once we have configured with kubeadm.
echo "The following kubelet command may complain... it is not an error"
sudo -E systemctl enable --now kubelet containerd || true

#Ensure that the system is ready without requiring a reboot
sudo -E swapoff -a
sudo -E systemctl restart systemd-modules-load.service

set +o nounset
if [[ ${http_proxy} ]] || [[ ${HTTP_PROXY} ]]; then
	echo "Setting up proxy stuff...."
	# Setup IP for users too
	sed_val=${ADD_NO_PROXY//\//\\/}
	[ -f /etc/environment ] && sudo -E sed -i "/no_proxy/I s/$/,${sed_val}/g" /etc/environment
	if [ -f /etc/profile.d/proxy.sh ]; then
		sudo -E sed -i "/no_proxy/I s/\"$/,${sed_val}\"/g" /etc/profile.d/proxy.sh
	else
		echo "Warning, failed to find /etc/profile.d/proxy.sh to edit no_proxy line"
	fi

	services=('crio' 'kubelet' 'docker' 'containerd')
	for s in "${services[@]}"; do
		sudo -E mkdir -p "/etc/systemd/system/${s}.service.d/"
		cat <<EOF | sudo -E bash -c "cat > /etc/systemd/system/${s}.service.d/proxy.conf"
[Service]
Environment="HTTP_PROXY=${http_proxy}"
Environment="HTTPS_PROXY=${https_proxy}"
Environment="SOCKS_PROXY=${socks_proxy}"
Environment="NO_PROXY=${no_proxy},${ADD_NO_PROXY}"
EOF
	done
fi
set -o nounset

# We have potentially modified their env files, we need to restart the services.
sudo -E systemctl daemon-reload
sudo -E systemctl restart containerd || true
sudo -E systemctl restart kubelet || true

# Setup kubectl auto-completion
echo "source <(kubectl completion bash)" >> $HOME/.bashrc

echo "Cloning the cloud-native-setup repository..."
git clone https://github.com/clearlinux/cloud-native-setup $HOME/cloud-native-setup
