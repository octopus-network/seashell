variable "gateway" {
  type = object({
    api_image       = string
    messenger_image = string
    stat_image      = string
  })
}

variable "chains" {
  description = ""
  type        = list(object({
    name    = string
    service = string
  }))
}

variable "redis" {
  description = ""
  type = object({
    host     = string
    port     = string
    password = string
    tls_cert = string
  })
}
