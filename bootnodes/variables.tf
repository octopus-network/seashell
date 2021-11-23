
variable "chain_name" {
  description = ""
  type        = string
}

variable "chain_spec" {
  description = "Specifies which chain specification to use"
  type        = string
}

variable "bootnodes" {
  description = "Count of bootnodes"
  type        = number
  # default     = 4
}

variable "p2p_port" {
  description = "Specifies the port that your node will listen for p2p traffic on"
  type        = string
  default     = 30333
}

variable "base_image" {
  description = "Pull base image from  Docker Hub or a different registry"
  type        = string
}

variable "start_cmd" {
  description = "No need to set if ENTRYPOINT is used, otherwise fill in the start command"
  type        = string
  default     = ""
}

variable "keys_octoup" {
  description = "Keys generated by octokey. https://github.com/octopus-network/octokey"
  type        = string
  default     = ""
}

# gke
variable "project" {
  description = "Project"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "cluster" {
  description = "Cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace"
  type        = string
  default     = "default" # devnet / testnet / mainnet
}

variable "cpu_requests" {
  description = ""
  type        = string
  default     = "500m"
}

variable "cpu_limits" {
  description = ""
  type        = string
  default     = "500m"
}

variable "memory_requests" {
  description = ""
  type        = string
  default     = "1000Mi"
}

variable "memory_limits" {
  description = ""
  type        = string
  default     = "1000Mi"
}

variable "volume_type" {
  description = ""
  type        = string
  default     = "standard-rwo"
}

variable "volume_size" {
  description = ""
  type        = string
  default     = "10Gi"
}
