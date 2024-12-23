
locals {
  timestamp       = formatdate("YYYYMMDDhhmmss", timestamp())
  datestamp       = formatdate("YYYY-MM-DD", timestamp())
  vm_lower        = lower(var.vmname)
  out_dir         = abspath("${path.root}/../build")
  inspecs         = abspath("${path.root}/../inspec")
  vmimagefullname = "dm-${var.vmname}.${var.version}_${local.timestamp}"
}

source "azure-arm" "dm-bastion-vm" {
  client_id       = var.clientId
  client_secret   = var.clientSecret
  subscription_id = var.subscriptionId
  tenant_id       = var.tenantId

  temp_resource_group_name          = "${var.resourceGroupName}-Builder-${local.timestamp}"
  managed_image_name                = local.vmimagefullname
  managed_image_resource_group_name = var.resourceGroupName

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_sku       = "20_04-lts"

  location = var.location
  vm_size  = var.virtualMachineSize
}

build {
  name    = "DM-Azure-Bastion-VM-Image"
  sources = ["sources.azure-arm.dm-bastion-vm"]

  # Display build metadata
  provisioner "shell-local" {
    inline = [
      "echo 'SN: ${source.name} ST: ${source.type}'",
      "echo 'H: ${build.Host}:${build.Port} U: ${build.User}  Id: ${local.timestamp} Ver: ${var.version}'",
      "echo '${build.SSHPrivateKey}' > ${local.out_dir}/${local.timestamp}.key ; chmod 0600 ${local.out_dir}/${local.timestamp}.key",
    ]
  }

  # Ensure instance has completed boot process & has python3 installed; create staging file area
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish'",
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do echo -n '.'; sleep 2; done",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python3 python3-rpm; python3 --version",
      "sudo mkdir -p /opt/dm_build/${local.vm_lower} || echo 'staging area was present'",
      "sudo chmod 777 /opt/dm_build/${local.vm_lower}"
    ]
  }

  ## Upload course staging directory to target instance
  # TRAILING SLASHES MATTER  - https://www.packer.io/docs/provisioners/file
  # If the source, however, is /foo/ (a trailing slash is present),
  # and the destination is /tmp, then the contents of /foo will be
  # uploaded into /tmp directly.
  provisioner "file" {
    source      = "${path.root}/staging/${local.vm_lower}/"
    destination = "/opt/dm_build/${local.vm_lower}"
  }

  # run a "before" InSpec audit
  provisioner "shell-local" {
    inline = [
      "inspec detect --key-files=${local.out_dir}/${local.timestamp}.key --target ssh://${build.User}@${build.Host}:${build.Port} --user=${build.User} --sudo || echo $?",
      <<-INSPEC
      inspec exec  ${local.inspecs}/dm --key-files=${local.out_dir}/${local.timestamp}.key \
      --target ssh://${build.User}@${build.Host}:${build.Port} --user=${build.User} --sudo \
      --reporter html:${local.out_dir}/${local.timestamp}.azure.before.html \
                junit:${local.out_dir}/${local.timestamp}.azure.before.junit.xml || echo 'InSpec: '$?
      INSPEC
      ,
    ]
  }

  provisioner "ansible" {
    playbook_file       = "${path.root}/ansible/default_playbook.yml"
    keep_inventory_file = false
    ansible_env_vars = [
      "myname=${var.vmname}",
    ]
    host_alias = var.vmname
    extra_arguments = [
      # "-v",
      "--extra-vars",
      "{\"myname\":\"${var.vmname}\"}",
    ]
  }

  # run an "after" InSpec audit
  provisioner "shell-local" {
    pause_before = "30s"
    inline = [
      <<-INSPEC
      inspec exec ${local.inspecs}/dm --key-files=${local.out_dir}/${local.timestamp}.key \
        --target ssh://${build.User}@${build.Host}:${build.Port} --user=${build.User} --sudo \
        --reporter html:${local.out_dir}/${local.timestamp}.azure.after.html \
                  junit:${local.out_dir}/${local.timestamp}.azure.after.junit.xml || echo 'InSpec: '$?
      INSPEC
      ,
      "rm ${local.out_dir}/${local.timestamp}.key",
    ]
  }

  # Deprovision installation user account
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }

  post-processor "manifest" {
    output     = "${local.out_dir}/${var.vmname}-manifest.json"
    strip_path = true
    custom_data = {
      dm_operations_variation = "minimial"
      dm_build_version        = "${var.version}"
      dm_build_tag            = "${var.buildtag}"
      dm_image_group          = "azurevm"
      built_vm_name           = "${local.vmimagefullname}"
    }
  }
}
