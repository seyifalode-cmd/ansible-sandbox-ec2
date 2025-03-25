variable "ssh_key_private" {
  type    = string
  #Replace this with the location of you private key
  default = "~/.ssh/id_ed25519"
}

variable "ssh_key_public" {
  type    = string
  #Replace this with the location of you public key .pub
  default = "~/.ssh/id_ed25519.pub"
}

