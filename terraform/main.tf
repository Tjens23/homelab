terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

variable "pm_api_url" { type = string }
variable "pm_tls_insecure" { type = bool }
variable "pm_user" { type = string }
variable "pm_password" {
  type      = string
  sensitive = true
}
variable "pm_parallel" { type = number }
variable "pm_minimum_permission_check" { type = bool }

variable "target_node" {
  type    = string
  default = "pve"
}

variable "ostemplate" {
  type    = string
  default = "local:vztmpl/nixos-image-lxc-proxmox-26.11.20260531.331800d-x86_64-linux.tar.xz"
}

variable "network_gateway" { type = string }
variable "network_cidr" { type = number }

provider "proxmox" {
  pm_api_url                  = var.pm_api_url
  pm_tls_insecure             = var.pm_tls_insecure
  pm_user                     = var.pm_user
  pm_password                 = var.pm_password
  pm_parallel                 = var.pm_parallel
  pm_minimum_permission_check = var.pm_minimum_permission_check
}

resource "proxmox_lxc" "ansible" {
  target_node  = var.target_node
  vmid         = 199
  hostname     = "ansible"
  ostemplate   = var.ostemplate
  start        = true
  onboot       = true
  unprivileged = true

  cores  = 2
  memory = 2048
  swap   = 512

  rootfs {
    storage = "local"
    size    = "20G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  features {
    nesting = true
  }
}

resource "proxmox_lxc" "k8s-masters" {  
  count = 3
  target_node  = var.target_node
  hostname     = "hele-${format("%02d", count.index + 1)}"
  ostemplate   = var.ostemplate
  start        = true
  onboot       = true
  unprivileged = true

  cores  = 4
  memory = 8196

  rootfs {
    storage = "local"
    size    = "20G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  features {
    nesting = true
  }
}


resource "proxmox_lxc" "k8s-workers" {  
  count = 3
  target_node  = var.target_node
  hostname     = "heroku-${format("%02d", count.index + 1)}"
  ostemplate   = var.ostemplate
  start        = true
  onboot       = true
  unprivileged = true

  cores  = 4
  memory = 16384

  rootfs {
    storage = "local"
    size    = "50G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  features {
    nesting = true
  }
}


resource "proxmox_lxc" "k8s-etcd" {  
  count = 3
  target_node  = var.target_node
  hostname     = "porcian-${format("%02d", count.index + 1)}"
  ostemplate   = var.ostemplate
  start        = true
  onboot       = true
  unprivileged = true

  cores  = 4
  memory = 8192

  rootfs {
    storage = "local"
    size    = "30G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  features {
    nesting = true
  }
}