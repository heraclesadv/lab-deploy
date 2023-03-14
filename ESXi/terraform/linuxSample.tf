resource "esxi_guest" "<name>" {
  guest_name = "<name>"
  disk_store = var.esxi_datastore
  guestos    = "ubuntu-64"

  boot_disk_type = "thin"

  memsize            = "8192"
  numvcpus           = "4"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "UbuntuServ2004"

    provisioner "remote-exec" {
    inline = [
      "sudo ifconfig eth0 up && echo 'eth0 up' || echo 'unable to bring eth0 interface up",
      "sudo ifconfig eth1 up && echo 'eth1 up' || echo 'unable to bring eth1 interface up"
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