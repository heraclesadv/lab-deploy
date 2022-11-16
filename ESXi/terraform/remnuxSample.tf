resource "esxi_guest" "<name>" {
  guest_name = "<name>"
  disk_store = var.esxi_datastore
  boot_disk_type = "thin"

  memsize            = "4096"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "Remnux7"
  
    provisioner "remote-exec" {
    inline = [
      "sudo dhclient ens33 && echo 'restart dhclinet on ens33' || echo 'unable to bring ens33 dhclient'",
      "sudo ifconfig ens33 down && echo 'ens33 down' || echo 'unable to bring ens33 interface down'",
      "sudo ifconfig ens33 up && echo 'ens33 up' || echo 'unable to bring ens33 interface up'",
      "sudo ifconfig ens34 down && echo 'ens34 down' || echo 'unable to bring ens34 interface down'"
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