#
# https://expertime.com/blog/a/stockage-nfs-prive-azure/
#   mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp  qplgvyjdfu.blob.core.windows.net:/myk8txgyle/nfs /mnt
# yum install nfs-utils
#6rwyuoxrfs.blob.core.windows.net/nfs
# mount -t nfs -o sec=sys,vers=3,nolock,proto=tcp qplgvyjdfu.blob.core.windows.net:/qplgvyjdfu/backup /var/lib/3cxpbx/Instance1/Data/Backups



module myip {
  source  = "4ops/myip/http"
  version = "1.0.0"
}

resource "random_string" "random" {
  length  = 10
  upper   = false
  special = false
}

resource "azurerm_storage_account" "storage" {
  name                     = random_string.random.id
  resource_group_name      = azurerm_resource_group.RG-3CX-GROUP.name
  location                 = azurerm_resource_group.RG-3CX-GROUP.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  nfsv3_enabled             = "true"
  is_hns_enabled            = "true"
  enable_https_traffic_only = "false"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["Metrics", "AzureServices", "Logging"]
    ip_rules                   = [ module.myip.address ]
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

  lifecycle {
    prevent_destroy = true
  }

}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "storagenfs-${var.vm_name}"
  location            = azurerm_resource_group.RG-3CX-GROUP.location
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name
  subnet_id           = azurerm_subnet.pbx-virtual-subnet.id

  private_service_connection {
    name                           = "stornfs-${var.vm_name}-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
  }

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }
}

resource "azurerm_storage_container" "nfsv3_backup" {
  name                  = "backup"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
  depends_on = [azurerm_private_endpoint.storage_blob]

  lifecycle {
    prevent_destroy = true
  }

}

resource "azurerm_storage_container" "nfsv3_callrecords" {
  name                  = "callrecords"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
  depends_on = [azurerm_private_endpoint.storage_blob]

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  backups_mount     = "${split("/", split("//", azurerm_storage_container.nfsv3_backup.id)[1])[0]}:/${azurerm_storage_account.storage.name}/${azurerm_storage_container.nfsv3_backup.name} /var/lib/3cxpbx/Instance1/Data/Backups auto sec=sys,vers=3,nolock,proto=tcp 0 0"
  callrecords_mount = "${split("/", split("//", azurerm_storage_container.nfsv3_callrecords.id)[1])[0]}:/${azurerm_storage_account.storage.name}/${azurerm_storage_container.nfsv3_callrecords.name} /var/lib/3cxpbx/Instance1/Data/Recordings auto sec=sys,vers=3,nolock,proto=tcp 0 0"
}


#output "backups_mount" {
#  value = backups_
#}
#
#output "callrecords_mount" {
#  value = "${split("/", split("//", azurerm_storage_container.nfsv3_callrecords.id)[1])[0]}:/${azurerm_storage_account.storage.name}/${azurerm_storage_container.nfsv3_callrecords.name} /var/lib/3cxpbx/Instance1/Data/Recordings auto sec=sys,vers=3,nolock,proto=tcp 0 0"
#}

resource "null_resource" "mount_storage" {

  connection {
    type     = "ssh"
    user     = var.local_admin_username
    private_key = tls_private_key.rsa_vm_ssh.private_key_pem
    host     = azurerm_public_ip.pbx-public-ip.ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sh -c \"echo '${local.backups_mount}' >> /etc/fstab\"",
      "sudo sh -c \"echo '${local.callrecords_mount}' >> /etc/fstab\"",
      "sudo mount /var/lib/3cxpbx/Instance1/Data/Backups",
      "sudo mount /var/lib/3cxpbx/Instance1/Data/Recordings",
    ]
  }

  depends_on = [ azurerm_virtual_machine.pbx, azurerm_storage_container.nfsv3_backup, azurerm_storage_container.nfsv3_callrecords ]

}








