########### misc settings ########################

variable "templatefile" {
  description = "A string of commands used to bootstrap the instance" 
  type        = string
  default     = ""
}

########### connection settings ##################

variable "user_name" {
  description = "The ssh or winrm user name, used to create users on the target servers, if the create_user variable is set to true"
  type        = string
}

variable "user_pass" {
  description = "The password to set for the ssh or winrm user"
  type        = string
  default     = ""
}

variable "create_user" {
  description = "Should the user be created"
  default     = false
}

variable "user_public_key" {
  description = "If set on linux systems and the create_user variable is true then the content from the file path provided in this variable will be added to the authorized_keys folder of the newly created user"
  type        = string
  default     = ""
}

variable "user_private_key" {
  description = "This needs to be set to the path of the private key pair that matches the provided public key. it is used when creating the guacamole connection data. Setting it allowd the guacamole client/server to ssh to the targets. can be ignored if using ssh passwords"
  type    = string
  default = ""
}

variable "system_type" {
  description = "Choose either linux or windows"
  type        = string
  default     = "linux"
}

########### aws settings #########################

variable "tags" {
  description = "A map of tags to pass through to the vpc, security group and instances"
  type        = "map"
  default     = {}
}

########### ec2 instance settings ################

variable "key_name" {
  description = "The key name to use for the instance"
  type        = string
}

variable "server_image_name" {
  description = "The name of the aws ami to use"
  type        = string
}

variable "server_image_owner" {
  description = "The owner id of the aws ami to use"
  type        = string
}

variable "server_instance_type" {
  description = "The aws ec2 instance type to use"
  type        = string
  default     = "t2.medium"
}

variable "server_root_disk_size" {
  description = "The size in GB of the root disk"
  type        = number
  default     = 30
}

variable "server_count" {
  description = "The nuber of servers to create"
  type        = number
  default     = 1
}

variable "subnets" {
  description = "A list of subnets to associate with the instances"
  type        = list(string)
}

variable "instance_name" {
  description = "A common name to append to all the instances created in this module"
  type        = string
}

########### vpc settings #########################

variable "vpc_id" {
  description = "The ID of a vpc to use"
  type        = string
}

########### security group settings ##############

variable "sec_grp_ingress_rules" {
  description = "A list of security group rules to create taken from the rules data structure of https://github.com/terraform-aws-modules/terraform-aws-security-group"
  type        = list(string)
}

variable "sec_grp_egress_rules" {
  description = "A list of security group rules to create taken from the rules data structure of https://github.com/terraform-aws-modules/terraform-aws-security-group"
  type        = list(string)
  default     = ["all-all"]
}

variable "sec_grp_ingress_cidr_blocks" {
  description = "A list of cidr's to apply the ingress rules to"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "sec_grp_ingress_with_cidr_blocks" {
  description = "A list of custom security group rules and cidr's to apply the rules to"
  type        = list(map(string))
  default     = []
}
