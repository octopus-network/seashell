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
  default     = "default" # testnet / mainnet
}


variable "omnity_indexer" {
  description = "omnity indexer"
  type = object({
    image = string
    resources = object({
      cpu_requests    = string
      cpu_limits      = string
      memory_requests = string
      memory_limits   = string
      volume_type     = string
      volume_size     = string
    })
  })
}

variable "sql_proxy" {
  description = "sql proxy"
  type = object({
    image     = string
    instances = string
    database  = string
    resources = object({
      cpu_requests    = string
      cpu_limits      = string
      memory_requests = string
      memory_limits   = string
    })
  })
}

variable "DFX_NETWORK" {
  description = "DFX_NETWORK"
  type        = string
}

variable "DFX_IDENTITY" {
  description = "DFX_IDENTITY"
  type        = string
  sensitive   = true
}

variable "OMNITY_HUB_CANISTER_ID" {
  description = "OMNITY_HUB_CANISTER_ID"
  type        = string
}

variable "OMNITY_CUSTOMS_BITCOIN_CANISTER_ID" {
  description = "OMNITY_CUSTOMS_BITCOIN_CANISTER_ID"
  type        = string
}

variable "OMNITY_ROUTES_ICP_CANISTER_ID" {
  description = "OMNITY_ROUTES_ICP_CANISTER_ID"
  type        = string
}

variable "BEVM_CHAIN_ID" {
  description = "BEVM_CHAIN_ID"
  type        = string
}

variable "BITLAYER_CHAIN_ID" {
  description = "BITLAYER_CHAIN_ID"
  type        = string
}

variable "XLAYER_CHAIN_ID" {
  description = "XLAYER_CHAIN_ID"
  type        = string
}

variable "BSQUARE_CHAIN_ID" {
  description = "BSQUARE_CHAIN_ID"
  type        = string
}

variable "MERLIN_CHAIN_ID" {
  description = "MERLIN_CHAIN_ID"
  type        = string
}

variable "BOB_CHAIN_ID" {
  description = "BOB_CHAIN_ID"
  type        = string
}

variable "ROOTSTOCK_CHAIN_ID" {
  description = "ROOTSTOCK_CHAIN_ID"
  type        = string
}

variable "BITFINITY_CHAIN_ID" {
  description = "BITFINITY_CHAIN_ID"
  type        = string
}

variable "AILAYER_CHAIN_ID" {
  description = "AILAYER_CHAIN_ID"
  type        = string
}

variable "OMNITY_CUSTOMS_ICP_CANISTER_ID" {
  description = "OMNITY_CUSTOMS_ICP_CANISTER_ID"
  type        = string
}