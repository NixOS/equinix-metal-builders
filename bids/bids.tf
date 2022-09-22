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

variable "facilities" {
  type = list(string)
  # curl --header "X-Auth-Token: $PACKET_AUTH_TOKEN" https://api.equinix.com/metal/v1/facilities \
  # | jq -r '.facilities | map(select(.metro.code | inside("am", "da", "fr", "la", "ny", "se", "sv", "dc")) | .code) | sort'
  default = [
    "am6",
    "da11",
    "da6",
    "dc10",
    "dc13",
    "fr2",
    "fr8",
    "la4",
    "ny5",
    "ny7",
    "se4",
    "sv15",
    "sv16"
  ]
}

variables "price" {
  type = number
  default = 4 # randomly chosen
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
    plan  = string
    name  = string # leave as an empty string to use the plan
    url   = string
  }))
  default = [
    {
      plan  = "c3.large.arm"
      name  = "c3.large.arm--big-parallel"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.large.arm"
      name  = "c3.large.arm--big-parallel"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.large.arm"
      name  = "c3.large.arm"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.medium.x86"
      name  = "c3.medium.x86--big-parallel"
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.medium.x86"
      name  = "c3.medium.x86--big-parallel"
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.medium.x86"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.medium.x86"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.medium.x86"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      plan  = "c3.medium.x86"
      name  = ""
      url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
    },
    {
      plan  = "m3.large.x86"
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
  max_bid_price = var.price
  facilities  = var.facilities
  devices_min = 1
  devices_max = 1
  wait_for_devices = true

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

  lifecycle {
    ignore_changes = [
      metro,
      facilities,
      max_bid_price,
    ]
  }
}
