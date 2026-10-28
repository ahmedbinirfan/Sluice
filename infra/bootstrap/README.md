# Terraform state bootstrap

One-time Azure resources that hold Terraform remote state. They are created by hand (or by a throwaway local-state stack) and are not managed by the main `infra/terraform` root.

## Resources

| What | Name |
|------|------|
| Resource group | `rg-sluice-tfstate-aue` |
| Location | `australiaeast` |
| Storage account | `stsluicetfstatefe8c1c` |
| Container | `tfstate` |

Storage settings: StorageV2, Standard_LRS, TLS 1.2 minimum, public blob access disabled, blob versioning enabled.

Tags on the group and account: `project=sluice`, `env=dev`, `owner=ahmed`.

## Check

```bash
az storage container list --account-name stsluicetfstatefe8c1c --auth-mode login -o table
```

The table should show `tfstate`.
