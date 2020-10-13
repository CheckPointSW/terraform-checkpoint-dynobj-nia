resource "checkpoint_management_dynamic_object" "dynamic_object" {
  for_each = local.grouped
  name     = replace("${var.dynamic_object_prefix}${each.key}", "/[^0-9A-Za-z]/", "-")
  comments = "consul"
  tags     = each.value // ["<name>-<ip>", ...]
}

output "services_output" {
  value = local.grouped
}

locals {
  service_ids = transpose({
      for id, s in var.services : id => [s.name]
  })
  grouped = {
      for name, ids in local.service_ids:
      name => [
        for id in ids : var.services[id].address != "" ?
          "${id}-${var.services[id].address}" : "${id}-${var.services[id].node_address}"
      ]
  }
}

resource "null_resource" "publish" {

  triggers = {
    version = local.timestamp
}
  provisioner  "local-exec" {
  command = "${path.module}/publish.sh"
  interpreter = ["/bin/bash"]
  }
}

locals {
  timestamp = timestamp()
}