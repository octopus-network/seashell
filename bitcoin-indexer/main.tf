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


# ip & dns record & certificate
resource "google_compute_global_address" "default" {
  name = "bitcoin-indexer-global-address"
}

data "google_dns_managed_zone" "default" {
  name = var.dns_zone
}

resource "google_dns_record_set" "a" {
  name         = "ord.${data.google_dns_managed_zone.default.dns_name}"
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.default.address]
}

resource "google_dns_record_set" "caa" {
  name         = "ord.${data.google_dns_managed_zone.default.dns_name}"
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "CAA"
  ttl          = 300
  rrdatas      = ["0 issue \"pki.goog\""]
}

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "bitcoin-indexer-managed-certificate"
      namespace = var.namespace
    }
    spec = {
      domains = [trimsuffix(google_dns_record_set.a.name, ".")]
    }
  }
}

# gsa ksa
resource "kubernetes_service_account" "default" {
  metadata {
    name        = "ord-ksa"
    namespace   = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = var.gcp_service_account
    }
  }
}

data "google_service_account" "default" {
  account_id = var.gcp_service_account
}

resource "google_service_account_iam_member" "default" {
  service_account_id = data.google_service_account.default.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[${var.namespace}/${kubernetes_service_account.default.metadata.0.name}]"
}

# sts svc ing...
resource "kubernetes_secret" "default" {
  metadata {
    name      = "ord-secret"
    namespace = var.namespace
  }
  data = {
    DATABASE_URL = var.sql_proxy.database
  }
}

resource "kubernetes_stateful_set" "default" {
  metadata {
    name      = "bitcoin-indexer"
    namespace = var.namespace
    labels = {
      app = "bitcoin-indexer"
    }
  }
  spec {
    service_name           = "bitcoin-indexer"
    pod_management_policy  = "Parallel"
    replicas               = 1
    revision_history_limit = 5
    selector {
      match_labels = {
        app = "bitcoin-indexer"
      }
    }
    template {
      metadata {
        labels = {
          app = "bitcoin-indexer"
        }
      }
      spec {
        container {
          name    = "bitcoind"
          image   = var.bitcoind.image
          command = ["bitcoind"]
          args    = [
            "-txindex",
            "--chain=${var.bitcoind.chain}",
            "-server",
            "-port=8333",
            "-rpcallowip=0.0.0.0/0",
            "-rpcport=8332",
            "-rpcbind=0.0.0.0",
            "-rpcuser=${var.bitcoind.rpc.user}",
            "-rpcpassword=${var.bitcoind.rpc.password}",
            "-deprecatedrpc=warnings",
          ]
          port {
            container_port = 8333
          }
          port {
            container_port = 8332
          }
          resources {
            limits = {
              cpu    = var.bitcoind.resources.cpu_limits
              memory = var.bitcoind.resources.memory_limits
            }
            requests = {
              cpu    = var.bitcoind.resources.cpu_requests
              memory = var.bitcoind.resources.memory_requests
            }
          }
          volume_mount {
            name       = "bitcoind-data-volume"
            mount_path = "/bitcoin/.bitcoin"
          }
        }
        container {
          name    = "ord"
          image   = var.ord.image
          command = ["ord"]
          args    = [
            "--chain",
            var.ord.chain,
            "--data-dir",
            "/data",
            "--bitcoin-data-dir",
            "/bitcoind-data",
            "--bitcoin-rpc-username",
            var.ord.bitcoin.rpc_user,
            "--bitcoin-rpc-password",
            var.ord.bitcoin.rpc_pass,
            "--bitcoin-rpc-url",
            "http://127.0.0.1:8332",
            "-n",
            "--index-runes",
            "server",
            "--http"
          ]
          port {
            container_port = 80
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.default.metadata.0.name
            }
          }
          resources {
            limits = {
              cpu    = var.ord.resources.cpu_limits
              memory = var.ord.resources.memory_limits
            }
            requests = {
              cpu    = var.ord.resources.cpu_requests
              memory = var.ord.resources.memory_requests
            }
          }
          volume_mount {
            name       = "ord-data-volume"
            mount_path = "/data"
          }
          volume_mount {
            name       = "bitcoind-data-volume"
            mount_path = "/bitcoind-data"
            read_only = true
          }
          # security_context {
          #   run_as_user = 0
          # }
        }
        container {
          name    = "cloud-sql-proxy"
          image   = var.gce_proxy_image
          command = ["/cloud_sql_proxy", "-instances=${var.gce_proxy_instances}"]
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
        service_account_name = kubernetes_service_account.default.metadata.0.name
        termination_grace_period_seconds = 300
      }
    }
    volume_claim_template {
      metadata {
        name      = "bitcoind-data-volume"
        namespace = var.namespace
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.bitcoind.resources.volume_type
        resources {
          requests = {
            storage = var.bitcoind.resources.volume_size
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name      = "ord-data-volume"
        namespace = var.namespace
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.ord.resources.volume_type
        resources {
          requests = {
            storage = var.ord.resources.volume_size
          }
        }
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

resource "kubernetes_manifest" "default" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "bitcoin-indexer-backendconfig"
      namespace = var.namespace
    }
    spec = {
      healthCheck = {
        type        = "HTTP"
        requestPath = "/status"
        port        = 80
      }
    }
  }
}

resource "kubernetes_service" "default" {
  metadata {
    name      = "bitcoin-indexer"
    namespace = var.namespace
    labels = {
      app  = "bitcoin-indexer"
    }
    annotations = {
      "cloud.google.com/neg"            = "{\"ingress\": true}"
      "cloud.google.com/backend-config" = "{\"default\": \"bitcoin-indexer-backendconfig\"}"
    }
  }
  spec {
    type = "NodePort"
    selector = {
      app = "bitcoin-indexer"
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      name        = "http"
    }
  }
}

resource "kubernetes_ingress_v1" "default" {
  metadata {
    name      = "bitcoin-indexer-ingress"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.default.name
      "networking.gke.io/managed-certificates"      = "bitcoin-indexer-managed-certificate"
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.allow-http"            = "true"
    }
  }
  spec {
    rule {
      host = trimsuffix("ord.${data.google_dns_managed_zone.default.dns_name}", ".")
      http {
        path {
          path = "/*"
          backend {
            service {
              name = "bitcoin-indexer"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
