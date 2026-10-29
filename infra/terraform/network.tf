resource "azurerm_virtual_network" "dev" {
  name                = "vnet-sluice-dev-aue"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    project = "sluice"
    env     = "dev"
    owner   = "ahmed"
  }
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.0.0.0/22"]
}
