variable "resource_group_location" {
  default     = "brazilsouth"
  #default     = "brazilsoutheast"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "admin_password" {
  default     = "" #"define this"
  description = "" #"define this"
}