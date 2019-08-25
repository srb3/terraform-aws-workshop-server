resource "random_id" "hash" {
  byte_length = 4
}

locals {
  prefix    = "${lookup(var.tags, "prefix", "changeme")}-${random_id.hash.hex}"
  bootstrap = var.templatefile != "" ? var.templatefile : templatefile("${path.module}/templates/bootstrap.sh", {
    create_user      = var.create_user,
    user_name        = var.user_name,
    user_pass        = var.user_pass,
    user_public_key  = var.user_public_key != "" ? file(var.user_public_key) : var.user_public_key,
    system_type      = var.system_type
  })
}

module "sg" {
  source                   = "terraform-aws-modules/security-group/aws"
  version                  = "3.0.1"
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
  version                     = "2.0.0"
  name                        = "${local.prefix}-${var.instance_name}"
  instance_count              = var.server_count
  ami                         = data.aws_ami.server_image.id
  instance_type               = var.server_instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  monitoring                  = false
  vpc_security_group_ids      = ["${module.sg.this_security_group_id}"]
  subnet_ids                  = var.subnets
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
  override_special = "/@\" "
}

### these are outputs created in case you want to plug guacamole-client
# into the created vms

locals {
  sec_type = var.user_private_key == "" ? "password" : "private-key"
  sec_value = local.sec_type == "password" ? var.user_pass : file(var.user_private_key)
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
        "${local.sec_type}" = local.sec_value
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
        "${local.sec_type}" = local.sec_value
      }
    }
  ]
  connections = var.system_type == "linux" ? local.lin_connections : local.win_connections
}
