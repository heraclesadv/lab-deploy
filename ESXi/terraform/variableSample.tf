#
#  See https://www.terraform.io/intro/getting-started/variables.html for more details.
#
#  Don't change the variables in this file! 
#  Instead, create a terrform.tfvars file to override them.

variable "esxi_hostname" {
  default = "<ESXiIP>"
}

variable "esxi_hostport" {
  default = "22"
}

variable "esxi_username" {
  default = "<ESXiUser>"
}

variable "esxi_password" { 
  default = "<ESXiPwd>"
}

variable "esxi_datastore" {
  default = "<ESXiDatastore>"
}

variable "vm_network" {
  default = "<VMNetwork>"
}

variable "hostonly_network" {
  default = "<HostOnlyNetwork>"
}
