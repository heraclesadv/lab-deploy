resource "esxi_guest" "<name>" {
  guest_name = "<name>"
  disk_store = var.esxi_datastore
  guestos    = "windows9-64"

  boot_disk_type = "thin"

  memsize            = "2048"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "Windows10"
  # This is the network that bridges your host machine with the ESXi VM
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "<MACAddressLanPortGroup>"
    nic_type        = "e1000"
  }
  # This is the local network that will be used for 192.168.56.x addressing
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "<MACAddressHostOnly>"
    nic_type        = "e1000"
  }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}