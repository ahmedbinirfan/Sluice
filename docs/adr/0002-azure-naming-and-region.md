# ADR 0002: Azure region and naming

## Status

Accepted

## Context

Sluice's first cloud is a pay-as-you-go Azure subscription billed in AUD. The monthly budget is AUD 30. The GPU has to be cheap enough on spot that intermittent dev use fits that budget, and Azure OpenAI has to be available in the same region so prompts and weights stay in Australia.

## Decision

Use **Australia East** (`australiaeast`). The short region code is `aue`.

The GPU size is `Standard_NC4as_T4_v3` (one NVIDIA T4, 4 vCPUs). On 26 Oct 2026 the Australia East Linux list price was about AUD 0.28 an hour for spot and about AUD 0.97 an hour on demand. AUD 30 buys about 109 spot hours, or about 31 on-demand hours. Spot prices move.

Name resources `<type>-sluice-<env>-<region>`:

- `rg-sluice-dev-aue`
- `aks-sluice-dev-aue`
- `acrsluicedevaue`

Azure Container Registry names are alphanumeric only, so that name has no dashes.

Tag every resource `project=sluice`, `env=dev`, `owner=ahmed`.

## Consequences

Terraform uses these names and tags. `acrsluicedevaue` has to be globally unique. If it is taken, add a short suffix. Do not change the pattern.

The T4 family quota and the regional spot quota are still separate requests. This ADR does not wait for them to be approved.

## Alternatives considered

Australia Southeast is closer to Melbourne and has a thinner GPU and Azure OpenAI catalog. A US region is cheaper for some GPUs and puts the data outside Australia.

A full A10 is about AUD 1.22 an hour on spot, about 25 hours inside the budget. An A100 is about AUD 1.40 an hour on spot and was not available on this subscription.
