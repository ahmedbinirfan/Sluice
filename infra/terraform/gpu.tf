resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                  = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.dev.id
  vm_size               = "Standard_NC4as_T4_v3"
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.aks.id

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1

  auto_scaling_enabled = true
  min_count            = 0
  max_count            = 1

  node_labels = {
    pool = "gpu"
  }

  node_taints = [
    "nvidia.com/gpu=present:NoSchedule",
  ]

  tags = {
    project = "sluice"
    env     = "dev"
    owner   = "ahmed"
  }
}
