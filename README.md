# Overview
This module will create aws ec2 vms and security groups in a given vpc (vpc id provided as input variable). It passes through many options from the terraform-aws-security-group and terraform-aws-ec2-instance modules. It can bootstrap vms of both Linux and Windows flavors with a user and password / ssh key if needed. As for outputs this module will prepare outputs for the terraform-linux-apache-guacamole module's client connections. Allowing you to plumb the instances you create directly as connections in apache guacamole. Note you will need to pass the path to a private key if you want to configure ssh key based access from guacamole to the vms. The instances created by this module are intended for workshops and training labs.

#### Supported platform families:
 * DEBIAN
 * RHEL
 * SUSE
 * WINDOWS

## Usage

```hcl

module "aws_instances_ceate" {
  source           = "devoptimist/workshop-server/aws"
  version          = "0.0.1"
  ips              = ["172.16.0.23"]
  instance_count   = 1
  user_name        = "jdoe"
  user_public_key  = "~/.ssh/id_rsa.pub" 
  user_private_key = "~/.ssh/id_rsa"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
|server_count|The number of instances being created|number|0|no|
|user_name|The ssh or winrm user name, used to create users on the target servers, if the create_user variable is set to true|string||yes|
|user_pass|The password to set for the ssh or winrm user|string|""|no|
|user_public_key|If set on linux systems and the create_user variable is true then the content from the file path provided in this variable will be added to the authorized_keys folder of the newly created user|string|""|no|
|user_private_key|This needs to be set to the path of the private key pair that matches the provided public key. it is used when creating the guacamole connection data. Setting it allowd the guacamole client/server to ssh to the targets. can be ignored if using ssh passwords|string|""|no|
|system_type|Choose either linux or windows|string|"linux"|no|
|tags|A map of tags to pass through to the vpc, security group and instances|map|{}|no|
|key_name|The aws key pair name to use for the instance|string||yes|
|server_image_name|The name of the aws ami to use|string||yes|
|server_image_owner|The owner id of the aws ami to use|string||yes|
|server_instance_type|The aws ec2 instance type to use|string|"t2.medium"|no|
|server_root_disk_size|The size in GB of the root disk|number|30|no|
|subnets|A list of subnet ids to associate with the instances|list||yes|
|instance_name|A common name to append to all the instances created in this module|string||yes|
|vpc_id|The ID of a vpc to use|string||yes|
|sec_grp_ingress_rules|A list of security group rules to create taken from the rules data structure of https://github.com/terraform-aws-modules/terraform-aws-security-group|list||yes|
|sec_grp_egress_rules|A list of security group rules to create taken from the rules data structure of https://github.com/terraform-aws-modules/terraform-aws-security-group|list|["all-all"]|no|
|sec_grp_ingress_cidr_blocks|A list of cidr's to apply the ingress rules to|list|["0.0.0.0/0"]|no|
|sec_grp_ingress_with_cidr_blocks|A list of custom security group rules and cidr's to apply the rules to|list|[]|no|
|tmp_path|The location of the temp path to use for downloading installers and executing scripts (linux only)|string|/var/tmp/workstation_install|no|
|chef_product_install_url|The url to use for installing chef products|string|https://www.chef.io/chef/install.sh|no|
|hab_install_url|The url to use for installing chef habitat|string|https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.sh|no|
|choco_install_url|The url to use for installing choco|string|https://chocolatey.org/install.ps1|no|
|install_workstation_tools|Should we install general workstation tools|bool|false|no|
|workstation_hab|Should we install the habitat application|bool|false|no|
|workstation_chef|Should we install chef related products (chef, chefdk, chef-workstation, inspec)|bool|false|no|
|chef_product_name|The name of the chef product to install (chef-workstion, chefdk, inspec, chef)|string|chef-workstation|no|
|chef_product_version|The version of the chef product to install|string|latest|no|
|hab_version|The version of the chef habitat to install|string|latest|no|
