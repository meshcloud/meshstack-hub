variable "kubeconfig" {
  type        = string
  sensitive   = true
  description = "Raw kubeconfig (YAML) of the target cluster, from a preceding building block so it is known at plan time."
}

variable "cert_manager_version" {
  type        = string
  nullable    = false
  description = "Version of the cert-manager Helm chart."
}

variable "haproxy_version" {
  type        = string
  nullable    = false
  description = "Version of the haproxytech/kubernetes-ingress Helm chart."
}

variable "haproxy_replica_count" {
  type        = number
  nullable    = false
  description = "Number of HAProxy ingress controller replicas."
}

variable "haproxy_service_annotations" {
  type        = map(string)
  nullable    = false
  description = "Annotations on the HAProxy controller Service, read by the cloud provider to configure the load balancer."
}

variable "ingress_class_name" {
  type        = string
  nullable    = false
  description = "Name of the IngressClass the controller serves."
}

variable "acme_email" {
  type        = string
  nullable    = false
  description = "Contact address Let's Encrypt uses for expiry warnings and account recovery."
}

variable "acme_server" {
  type        = string
  nullable    = false
  description = "ACME directory URL the ClusterIssuer registers against."
}

variable "cluster_issuer_name" {
  type        = string
  nullable    = false
  description = "Name of the ClusterIssuer application teams reference from the cert-manager.io/cluster-issuer annotation."
}
