provider "metal" {}

terraform {
  backend "s3" {
    bucket = "grahamc-nixops-state"
    key    = "packet-nix-builder/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    metal = {
      source = "equinix/metal"
    }

    equinix = {
      source = "equinix/equinix"
    }
  }
}

variable "tags" {
  type    = list(string)
  default = ["terraform-packet-nix-builder"]
}

variable "project_id" {
  default = "86d5d066-b891-4608-af55-a481aa2c0094"
}

variable "bids" {
  type = list(object({
    price = number
    plan  = string
    metro = string
    name  = string # leave as an empty string to use the plan
    url   = string
  }))
  default = [
    {
      price = 2.0
      plan  = "c3.large.arm"
      metro = "DC"
      name  = "c3.large.arm--big-parallel"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      price = 1.9
      plan  = "c3.large.arm"
      metro = "DC"
      name  = "c3.large.arm--big-parallel"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      price = 1.8
      plan  = "c3.large.arm"
      metro = "DC"
      name  = "c3.large.arm"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      price = 2.0
      plan  = "c3.medium.x86"
      metro = "AM"
      name  = "c3.medium.x86--big-parallel"
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      price = 1.99
      plan  = "c3.medium.x86"
      metro = "AM"
      name  = "c3.medium.x86--big-parallel"
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      price = 1.98
      plan  = "c3.medium.x86"
      metro = "AM"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      price = 1.97
      plan  = "c3.medium.x86"
      metro = "NY"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      price = 1.96
      plan  = "c3.medium.x86"
      metro = "NY"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      price = 1.95
      plan  = "c3.medium.x86"
      metro = "AM"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      price = 1.97
      plan  = "m3.large.x86"
      metro = "DA"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
  ]
}

locals {
  named_bids = { for bid in var.bids : "${bid.plan}--${bid.name}--${bid.price}" => bid }
}

resource "equinix_metal_spot_market_request" "request" {
  for_each      = local.named_bids
  project_id    = var.project_id
  max_bid_price = each.value.price
  # facilities    = [ "sjc1", "dfw2", "ewr1" ] # todo: add nrt1 and ams1; their spot markets were churning in 2021-09-03
  # metros         = [ "DC", "DA", "SV", "SP", "AM", "FR", "SG", "SV" ]
  metro = each.value.metro
  # facilities  = ["ewr1"]
  devices_min = 1
  devices_max = 1

  instance_parameters {
    hostname         = each.value.name == "" ? each.value.plan : each.value.name
    billing_cycle    = "hourly"
    operating_system = "custom_ipxe"
    always_pxe       = true
    plan             = each.value.plan
    ipxe_script_url  = each.value.url
    project_ssh_keys = []
    user_ssh_keys    = []
    tags             = concat(var.tags, ["hydra"])
  }

  provisioner "local-exec" {
    when = destroy
    on_failure = continue
    command = "../drain-spot-bid.sh ${self.id}"
  }

  provisioner "local-exec" {
    when = destroy
    on_failure = continue
    command = "../terminate-spot-bid.sh ${self.id}"
  }
}
