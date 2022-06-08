# Azure tenant ID
# az account show --subscription <client tenant id>
tenant_id = ""
subscription_id = ""

# VMS
vm_resource_group_name = "RG-US-3CX-test"
region = "westus"
vm_name = "3CX"

vm_size = "Standard_DS1_v2"
enable_accelerated_networking = true
vm_storage_os_disk_size = 30
local_admin_username = "admin3cx"
vm_timezone = ""

# az vm image list -l westus -p 3cx --all
vm_image_id = ""
vm_publisher = "Debian"
vm_offer = "debian-10"
vm_sku = "10"
vm_version = "latest"

# 3CX original image
#vm_publisher = "3cx-pbx"
#vm_offer = "3cx-pbx"
#vm_sku = "16"
#vm_version = "18.0.1"

managed_disk_sizes = [""]
managed_disk_type = "Standard_LRS"
firewall_allow_voipproviders = ["127.0.0.1"]
firewall_allow_clientip = ["127.0.0.1"]
vault_ad_sec_group="Administrators"