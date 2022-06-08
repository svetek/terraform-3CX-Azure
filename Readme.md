# terraform-3CX-Azure

## How to use
### Terraforms files

Before start on your system will be installed terraform and azure-cli.  
Create directory with name organization and inside new directory create 3 files.

https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt
https://www.terraform.io/downloads

terraform.tfvars

    tenant_id = "<Azure tenant ID>"
    subscription_id = "<Azure subscription ID>"

terraform.tf

    terraform {
        required_providers {
            azurerm = {
                source  = "hashicorp/azurerm"
                version = "3.7.0"
            }
        }
    }
    
    variable "tenant_id" {}
    variable "subscription_id" {}

pbx-3cx.tf

    module "PBX" {
        source          = "git::github.com/svetek/terraform-3CX-Azure.git/module"

        region          = "westus3"
        
        tenant_id       = var.tenant_id
        subscription_id = var.subscription_id
        
        # VMS
        vm_resource_group_name = "RG-${local.resource_name_prefix}-3CX-US-${local.envoriment}"
        vm_name                = "${local.resource_name_prefix}-3CX"
        # VMS
        vm_resource_group_name = "RG-TESTORG-3CX-US-PROD"
        vm_name                = "3CX-TESTORG"
        
        vm_size                 = "Standard_B1s"
        enable_accelerated_networking = false
        vm_storage_os_disk_size = 30
        local_admin_username    = "admin3cx"
        vm_timezone             = ""
        
        # az vm image list -l westus -p 3cx --all
        vm_image_id  = ""
        vm_publisher = "Debian"
        vm_offer     = "debian-10"
        vm_sku       = "10"
        vm_version   = "latest"
        
        managed_disk_sizes = [""]
        managed_disk_type  = "Standard_LRS"

        firewall_allow_voipproviders = ["205.251.***.***/32", "205.251.***.98/32","205.***.***.212/32","205.***.***.194/32"]
        firewall_allow_clientip = ["205.251.***.***"]
        vault_ad_sec_group = "DUO"
    }
    
    output "pbx_installation_ip" {
        value = module.CX.pbx_installation_ip
    }

### Run deploy
You need auth in your original tenant on Azure after that make switch to subscribtion

    az login --use-device-code
    az account list --output table
    az account set --subscription  <Azure subscribtion where you want to deploy>
    az account show
    az account list-locations -o table
    az vm list-skus --size Standard_B --all --output table

Inside directory with terraform files run next command:

    # Download modules and packages for deploy 
    terraform get 
    terraform init 
    # Plan deploy (see what changes planed by deploy scripts)
    terraform plan 
    # Run deploy process 
    terraform apply 

All passwords and ssh keys you can see on Azure vault on resource group 
