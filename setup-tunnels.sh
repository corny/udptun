#!/bin/sh

# Used networks:
# - 192.168.9.0/24 private Vagrant network for the VMs
# - 192.168.2.0/24 inner network for the tunnel interfaces

setup()
{
  this=$1
  thisname="node$this"
  otherip="192.168.9.1$2"

  # Prepare ssh config for faster ssh invocation.
  ssh_config="$(mktemp --tmpdir vagrant_ssh_cfg.XXXXXXX)"
  trap "{ rm '$ssh_config'; }" EXIT

  # echo "Include ~/.ssh/config" > "$ssh_config"
  vagrant ssh-config "$thisname"  > "$ssh_config"

  # 1. build and install kernel module
  # 2. build and install setup tool
  # 3. set up tunnel
  ssh -F "$ssh_config" -t root@"$thisname" <<SHELL
    set -x
    cd /vagrant/openspot-kmod-udptun/src/
    make clean
    make
    rmmod udptun
    insmod udptun.ko

    cd /vagrant/udptun-go/src
    go install .

    ~/go/bin/main setup --local :5000 --remote "$otherip:5000"
    ip addr add 192.168.2.$this/24 dev test
    ip link set up dev test
    ~/go/bin/main list
SHELL
}

# build and setup up tunnels

setup 1 2 & # node1 to node2
setup 2 1 & # node2 to node1

wait
