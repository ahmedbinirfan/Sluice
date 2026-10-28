terraform {
  backend "azurerm" {
    resource_group_name  = "rg-sluice-tfstate-aue"
    storage_account_name = "stsluicetfstatefe8c1c"
    container_name       = "tfstate"
    key                  = "sluice-dev.tfstate"
    use_azuread_auth     = true
  }
}
