# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
  }
  tenant_id = "${var.tenant_id}"
  subscription_id = "${var.subscription_id}"
}

# Create Vault
data "azurerm_client_config" "current" {}

data "azuread_group" "vaultgroup" {
  display_name     = var.vault_ad_sec_group
  security_enabled = true
}

#output "object_id" {
#  value = data.azuread_group.vaultgroup.object_id
#}


resource "random_string" "random_prefix_vault_name" {
  length           = 5
  special          = false
  override_special = "/@£$"
}

resource "azurerm_key_vault" "pbx_vault" {
  name                       = "v-${lower(var.vm_name)}-${random_string.random_prefix_vault_name.result}"
  location                   = azurerm_resource_group.RG-3CX-GROUP.location
  resource_group_name        = azurerm_resource_group.RG-3CX-GROUP.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  enabled_for_disk_encryption = true
  enable_rbac_authorization   = true
  enabled_for_deployment      = true
  purge_protection_enabled    = false

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_access_policy" "pbx_vault_sp_access" {
  key_vault_id = azurerm_key_vault.pbx_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_group.vaultgroup.object_id

  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"
  ]

  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
  ]

  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update"
  ]
  depends_on = [azurerm_key_vault.pbx_vault]
}

resource "azurerm_role_assignment" "role-secret-officer" {
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_group.vaultgroup.object_id
  scope                = azurerm_key_vault.pbx_vault.id

  depends_on = [azurerm_key_vault_access_policy.pbx_vault_sp_access]

}

resource "azurerm_role_assignment" "role-crypto-officer" {
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azuread_group.vaultgroup.object_id
  scope                = azurerm_key_vault.pbx_vault.id

  depends_on = [azurerm_key_vault_access_policy.pbx_vault_sp_access]

}

resource "random_password" "pbx-ssh-password" {
  length           = 20
  special          = true
}

resource "random_password" "pbx-web-password" {
  length           = 20
  special          = true
}

resource "random_password" "pbx-superset-password" {
  length           = 20
  special          = true
}

#output "random_password_result" {
#  value = random_password.pbx-local-password.result
#  sensitive = true
#}

resource "azurerm_key_vault_secret" "save_password_vault" {
  name         = "${var.vm_name}-${var.local_admin_username}"
  value        = "${random_password.pbx-ssh-password.result}"
  key_vault_id = azurerm_key_vault.pbx_vault.id

  depends_on = [azurerm_role_assignment.role-secret-officer]

  lifecycle {
    prevent_destroy = true
  }
}


# No metods for export private keys
#resource "azurerm_key_vault_key" "rsa_vm_ssh" {
#  name         = "${var.vm_name}-rsa-key"
#  key_vault_id = azurerm_key_vault.pbx_vault.id
#  key_type     = "RSA"
#  key_size     = 2048
#
#  key_opts = [
#    "decrypt",
#    "encrypt",
#    "sign",
#    "unwrapKey",
#    "verify",
#    "wrapKey",
#  ]
#
#  depends_on = [ azurerm_role_assignment.role-crypto-officer ]
#}

resource "tls_private_key" "rsa_vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "rsa_vm_ssh_private" {
  name         = "${var.vm_name}-ssh-private"
  value        = base64encode(tls_private_key.rsa_vm_ssh.private_key_pem)
  key_vault_id = azurerm_key_vault.pbx_vault.id
  content_type = "Need Base64 Decoded"
  depends_on = [azurerm_role_assignment.role-secret-officer]

  lifecycle {
    prevent_destroy = true
  }

}

resource "azurerm_key_vault_secret" "rsa_vm_ssh_public" {
  name         = "${var.vm_name}-ssh-public"
  value        = base64encode(tls_private_key.rsa_vm_ssh.public_key_openssh)
  key_vault_id = azurerm_key_vault.pbx_vault.id
  content_type = "Need Base64 Decoded"

  depends_on = [azurerm_role_assignment.role-secret-officer]

  lifecycle {
    prevent_destroy = true
  }

}

output "ssh_public_key" {
  value = azurerm_key_vault_secret.rsa_vm_ssh_private
}

resource "azurerm_key_vault_secret" "save_password_web_vault" {
  name         = "${var.vm_name}-webadmin"
  value        = "${random_password.pbx-web-password.result}"
  key_vault_id = azurerm_key_vault.pbx_vault.id

  depends_on = [azurerm_role_assignment.role-secret-officer]

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "save_password_superset_vault" {
  name         = "${var.vm_name}-superset-admin"
  value        = "${random_password.pbx-superset-password.result}"
  key_vault_id = azurerm_key_vault.pbx_vault.id

  depends_on = [azurerm_role_assignment.role-secret-officer]

  lifecycle {
    prevent_destroy = true
  }
}

# Create a resource group
resource "azurerm_resource_group" "RG-3CX-GROUP" {
  name     = "${var.vm_resource_group_name}"
  location = "${var.region}"

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "pbx-virtual-network" {
  name                = "${var.vm_name}-Vnet"
  address_space       = ["10.0.0.0/29"]
  location            = azurerm_resource_group.RG-3CX-GROUP.location
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }
}

# Create subnet
resource "azurerm_subnet" "pbx-virtual-subnet" {
  name                 = "${var.vm_name}-Subnet"
  resource_group_name  = azurerm_resource_group.RG-3CX-GROUP.name
  virtual_network_name = azurerm_virtual_network.pbx-virtual-network.name
  address_prefixes       = ["10.0.0.0/29"]
  service_endpoints    = ["Microsoft.Storage"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_network_security_group" "pbx-nsg" {
  name                = "${var.vm_name}-NetworkSecurityGroup"
  location            = azurerm_resource_group.RG-3CX-GROUP.location
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name

  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

#  security_rule {
#    name                       = "IPs_TCP"
#    priority                   = 1005
#    direction                  = "Inbound"
#    access                     = "Allow"
#    protocol                   = "*"
#    source_port_range          = "*"
#    destination_port_range     = "*"
#    source_address_prefix      = "*"
#    destination_address_prefix = "*"
#  }

  security_rule {
    name                       = "IPs_BANDWIDTH-${var.firewall_allow_bandwidth_ip_1}"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "${var.firewall_allow_bandwidth_ip_1}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "IPs_BANDWIDTH-${var.firewall_allow_bandwidth_ip_2}"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "${var.firewall_allow_bandwidth_ip_2}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5001_TCP"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5001"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5090_TCP"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5090_UDP"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5060_TCP"
    priority                   = 1040
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5060_UDP"
    priority                   = 1050
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5060"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5061_TCP"
    priority                   = 1060
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5061"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5015_TCP"
    priority                   = 1070
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5015"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "443_TCP"
    priority                   = 1080
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "5062_TCP"
    priority                   = 1090
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5062"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "10600_10998_UDP"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "10600-10998"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "9000_9398_UDP"
    priority                   = 1110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "9000-9398"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "8088_TCP"
    priority                   = 1120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8088"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pbx-sec-group-association" {
  subnet_id                 = azurerm_subnet.pbx-virtual-subnet.id
  network_security_group_id = azurerm_network_security_group.pbx-nsg.id
}

resource "azurerm_public_ip" "pbx-public-ip" {
  name                = "${var.vm_name}-public-Ip"
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name
  location            = azurerm_resource_group.RG-3CX-GROUP.location
  allocation_method   = "Static"
#  domain_name_label = "cx1"
}

output "pbx_public_ip" {
  value = "${azurerm_public_ip.pbx-public-ip.ip_address}"

}

resource "azurerm_network_interface" "pbx-network-interface" {
  name                      = "${var.vm_name}-nic"
  location                  = "${var.region}"
  resource_group_name       = azurerm_resource_group.RG-3CX-GROUP.name
  enable_accelerated_networking = "${var.enable_accelerated_networking}"
  dns_servers = ["8.8.8.8","1.1.1.1"]

  ip_configuration {
    name                     = "${var.vm_name}-nic-01"
    subnet_id                = azurerm_subnet.pbx-virtual-subnet.id
    public_ip_address_id     = azurerm_public_ip.pbx-public-ip.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    Company = "SVETEK"
    Name = "3CX VM MODULE"
    environment = "PROD"
  }

}

resource "azurerm_virtual_machine" "pbx" {
  name                  = "${var.vm_name}"
  location              = "${var.region}"
  resource_group_name   = azurerm_resource_group.RG-3CX-GROUP.name
  network_interface_ids = [azurerm_network_interface.pbx-network-interface.id]
  vm_size               = "${var.vm_size}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id        = "${var.vm_image_id}"
    publisher = "${var.vm_publisher}"
    offer     = "${var.vm_offer}"
    sku       = "${var.vm_sku}"
    version   = "${var.vm_version}"
  }

  storage_os_disk {
    name              = "${lower(var.vm_name)}-OSDISK-1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = "${var.vm_storage_os_disk_size}"
  }

#  storage_data_disk {
#    name              = "${lower(var.vm_name)}-RECDISK-1"
#    caching           = "None"
#    create_option     = "Empty"
#    managed_disk_type = "Standard_LRS"
#    disk_size_gb      = "10"
#    lun               = 1
#  }

  os_profile {
    computer_name  = "${var.vm_name}-1"
    admin_username = "${var.local_admin_username}"
    admin_password = "${random_password.pbx-ssh-password.result}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = tls_private_key.rsa_vm_ssh.public_key_openssh
      path     = "/home/${var.local_admin_username}/.ssh/authorized_keys"
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

#data "azurerm_subscription" "primary" {
#}
#
#data "azurerm_role_definition" "owner" {
#  name  = "owner"
#  scope = data.azurerm_subscription.primary.id
#}

resource "azurerm_monitor_action_group" "ag" {
  name                = "support_group"
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name
  short_name          = "support_g"


  arm_role_receiver {
    name                    = "owner"
    role_id                 = "de139f84-1756-47ae-9be6-808fbbe84772"
#    role_id = data.azurerm_role_definition.owner.role_definition_id
    use_common_alert_schema = true
  }

  email_receiver {
    name                    = "support"
    email_address           = "help@svetek.com"
    use_common_alert_schema = true
  }

}

resource "azurerm_monitor_metric_alert" "alert" {
  name                = "3cx_cpu_high"
  resource_group_name = azurerm_resource_group.RG-3CX-GROUP.name
  scopes              = [azurerm_virtual_machine.pbx.id]
  description         = "description"
  target_resource_type = "Microsoft.Compute/virtualMachines"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}

resource "azurerm_virtual_machine_extension" "deploy_3cx" {
  name                 = "hostname"
  virtual_machine_id   =  azurerm_virtual_machine.pbx.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "fileUris": ["${join("\",\"", ["https://raw.githubusercontent.com/svetek/terraform-3CX-Azure/main/module/scripts/deploy.sh"])}"],
        "commandToExecute": "sudo ./deploy.sh -p '${random_password.pbx-superset-password.result}'"
    }
SETTINGS

}

output "pbx_installation_ip" {
  value = "http://${azurerm_public_ip.pbx-public-ip.ip_address}:5015"
}


#output "pbx_installation_url" {
#  value = "http://${azurerm_public_ip.pbx-public-ip.fqdn}:5015"
#}

