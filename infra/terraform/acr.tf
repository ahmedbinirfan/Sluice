resource "azurerm_container_registry" "dev" {
  name                = "acrsluicedevaue"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    project = "sluice"
    env     = "dev"
    owner   = "ahmed"
  }
}
