provider "google" {
  project = var.project
  region  = var.region
}

data "google_client_config" "default" {
}

data "google_container_cluster" "default" {
  name     = var.cluster
  location = var.region
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.default.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.default.master_auth[0].cluster_ca_certificate)
}

module "relayer" {
  source = "./relayer"

  for_each                 = var.relays
  appchain_id              = each.value.appchain_id
  appchain_endpoint        = each.value.appchain_endpoint
  relay_contract_id        = each.value.relay_contract_id
  relayer_private_key_name = each.value.relayer_private_key_name
  relayer_private_key_ver  = each.value.relayer_private_key_ver
  relayer_image            = each.value.relayer_image
  near_node_url            = var.near.node_url
  near_wallet_url          = var.near.wallet_url
  near_helper_url          = var.near.helper_url
}
