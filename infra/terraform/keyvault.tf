data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "dev" {
  name                       = "kv-sluice-dev-aue"
  location                   = azurerm_resource_group.dev.location
  resource_group_name        = azurerm_resource_group.dev.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true

  tags = {
    project = "sluice"
    env     = "dev"
    owner   = "ahmed"
  }
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.dev.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
