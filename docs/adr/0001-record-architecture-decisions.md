# ADR 0001: Record architecture decisions

## Status

Accepted

## Context

Sluice will take months. Choices such as the model, the gateway, the judge, and the Azure region will be made in different tickets. Chat history and commit messages will not keep the reason next to the code.

## Decision

Every significant choice gets a numbered file in `docs/adr/`, copied from `0000-template.md`. A choice is not done until that file exists.

## Consequences

The reason for a choice stays in the repo. Writing it is short on purpose: status, context, the decision, the consequences, and what was rejected.

These numbers are reserved:

- 0002 Azure region and naming (SLU-41)
- 0003 AKS, spot GPU nodes, and Argo CD (SLU-50)
- 0004 which model to serve (SLU-51)
- 0005 how the air gap works (SLU-70)

## Alternatives considered

Leaving decisions only in Notion, or only in commit messages. Both are harder to find when reading the code later.
