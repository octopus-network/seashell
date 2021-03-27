resource "random_id" "this" {
  byte_length = 8
}

resource "null_resource" "workspace" {
  triggers = {
    workspace = random_id.this.hex
  }

  provisioner "local-exec" {
    command = <<-EOT
mkdir -p ${random_id.this.hex}/ssh
mkdir -p ${random_id.this.hex}/p2p
EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.workspace}"
  }
}

resource "null_resource" "ssh-key" {
  triggers = {
    ssh_key = random_id.this.hex
  }

  provisioner "local-exec" {
    command = "ssh-keygen -t rsa -P '' -f ${random_id.this.hex}/ssh/${random_id.this.hex} <<<y"
  }
  depends_on = [null_resource.workspace]
}

resource "null_resource" "p2p-key" {
  triggers = {
    ssh_key = random_id.this.hex
  }

  provisioner "local-exec" {
    command = "/bin/bash generate-node-key.sh ${var.bootnodes} ${random_id.this.hex}/p2p"
  }
  depends_on = [null_resource.workspace]
}


module "cloud" {
  source            = "./multi-cloud/aws"

  access_key        = var.access_key
  secret_key        = var.secret_key
  instance_count    = var.bootnodes
  public_key_file   = abspath("${random_id.this.hex}/ssh/${random_id.this.hex}.pub")
  module_depends_on = [null_resource.ssh-key]
}

resource "local_file" "ansible-inventory" {
  content    = templatefile("${path.module}/ansible/ansible_inventory.tpl", {
    public_ips = module.cloud.public_ip_address,
    peer_ids   = tolist(fileset("${random_id.this.hex}/p2p", "12D3*"))
  })
  filename   = "${random_id.this.hex}/ansible_inventory"
  depends_on = [null_resource.p2p-key]
}

module "ansible" {
  source = "github.com/insight-infrastructure/terraform-ansible-playbook.git"

  ips                = module.cloud.public_ip_address
  playbook_file_path = "${path.module}/ansible/bootnodes.yml"
  user               = var.user
  private_key_path   = "${random_id.this.hex}/ssh/${random_id.this.hex}"
  inventory_file     = local_file.ansible-inventory.filename
  playbook_vars      = {
    workspace     = abspath(random_id.this.hex)
    chain_spec    = var.chain_spec
    rpc_port      = var.rpc_port 
    ws_port       = var.ws_port
    p2p_port      = var.p2p_port
    base_image    = var.base_image
    start_cmd     = var.start_cmd
    wasm_url      = var.wasm_url
    wasm_checksum = var.wasm_checksum
  }
  # module_depends_on = [local_file.ansible-inventory]
}
