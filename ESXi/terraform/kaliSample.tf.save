resource "esxi_guest" "<name>" {
  guest_name = "<name>"
  disk_store = var.esxi_datastore

  boot_disk_type = "thin"

  memsize            = "4096"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "Kali20223"


    provisioner "remote-exec" {
    inline = [
      "sudo dhclient eth0 && echo 'restart dhclient on eth0' || echo 'unable to bring eth0 dhclient'",
      "sudo ifconfig eth0 down && echo 'eth0 down' || echo 'unable to bring eth0 interface down'",
      "sudo ifconfig eth0 up && echo 'eth0 up' || echo 'unable to bring eth0 interface up'",
      "sudo ifconfig eth1 down && echo 'eth1 down' || echo 'unable to bring eth1 interface down'"
    ]

    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
    }
  }

  # <balise> 
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "<MACAddressLanPortGroup>"
    nic_type        = "e1000"
  }
  # <balise>
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "<MACAddressHostOnly>"
    nic_type        = "e1000"
  }

  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}
