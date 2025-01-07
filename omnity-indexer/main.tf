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

resource "kubernetes_config_map" "default" {
  metadata {
    name      = "omnity-indexer-config-map"
    namespace = var.namespace
  }
  data = {
    DFX_NETWORK                        = var.DFX_NETWORK
    OMNITY_HUB_CANISTER_ID             = var.OMNITY_HUB_CANISTER_ID
    OMNITY_CUSTOMS_BITCOIN_CANISTER_ID = var.OMNITY_CUSTOMS_BITCOIN_CANISTER_ID
    OMNITY_ROUTES_ICP_CANISTER_ID      = var.OMNITY_ROUTES_ICP_CANISTER_ID
    BEVM_CHAIN_ID                      = var.BEVM_CHAIN_ID
    BITLAYER_CHAIN_ID                  = var.BITLAYER_CHAIN_ID
    XLAYER_CHAIN_ID                    = var.XLAYER_CHAIN_ID
    BSQUARE_CHAIN_ID                   = var.BSQUARE_CHAIN_ID
    MERLIN_CHAIN_ID                    = var.MERLIN_CHAIN_ID
    BOB_CHAIN_ID                       = var.BOB_CHAIN_ID
    ROOTSTOCK_CHAIN_ID                 = var.ROOTSTOCK_CHAIN_ID
    BITFINITY_CHAIN_ID                 = var.BITFINITY_CHAIN_ID
    AILAYER_CHAIN_ID                   = var.AILAYER_CHAIN_ID
    OMNITY_CUSTOMS_ICP_CANISTER_ID     = var.OMNITY_CUSTOMS_ICP_CANISTER_ID
    OSMOSIS_TEST5_CHAIN_ID             = var.OSMOSIS_TEST5_CHAIN_ID
    OSMOSIS1_CHAIN_ID                  = var.OSMOSIS1_CHAIN_ID
    OMNITY_ROUTES_SOLANA_CANISTER_ID   = var.OMNITY_ROUTES_SOLANA_CANISTER_ID
    EVM_CANISTER_ID                    = var.EVM_CANISTER_ID
    OMNITY_CUSTOMS_BITCOIN_BRC20_CANISTER_ID = var.OMNITY_CUSTOMS_BITCOIN_BRC20_CANISTER_ID
    CORE_CANISTER_ID                   = var.CORE_CANISTER_ID
    TON_CANISTER_ID                    = var.TON_CANISTER_ID
    OMNITY_CUSTOMS_DOGECOIN_CANISTER_ID= var.OMNITY_CUSTOMS_DOGECOIN_CANISTER_ID
    SUI_CANISTER_ID                    = var.SUI_CANISTER_ID
  }
}

resource "kubernetes_secret" "default" {
  metadata {
    name      = "omnity-indexer-secret"
    namespace = var.namespace
  }
  data = {
    DATABASE_URL = var.sql_proxy.database
    DFX_IDENTITY = var.DFX_IDENTITY
  }
}

resource "kubernetes_deployment" "default" {
  metadata {
    name      = "omnity-indexer"
    namespace = var.namespace
    labels = {
      app = "omnity-indexer"
    }
  }
  spec {
    replicas               = 1
    revision_history_limit = 5
    selector {
      match_labels = {
        app = "omnity-indexer"
      }
    }
    template {
      metadata {
        labels = {
          app = "omnity-indexer"
        }
      }
      spec {
        container {
          name    = "omnity-indexer"
          image   = var.omnity_indexer.image
          command = ["/bin/omnity_indexer_sync"]
          env_from {
            config_map_ref {
              name = kubernetes_config_map.default.metadata.0.name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.default.metadata.0.name
            }
          }
          resources {
            limits = {
              cpu    = var.omnity_indexer.resources.cpu_limits
              memory = var.omnity_indexer.resources.memory_limits
            }
            requests = {
              cpu    = var.omnity_indexer.resources.cpu_requests
              memory = var.omnity_indexer.resources.memory_requests
            }
          }
        }
        container {
          name    = "cloud-sql-proxy"
          image   = var.sql_proxy.image
          command = ["/cloud_sql_proxy", "-instances=${var.sql_proxy.instances}"]
          resources {
            limits = {
              cpu    = var.sql_proxy.resources.cpu_limits
              memory = var.sql_proxy.resources.memory_limits
            }
            requests = {
              cpu    = var.sql_proxy.resources.cpu_requests
              memory = var.sql_proxy.resources.memory_requests
            }
          }
          security_context {
            run_as_non_root = true
          }
        }
        service_account_name             = "ord-ksa"
        termination_grace_period_seconds = 300
      }
    }
  }
  lifecycle {
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].resources,
      spec[0].template[0].spec[0].container[1].resources,
    ]
  }
}

