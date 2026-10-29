# frozen_string_literal: true

require "ipaddr"

def positive_integer_env(name, default)
  value = Integer(ENV.fetch(name, default.to_s))
  raise "#{name} must be greater than zero" unless value.positive?

  value
rescue ArgumentError
  raise "#{name} must be a positive integer"
end

control_plane_ip = ENV.fetch("CONTROL_PLANE_IP", "192.168.56.10")
worker_ip = ENV.fetch("WORKER_IP", "192.168.56.11")
begin
  control_plane_address = IPAddr.new(control_plane_ip)
  worker_address = IPAddr.new(worker_ip)
  raise "CONTROL_PLANE_IP and WORKER_IP must be IPv4 addresses" unless control_plane_address.ipv4? && worker_address.ipv4?
rescue IPAddr::InvalidAddressError
  raise "CONTROL_PLANE_IP and WORKER_IP must be valid IP addresses"
end
raise "CONTROL_PLANE_IP and WORKER_IP must be different" if control_plane_address == worker_address

control_plane_cpus = positive_integer_env("CONTROL_PLANE_CPUS", 2)
control_plane_memory = positive_integer_env("CONTROL_PLANE_MEMORY_MB", 3072)
worker_cpus = positive_integer_env("WORKER_CPUS", 2)
worker_memory = positive_integer_env("WORKER_MEMORY_MB", 2048)
pod_cidr = ENV.fetch("POD_CIDR", "10.244.0.0/16")
cni_plugin = ENV.fetch("CNI_PLUGIN", "calico")
raise "Unsupported CNI_PLUGIN: #{cni_plugin}" unless %w[calico cilium].include?(cni_plugin)

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "20241002.0.0"

  config.vm.define "worker" do |worker|
    worker.vm.hostname = "worker"
    worker.vm.network "private_network", ip: worker_ip
    worker.vm.provider "virtualbox" do |virtualbox|
      virtualbox.cpus = worker_cpus
      virtualbox.memory = worker_memory
    end
  end

  config.vm.define "control-plane" do |control_plane|
    control_plane.vm.hostname = "control-plane"
    control_plane.vm.network "private_network", ip: control_plane_ip
    control_plane.vm.provider "virtualbox" do |virtualbox|
      virtualbox.cpus = control_plane_cpus
      virtualbox.memory = control_plane_memory
    end
    control_plane.vm.provision "file",
      source: ".vagrant/machines/worker/virtualbox/private_key",
      destination: "/home/vagrant/.ssh/worker_vagrant_key"
    control_plane.vm.provision "shell",
      inline: "chmod 0600 /home/vagrant/.ssh/worker_vagrant_key"
    control_plane.vm.provision "ansible_local" do |ansible|
      ansible.install = true
	  ansible.limit = "all"
      ansible.provisioning_path = "/vagrant"
      ansible.playbook = "ansible/site.yml"
      ansible.inventory_path = "/vagrant/ansible/inventory.ini"
      ansible.config_file = "/vagrant/ansible/ansible.cfg"
      ansible.become = true
      ansible.extra_vars = {
        control_plane_ip: control_plane_ip,
        worker_ip: worker_ip,
        kubernetes_pod_cidr: pod_cidr,
		cni_plugin: cni_plugin
      }
    end
  end
end
