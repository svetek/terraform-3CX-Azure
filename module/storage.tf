#
# https://expertime.com/blog/a/stockage-nfs-prive-azure/
#   mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp  qplgvyjdfu.blob.core.windows.net:/myk8txgyle/nfs /mnt
# yum install nfs-utils
#6rwyuoxrfs.blob.core.windows.net/nfs
# mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp qplgvyjdfu.blob.core.windows.net:/qplgvyjdfu/backup /var/lib/3cxpbx/Instance1/Data/Backups



#module myip {
#  source  = "4ops/myip/http"
#  version = "1.0.0"
#}


data "http" "ipinfo" {
  url = "https://ipinfo.io"
  method = "GET"
}

#data "dns_a_record_set" "whoami" {
#  host = "resolver1.opendns.com"
#}



resource "random_string" "random" {
  length  = 10
  upper   = false
  special = false
}

resource "azurerm_storage_account" "storage" {
  count = var.storage_for_records ? 1 : 0
  name                     = random_string.random.id
  resource_group_name      = azurerm_resource_group.RG-3CX-GROUP.name
  location                 = azurerm_resource_group.RG-3CX-GROUP.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  account_kind             = "StorageV2"
  nfsv3_enabled             = "true"
  is_hns_enabled            = "true"
  enable_https_traffic_only = "false"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["Metrics", "AzureServices", "Logging"]
#    ip_rules                   = [ module.myip.address ]
    ip_rules                   = [ jsondecode(data.http.ipinfo.response_body).ip ]
    virtual_network_subnet_ids = [azurerm_subnet.pbx-virtual-subnet.id]
    private_link_access {
      endpoint_resource_id = azurerm_subnet.pbx-virtual-subnet.id
    }

  }

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }

#  lifecycle {
#    prevent_destroy = true
#  }

}

resource "azurerm_private_endpoint" "storage_blob" {
  count = var.storage_for_records ? 1 : 0
  name                = "storagenfs-${var.vm_name}"
  location            = azurerm_resource_group.RG-3CX-GROUP.location
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name
  subnet_id           = azurerm_subnet.pbx-virtual-subnet.id

  private_service_connection {
    name                           = "stornfs-${var.vm_name}-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storage[0].id
    subresource_names              = ["blob"]
  }

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }
}

resource "azurerm_storage_container" "nfsv3_backup" {
  count = var.storage_for_records ? 1 : 0
  name                  = "backup"
  storage_account_name  = azurerm_storage_account.storage[0].name
  container_access_type = "private"
  depends_on = [azurerm_private_endpoint.storage_blob]

#  lifecycle {
#    prevent_destroy = true
#  }

}

resource "azurerm_storage_container" "nfsv3_callrecords" {
  count = var.storage_for_records ? 1 : 0
  name                  = "callrecords"
  storage_account_name  = azurerm_storage_account.storage[0].name
  container_access_type = "private"
  depends_on = [azurerm_private_endpoint.storage_blob]

#  lifecycle {
#    prevent_destroy = true
#  }
}

#locals {
#  count = var.storage_for_records ? 1 : 0
#  backups_fstab     = "${split("/", split("//", azurerm_storage_container.nfsv3_backup[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_backup[0].name} /var/lib/3cxpbx/Instance1/Data/Backups auto sec=sys,vers=3,nolock,proto=tcp 0 0"
#  callrecords_fstab = "${split("/", split("//", azurerm_storage_container.nfsv3_callrecords[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_callrecords[0].name} /var/lib/3cxpbx/Instance1/Data/Recordings auto sec=sys,vers=3,nolock,proto=tcp 0 0"
#  backups_mount     = "mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp ${split("/", split("//", azurerm_storage_container.nfsv3_backup[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_backup[0].name} /var/lib/3cxpbx/Instance1/Data/Backups"
#  callrecords_mount = "mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp ${split("/", split("//", azurerm_storage_container.nfsv3_callrecords[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_callrecords[0].name} /var/lib/3cxpbx/Instance1/Data/Recordings"
#
#}



locals {
  backups_fstab     = var.storage_for_records ? "${split("/", split("//", azurerm_storage_container.nfsv3_backup[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_backup[0].name} /var/lib/3cxpbx/Instance1/Data/Backups auto sec=sys,vers=3,nolock,proto=tcp 0 0" : ""
  callrecords_fstab = var.storage_for_records ? "${split("/", split("//", azurerm_storage_container.nfsv3_callrecords[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_callrecords[0].name} /var/lib/3cxpbx/Instance1/Data/Recordings auto sec=sys,vers=3,nolock,proto=tcp 0 0" : ""
  backups_mount     = var.storage_for_records ? "mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp ${split("/", split("//", azurerm_storage_container.nfsv3_backup[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_backup[0].name} /var/lib/3cxpbx/Instance1/Data/Backups" : ""
  callrecords_mount = var.storage_for_records ? "mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp ${split("/", split("//", azurerm_storage_container.nfsv3_callrecords[0].id)[1])[0]}:/${azurerm_storage_account.storage[0].name}/${azurerm_storage_container.nfsv3_callrecords[0].name} /var/lib/3cxpbx/Instance1/Data/Recordings" : ""
}




output "backups_fstab" {
  value = local.backups_fstab
}

output "callrecords_fstab" {
  value = local.callrecords_fstab
}

output "backups_mount" {
  value = local.backups_mount
}

output "callrecords_mount" {
  value = local.callrecords_mount
}

output "your_addr" {
  value = "${jsondecode(data.http.ipinfo.response_body).ip}"
}

resource "null_resource" "mount_storage" {
  count = var.storage_for_records ? 1 : 0
  connection {
    type     = "ssh"
    user     = var.local_admin_username
    private_key = tls_private_key.rsa_vm_ssh.private_key_pem
    host     = data.azurerm_public_ip.pbx-public-ip.ip_address
  }

  provisioner "remote-exec" {
    inline = [

      "sudo sh -c \"echo \\\"@reboot root /bin/bash -c 'sleep 10 && ${local.backups_mount} '\\\" >> /etc/crontab \"",
      "sudo sh -c \"echo \\\"@reboot root /bin/bash -c 'sleep 10 && ${local.callrecords_mount} '\\\" >> /etc/crontab \"",
      "sudo ${local.backups_mount}",
      "sudo ${local.callrecords_mount}",
//      "sudo sh -c \"echo '${local.backups_mount}' >> /etc/fstab\"",
//      "sudo sh -c \"echo '${local.callrecords_mount}' >> /etc/fstab\"",
//      "sudo mount /var/lib/3cxpbx/Instance1/Data/Backups",
//      "sudo mount /var/lib/3cxpbx/Instance1/Data/Recordings",
    ]
  }

  depends_on = [ azurerm_virtual_machine.pbx, azurerm_storage_container.nfsv3_backup, azurerm_storage_container.nfsv3_callrecords ]

}








