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

variable "reservations" {
  type = map(object({ # reservation ID is the key
    facility = string
    class    = string
  }))
  default = {
  }
}

variable "reservation_class_urls" {
  type = map(string)
  default = {
    "baremetal_2a5" = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    "c2.large.arm"  = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
  }
}

variable "reservation_facility_names" {
  type = map(string)
  default = {
    "c9dcbd06-6797-4096-b648-1be16dd5d833" = "dfw2",
  }
}

# Reservations where the underlying hardware is probably broken
variable "reservation_broken" {
  type = list(string)
  default = [
  ]
}

variable "reservation_class_names" {
  type = map(string)
  default = {
    "baremetal_2a5" = "baremetal-2a5" # _'s not allowed in hostnames
  }
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
      metro = "DA"
      name  = "c3.large.arm--big-parallel"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      price = 1.9
      plan  = "c3.large.arm"
      metro = "DA"
      name  = "c3.large.arm--big-parallel"
      url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
    },
    {
      price = 1.8
      plan  = "c3.large.arm"
      metro = "DA"
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


resource "metal_device" "reservation" {
  for_each                = { for id, value in var.reservations : id => value if !contains(var.reservation_broken, id) }
  project_id              = var.project_id
  hostname                = lookup(var.reservation_class_names, each.value.class, each.value.class)
  billing_cycle           = "hourly"
  operating_system        = "custom_ipxe"
  always_pxe              = true
  plan                    = each.value.class
  facilities              = [var.reservation_facility_names[each.value.facility]]
  hardware_reservation_id = each.key

  ipxe_script_url                  = var.reservation_class_urls[each.value.class]
  project_ssh_key_ids              = []
  tags                             = concat(var.tags, ["hydra"])
  wait_for_reservation_deprovision = true

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  provisioner "local-exec" {
    when = destroy
    on_failure = continue
    command = "../drain.sh ${self.device_id}"
  }

  provisioner "local-exec" {
    when = destroy
    on_failure = continue
    command = "../terminate.sh ${self.id}"
  }
}

