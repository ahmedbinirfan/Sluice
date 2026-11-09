# GitHub Actions OIDC app: gh-sluice-ci (client_id 7916a3ad-…).
# Object ID is not a secret. Re-created with the RG so `make up` restores CI plan rights
# after every destroy (listClusterUserCredential 403 otherwise).
variable "ci_principal_object_id" {
  type        = string
  description = "Object ID of the gh-sluice-ci service principal used by Actions OIDC"
  default     = "9e27e639-10d0-42e5-8b6c-ac1ccd861496"
}

resource "azurerm_role_assignment" "ci_rg_reader" {
  scope                = azurerm_resource_group.dev.id
  role_definition_name = "Reader"
  principal_id         = var.ci_principal_object_id
}

resource "azurerm_role_assignment" "ci_aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.dev.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.ci_principal_object_id
}
