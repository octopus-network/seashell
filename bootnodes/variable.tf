
variable "cloud_vendor" {
  description = "Cloud Vendor (Alicoud, AWS, Azure, Google Cloud)"
  type        = string
  default     = ""
}

variable "access_key" {
  description = "Access key"
  type = string
}

variable "secret_key" {
  description = "Secret key"
  type = string
}

variable "region" {
  description = "Region"
  type    = string
}


variable "p2p_port" {
  description = "Specifies the port that your node will listen for p2p traffic on"
  type        = string
  default     = 30333
}

variable "rpc_port" {
  description = "Specifies the port that your node will listen for incoming RPC traffic on"
  type        = string
  default     = 9933
}

variable "ws_port" {
  description = "Specifies the port that your node will listen for incoming WebSocket traffic on"
  type        = string
  default     = 9944
}


variable "chain_spec" {
  description = "Specifies which chain specification to use"
  type        = string
  default     = ""
}

variable "p2p_peer_ids" {
  description = "Subtrate node identity file (node libp2p key)"
  type        = list(string)
  default     = []
}


variable "inventory_template" {
  description = "Ansible inventory template file"
  type        = string
  default     = ""
}