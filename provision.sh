#!/usr/bin/env bash
set -ex

mkdir -p /etc/dpkg/dpkg.cfg.d
cat >/etc/dpkg/dpkg.cfg.d/01_nodoc <<EOF
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF

export DEBIAN_FRONTEND=noninteractive
export APTARGS="-qq -o=Dpkg::Use-Pty=0"
export CONSUL=$1

systemctl stop apt-daily.service
systemctl kill --kill-who=all apt-daily.service

# wait until `apt-get updated` has been killed
while ! (systemctl list-units --all apt-daily.service | fgrep -q dead)
do
  sleep 1;
done

apt-get clean ${APTARGS}
apt-get update ${APTARGS}

apt-get upgrade -y ${APTARGS}
apt-get dist-upgrade -y ${APTARGS}

# unzip jq wget
echo "Installing packages"
which unzip jq wget &>/dev/null || {
  apt-get update -y ${APTARGS}
  apt-get install unzip jq wget -y ${APTARGS}
}

if [ -z "$CONSUL" ]; then
  CONSUL=`wget -qO-  https://releases.hashicorp.com/consul/index.json | jq -r '.versions[].version' | grep --extended-regexp --invert-match 'ent|beta|rc|alpha' | tail -1`
fi
# check consul binary
which consul || {
  echo "Installing consul..."
  pushd /usr/local/bin
  [ -f consul_${CONSUL}_linux_amd64.zip ] || {
    wget https://releases.hashicorp.com/consul/${CONSUL}/consul_${CONSUL}_linux_amd64.zip
  }
  unzip consul_${CONSUL}_linux_amd64.zip
  chmod +x consul
  popd
}

# Creating user
echo "Create consul user"

consul -autocomplete-install
complete -C /usr/local/bin/consul consul
groupadd --system consul
useradd -s /sbin/nologin --system -g consul consul
mkdir -p /etc/consul.d/
mkdir -p /opt/consul
chown -R consul:consul /opt/consul
chmod -R 775 /opt/consul
chown -R consul:consul /etc/consul.d/
chmod -R 775 /etc/consul.d/

####################################
# Consul Server systemd Unit file  #
####################################
cat <<EOF > /etc/systemd/system/consul.service
### BEGIN INIT INFO
# Provides:          consul
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Consul agent
# Description:       Consul service discovery framework
### END INIT INFO

[Unit]
Description=Consul server agent
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
PIDFile=/var/run/consul/consul.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/consul
ExecStartPre=/bin/chown -R consul:consul /var/run/consul
ExecStart=/usr/local/bin/consul agent \
    -config-dir=/etc/consul.d/ \
    -pid-file=/var/run/consul/consul.pid
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target

EOF

###################
# Starting Consul #
###################
cat <<EOF > /etc/consul.d/server.json
{ 
  "server": true,
  "bootstrap_expect": 1
}
EOF
systemctl daemon-reload

echo "Finished provisioning"
set +x

# Update to the latest kernel
apt-get install -y linux-generic linux-image-generic ${APTARGS}

# build-essential
apt-get install -y build-essential ${APTARGS}

# Hide Ubuntu splash screen during OS Boot, so you can see if the boot hangs
apt-get remove -y plymouth-theme-ubuntu-text
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
update-grub

# Reboot with the new kernel
shutdown -r now
