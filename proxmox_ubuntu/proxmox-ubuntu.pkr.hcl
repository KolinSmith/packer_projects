locals {
  timestamp       = formatdate("YYYYMMDDhhmmss", timestamp())
  datestamp       = formatdate("YYYY-MM-DD", timestamp())
  vm_lower        = lower(var.vmname)
  out_dir         = abspath("${path.root}/../build")
  inspecs         = abspath("${path.root}/../inspec")
  vmimagefullname = "dm-${var.vmname}.${var.version}_${local.timestamp}"
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = "https://your-proxmox-host:8006/api2/json"
  username                 = "root@pam"
  password                 = "your_password"
  node                     = "your-proxmox-node"
  insecure_skip_tls_verify = true

  iso_url          = "https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso"
  iso_checksum     = "sha256:b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
  
  vm_name         = local.vmimagefullname
  vm_id           = "900" # Adjust as needed
  memory          = "2048"
  cores           = "2"
  
  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = "local-lvm"
    format       = "raw"
  }

  # Ubuntu Server autoinstall settings
  http_directory    = "http"
  boot_wait        = "10s"
  boot_command     = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<F10>"
  ]
}

build {
  name    = "DM-Proxmox-VM-Image"
  sources = ["source.proxmox-iso.ubuntu"]

  # Your existing provisioners can largely remain the same
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish'",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do echo -n '.'; sleep 2; done",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python3 python3-rpm",
      "sudo mkdir -p /opt/dm_build/${local.vm_lower}",
      "sudo chmod 777 /opt/dm_build/${local.vm_lower}"
    ]
  }

  # Your existing file provisioner
  provisioner "file" {
    source      = "${path.root}/staging/${local.vm_lower}/"
    destination = "/opt/dm_build/${local.vm_lower}"
  }

  # Your existing ansible provisioner
  provisioner "ansible" {
    playbook_file       = "${path.root}/ansible/default_playbook.yml"
    keep_inventory_file = false
    ansible_env_vars = [
      "myname=${var.vmname}",
    ]
    host_alias = var.vmname
    extra_arguments = [
      "--extra-vars",
      "{\"myname\":\"${var.vmname}\"}",
    ]
  }
}