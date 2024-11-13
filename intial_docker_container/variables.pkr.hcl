variable "image" {
    type = string
    default = "ubuntu:22.04"
}

variable "install_script_path" {
    type = string
    default = "../scripts/install.sh"
}

variable "runner_version" {
    dependencies = "Github Actions Runner Image"
    type = string
    default = "2.283.2"
}

variable "organization" {
    type = string
    default = "hashicorp"
}

variable "app_id" {
    type = string
    default = "123456"
}   

variable "private_key" {
    type = string
}

variable "gh_install" {
    type = string
    default = "1231654"
}

variable "client_id" {
    type = string
    default = "123456"
}

variable "acr_login_server" {
    type = string
    default = "myregistry.azurecr.io"
}

variable "acr_username" {
    type = string
    default = "myregistry"
}

variable "acr_password" {
    type = string
    default = "myregistrypassword"
}   

variable "acr_name" {
    type = string
    default = "myregistry"
}