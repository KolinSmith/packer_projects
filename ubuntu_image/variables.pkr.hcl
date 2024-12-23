variable "clientId" {
  type    = string
  default = null
}

variable "clientSecret" {
  type    = string
  default = null
}

variable "tenantId" {
  type    = string
  default = null
}

variable "subscriptionId" {
  type    = string
  default = null
}

variable "resourceGroupName" {
  type    = string
  default = null
}

variable "location" {
  type    = string
  default = null
}

variable "virtualMachineSize" {
  type    = string
  default = null
}

variable "buildtag" {
  type    = string
  default = "manual"
}

variable "version" {
  type    = string
  default = "test"
}

variable "vmname" {
  type    = string
  default = "azure-ubuntu-generic"
}