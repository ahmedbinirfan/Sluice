resource "azurerm_resource_group" "dev" {
  name     = "rg-sluice-dev-aue"
  location = "australiaeast"

  tags = {
    project = "sluice"
    env     = "dev"
    owner   = "ahmed"
  }
}
