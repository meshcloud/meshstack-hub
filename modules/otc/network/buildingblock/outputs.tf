output "vpc_id" {
  value       = module.vpc.vpc.id
  description = "ID of the VPC."
}

# The subnet's `id` is the network ID that NAT gateways, RDS and CCE take as their subnet; its
# `subnet_id` attribute is the underlying IPv4 subnet, which they do not accept.
output "subnet_id" {
  value       = local.subnet.id
  description = "Network ID of the subnet, as RDS instances and CCE clusters take it."
}

output "subnet_cidr" {
  value       = local.subnet.cidr
  description = "IP range of the subnet."
}

output "snat_ip" {
  value       = var.snat_enabled ? module.snat.nat_ip : ""
  description = "Public IP the subnet's outbound traffic leaves through, or empty without a NAT gateway."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # Network ${var.name}

    The VPC `${var.name}` (`${var.cidr_block}`) and its subnet `${var.name}` (`${local.subnet.cidr}`)
    are ready in this project.

    ${var.snat_enabled ? "Outbound internet traffic from the subnet leaves through the NAT gateway's public IP `${module.snat.nat_ip}`. Allow-list that IP where an external service restricts callers." : "The subnet has no NAT gateway, so servers in it reach the internet only through public IPs of their own."}

    ## Next steps

    Enter **${var.name}** as the network name when you order a database (RDS) or a Kubernetes
    cluster (CCE) building block in this project. They place their servers in this subnet.
  EOT
}
