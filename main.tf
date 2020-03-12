resource "random_id" "hash" {
  byte_length = 4
}

locals {
  prefix    = "${lookup(var.tags, "prefix", "changeme")}-${random_id.hash.hex}"
  hostname  = var.ip_hostname ? var.instance_name : "${local.prefix}-${var.instance_name}"
  bootstrap = var.templatefile != "" ? var.templatefile : templatefile("${path.module}/templates/bootstrap.sh", {
    create_user               = var.create_user,
    user_name                 = var.user_name,
    user_pass                 = var.user_pass,
    user_public_key           = var.user_public_key != "" ? file(var.user_public_key) : var.user_public_key,
    system_type               = var.system_type,
    tmp_path                  = var.tmp_path,
    chef_product_install_url  = var.chef_product_install_url,
    hab_install_url           = var.hab_install_url,
    workstation_chef          = var.workstation_chef,
    chef_product_name         = var.chef_product_name,
    chef_product_version      = var.chef_product_version,
    workstation_hab           = var.workstation_hab,
    hab_version               = var.hab_version,
    install_workstation_tools = var.install_workstation_tools,
    choco_install_url         = var.choco_install_url,
    hostname                  = local.hostname
    helper_files              = var.helper_files,
    ip_hostname               = var.ip_hostname,
    set_hostname              = var.set_hostname,
    populate_hosts            = var.populate_hosts,
    wsl                       = var.wsl,
    kb_uk                     = var.kb_uk
  })
}

module "sg" {
  source                   = "terraform-aws-modules/security-group/aws"
  version                  = "3.2.0"
  name                     = "${local.prefix}-security-group"
  description              = "security group ${local.prefix}"
  vpc_id                   = var.vpc_id
  ingress_rules            = var.sec_grp_ingress_rules
  egress_rules             = var.sec_grp_egress_rules
  ingress_with_cidr_blocks = var.sec_grp_ingress_with_cidr_blocks
  ingress_cidr_blocks      = var.sec_grp_ingress_cidr_blocks
  tags                     = var.tags
}

data "aws_ami" "server_image" {
  most_recent = true
  owners      = [var.server_image_owner]
  filter {
    name      = "name"
    values    = [var.server_image_name]
  }
}

module "server" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "2.8.0"
  name                        = "${local.prefix}-${var.instance_name}"
  instance_count              = var.server_count
  ami                         = data.aws_ami.server_image.id
  instance_type               = var.server_instance_type
  associate_public_ip_address = var.public_ip
  key_name                    = var.key_name
  monitoring                  = false
  vpc_security_group_ids      = ["${module.sg.this_security_group_id}"]
  subnet_ids                  = var.subnets
  get_password_data           = var.get_password_data
  root_block_device = [{
    volume_type = "gp2"
    volume_size = var.server_root_disk_size
  }]
  tags                        = var.tags
  user_data                   = local.bootstrap
}

resource "random_string" "guacamole_access_password" {
  length           = 8
  special          = true
}

### these are outputs created in case you want to plug guacamole-client
# into the created vms

locals {
  user_private_keys = var.user_private_key != "" ? [ for i in range(var.server_count) : var.user_private_key ] : []
  user_passes = var.get_password_data == true ? [ for i in range(var.server_count) : rsadecrypt(module.server.password_data[i], file(var.user_private_key))] : [ for i in range(var.server_count) : var.user_pass ]
  sec_type = var.user_private_key != "" ? var.get_password_data == true ? "password" : var.system_type == "windows" ? "password" : "private-key" : "password"
  sec_value = local.sec_type == "password" ? [ for i in range(var.server_count) :  local.user_passes[i] ] : [ for i in range(var.server_count) : file(var.user_private_key) ]

#  sec_type = var.user_private_key == "" ? "password" : "private-key"
#  sec_value = local.sec_type == "password" ? var.user_pass : file(var.user_private_key)

  output_hostnames = [
    for ip in module.server.private_ip :
      "${local.hostname}-${replace(ip, ".", "-")}"
  ]

  win_connections = [
    for ip in module.server.public_ip :
    { 
      "name"     = "${local.prefix}-${var.instance_name}-${index(module.server.public_ip, ip)}",
      "protocol" = "rdp",
      "params"   = {
        "security"          = "any",
        "ignore-cert"       = "true",
        "hostname"          = module.server.private_ip[index(module.server.public_ip, ip)],
        "port"              = 3389,
        "username"          = var.user_name,
        "${local.sec_type}" = local.sec_value[index(module.server.public_ip, ip)]
      }
    }
  ]
  lin_connections = [
    for ip in module.server.public_ip :
    { 
      "name"     = "${local.prefix}-${var.instance_name}-${index(module.server.public_ip, ip)}",
      "protocol" = "ssh",
      "params"   = {
        "color-scheme"      = "green-black",
        "hostname"          = module.server.private_ip[index(module.server.public_ip, ip)],
        "port"              = 22,
        "username"          = var.user_name,
        "${local.sec_type}" = local.sec_value[index(module.server.public_ip, ip)]
      }
    }
  ]
  connections = var.system_type == "linux" ? local.lin_connections : local.win_connections
}
