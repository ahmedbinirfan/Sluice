resource "azurerm_kubernetes_cluster" "dev" {
  name                = "aks-sluice-dev-aue"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  dns_prefix          = "aks-sluice-dev-aue"

  sku_tier                  = "Free"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "system"
    vm_size        = "Standard_D4s_v6"
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.aks.id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    load_balancer_sku   = "standard"
    # VNet is 10.0.0.0/16 — default service CIDR 10.0.0.0/16 would overlap
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    pod_cidr       = "10.244.0.0/16"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  tags = {
    project = "sluice"
    env     = "dev"
    owner   = "ahmed"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.dev.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.dev.kubelet_identity[0].object_id
}
