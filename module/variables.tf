variable "tenant_id" {}
variable "subscription_id" {}

variable "vm_resource_group_name" {}
variable "region" {
  description = "Region to deploy"
}

variable "vm_name" {}
variable "vm_size" {}
variable "enable_accelerated_networking" {}
variable "vm_storage_os_disk_size" {}
variable "vm_image_id" {}
variable "vm_publisher" {}
variable "vm_offer" {}
variable "vm_sku" {}
variable "vm_version" {}
variable "managed_disk_sizes" {}
variable "managed_disk_type" {}
variable "vm_timezone" {}
variable "local_admin_username" {}
variable "vault_ad_sec_group" {}
variable "firewall_allow_voipproviders" {}
variable "firewall_allow_clientip" {}

variable "storage_for_records" {}
variable "email_notification" {}

