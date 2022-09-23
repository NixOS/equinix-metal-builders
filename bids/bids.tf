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

variable "tags" {
  type    = list(string)
  default = ["terraform-packet-nix-builder"]
}

variable "project_id" {
  default = "86d5d066-b891-4608-af55-a481aa2c0094"
}

variable "details_by_arch_big_parallel" {
  type = map(object({
    divisor = number
    minimum = number
    plans = list(object({
      price = number
      plan  = string
      name  = string # leave as an empty string to use the plan
      url   = string
    }))
  }))
  default = {
    "aarch64-linux" = {
      divisor = 2000
      minimum = 1
      plans = [
        {
          price = 2.0
          plan  = "c3.large.arm"
          name  = "c3.large.arm"
          url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
        },
      ]
    },
    "aarch64-linux--big-parallel" = {
      divisor = 2000
      minimum = 1
      plans = [
        {
          price = 2.0
          plan  = "c3.large.arm"
          name  = "c3.large.arm--big-parallel"
          url   = "https://netboot.gsc.io/hydra-aarch64-linux/netboot.ipxe"
        },
      ]
    },
    "x86_64-linux" = {
      divisor = 2000
      minimum = 1
      plans = [
        {
          price = 2.0
          plan  = "c3.medium.x86"
          name  = "c3.medium.x86"
          url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
        },

        {
          price = 2.0
          plan  = "m3.large.x86"
          name  = "m3.large.x86"
          url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
        },
      ]
    },
    "x86_64-linux--big-parallel" = {
      divisor = 2000
      minimum = 1
      plans = [
        {
          price = 2.0
          plan  = "c3.medium.x86"
          name  = "c3.medium.x86--big-parallel"
          url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
        },

        {
          price = 2.0
          plan  = "m3.large.x86"
          name  = "m3.large.x86--big-parallel"
          url   = "https://netboot.gsc.io/hydra-x86_64-linux/netboot.ipxe"
        },
    ], },
  }
}

locals {

  #| jq '.machineTypes
  #       | to_entries
  #       | map(
  #           select(.key | contains("linux"))
  #           | .architecture = (.key | split(":")[0])
  #           | .features = (.key | split(":")[1] // "" | split(","))
  #           | .bigparallel = (.features | contains(["big-parallel"]))
  #           | .builder_arch = (if .architecture == "i686-linux" then "x86_64-linux" else .architecture end)
  #           | .buildername = .builder_arch + (if .bigparallel then "--big-parallel" else "" end)
  #         )
  #        | reduce .[] as $item ({}; .[($item.buildername)] += $item.value.runnable)
  #        | to_entries
  #        | map(.machines = (.value / 2000 | ceil))
  #        | reduce .[] as $item ({}; .[($item.key)] = $item.machines)'

  arch_big_parallel_runnable = { for machineType, machineData in jsondecode(data.http.example.response_body).machineTypes :
    # { "x86_64-linux" => [ { features => [ "big-parallel" ], runnable = 10 }] }
    "${split(":", machineType)[0] == "i686-linux" ? "x86_64-linux" : split(":", machineType)[0]}${can(regex("big-parallel", machineType)) ? "--big-parallel" : ""}" => machineData.runnable...
    if endswith(split(":", machineType)[0], "-linux")
  }

  summed_runnable = { for arch_big_parallel, runnable in local.arch_big_parallel_runnable :
    arch_big_parallel => sum(runnable)
  }

  machines = flatten([for arch_big_parallel, runnable in local.summed_runnable :
    [for idx in range(0, max(ceil(runnable / var.details_by_arch_big_parallel[arch_big_parallel].divisor), var.details_by_arch_big_parallel[arch_big_parallel].minimum)) :
      merge(element(var.details_by_arch_big_parallel[arch_big_parallel].plans, idx), { idx = idx })
    ]
  ])

  named_bids = { for machine in local.machines :
    "${machine.plan}--${machine.name}--${machine.idx}" => machine
  }
}

data "http" "example" {
  url = "https://hydra.nixos.org/queue-runner-status"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

output "runnable" {
  value = local.summed_runnable
}

output "foo" {
  value = flatten(local.machines)
}

resource "equinix_metal_spot_market_request" "request" {
  for_each         = local.named_bids
  project_id       = var.project_id
  max_bid_price    = each.value.price
  facilities       = var.facilities
  devices_min      = 1
  devices_max      = 1
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
    when       = destroy
    on_failure = continue
    command    = "../drain-spot-bid.sh ${self.id}"
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "../terminate-spot-bid.sh ${self.id}"
  }

  lifecycle {
    ignore_changes = [
      metro,
      facilities,
      max_bid_price,
      wait_for_devices,
    ]
  }
}
