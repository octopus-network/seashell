
resource "kubernetes_config_map" "default" {
  metadata {
    name      = "${var.chain_name}-validator-config-map"
    namespace = var.namespace
  }
  data = {
    "init.sh"     = file("${path.module}/init.sh")
  }
}

resource "kubernetes_secret" "default" {
  metadata {
    name      = "${var.chain_name}-validator-secret"
    namespace = var.namespace
  }
  data = merge([
    for idx, key in var.keys : {
      for k, v in key :
      "${idx}-${k}" => v
    }
  ]...)
}

resource "kubernetes_stateful_set" "default" {
  metadata {
    name      = "${var.chain_name}-validator"
    namespace = var.namespace
    labels = {
      name  = "${var.chain_name}-validator"
      app   = "validator"
      chain = var.chain_name
    }
  }
  spec {
    service_name           = "${var.chain_name}-validator"
    pod_management_policy  = "Parallel"
    replicas               = var.nodes.replicas
    revision_history_limit = 5
    selector {
      match_labels = {
        name  = "${var.chain_name}-validator"
        app   = "validator"
        chain = var.chain_name
      }
    }
    template {
      metadata {
        labels = {
          name  = "${var.chain_name}-validator"
          app   = "validator"
          chain = var.chain_name
        }
      }
      spec {
        container {
          name    = "validator"
          image   = var.nodes.image
          command = [var.nodes.command]
          args = [
            "start",
            "--rpc.laddr",
            "tcp://0.0.0.0:26657",
            "--home",
            "/data"
          ]
          port {
            container_port = 9090
          }
          port {
            container_port = 26656
          }
          port {
            container_port = 26657
          }
          resources {
            limits = {
              cpu    = var.nodes.resources.cpu_limits
              memory = var.nodes.resources.memory_limits
            }
            requests = {
              cpu    = var.nodes.resources.cpu_requests
              memory = var.nodes.resources.memory_requests
            }
          }
          volume_mount {
            name       = "validator-data-volume"
            mount_path = "/data"
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 26657
            }
            initial_delay_seconds = 10
            timeout_seconds       = 1
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 26657
            }
            initial_delay_seconds = 10
            timeout_seconds       = 1
          }
        }
        init_container {
          name    = "init-configuration"
          image   = var.nodes.image
          command = ["/init.sh", var.nodes.command, var.nodes.moniker, var.chain_id, "/data", var.nodes.keyname, var.nodes.keyring]
          volume_mount {
            name       = "validator-data-volume"
            mount_path = "/data"
          }
          volume_mount {
            name       = "validator-config-volume"
            mount_path = "/init.sh"
            sub_path   = "init.sh"
          }
          volume_mount {
            name       = "validator-secret-volume"
            mount_path = "/keys" # 0-mnemonic 0-node_key ...
          }
        }
        init_container {
          name    = "download-genesis"
          image   = "curlimages/curl"
          args = [
            "-L",
            "-o",
            "/data/config/genesis.json",
            var.nodes.genesis
          ]
          volume_mount {
            name       = "validator-data-volume"
            mount_path = "/data"
          }
          security_context {
            run_as_user = 0
          }
        }
        volume {
          name = "validator-config-volume"
          config_map {
            name         = kubernetes_config_map.default.metadata.0.name
            default_mode = "0555"
          }
        }
        volume {
          name = "validator-secret-volume"
          secret {
            secret_name = kubernetes_secret.default.metadata.0.name
          }
        }
        termination_grace_period_seconds = 300
      }
    }
    volume_claim_template {
      metadata {
        name      = "validator-data-volume"
        namespace = var.namespace
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.nodes.resources.volume_type
        resources {
          requests = {
            storage = var.nodes.resources.volume_size
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].resources
    ]
  }
}

resource "kubernetes_service" "default" {
  count = var.nodes.replicas
  metadata {
    name      = "${var.chain_name}-validator-${count.index}"
    namespace = var.namespace
    labels = {
      name  = "${var.chain_name}-validator"
      app   = "validators"
      chain = var.chain_name
    }
  }
  spec {
    selector = {
      "statefulset.kubernetes.io/pod-name" = "${var.chain_name}-validator-${count.index}"
    }
    session_affinity = "ClientIP"
    port {
      name        = "p2p"
      protocol    = "TCP"
      port        = 26656
      target_port = 26656
    }
    type                    = "LoadBalancer"
    external_traffic_policy = "Local"
  }
}