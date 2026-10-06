# STACKIT Kubernetes Platform Services — Building Block

Terraform for the nested **STACKIT Kubernetes Platform Services** definition. Only the outer
[STACKIT Kubernetes Platform](../../buildingblock/README.md) run orders it, on the STACKIT project it
created, and every run acts as the platform's STACKIT service account through workload identity
federation.

It creates the platform's Secrets Manager instance with a writer and a reader user, an SKE cluster,
an admin Kubernetes service account, in-cluster ingress (cert-manager, HAProxy and a Let's Encrypt
ClusterIssuer), the meshStack replicator and metering identities, a DNS zone, a STACKIT Model
Serving token, a STACKIT Git instance, a container registry, and the meshStack SKE platform with one
landing zone per stage.

With `imports.ske` or `imports.git` set, the SKE Cluster or STACKIT Git Instance building block takes
over the existing cluster `cluster_name` or the given instance instead of creating one. In playground mode it gets
`release_on_destroy`, so deleting it leaves what it took over in place. The Git building block also
takes over the Forgejo organization with the existing token at
`imports.git.existing_forgejo_api_token_path`. This run writes each entry of `import_secrets` to the
Secrets Manager with the writer user before it orders the Git building block, so that token can
arrive through it.

With `existing` set, it orders neither the Kubernetes Ingress nor the DNS Zone building block, and
uses the given load balancer IP and zone instead.

It **registers building block definitions of its own** — `stackit/secrets-manager`, `ske/cluster`,
`kubernetes/service-account`, `kubernetes`, `kubernetes/ingress`, `stackit/git`,
`stackit/container-registry`, `stackit/dns` and `stackit/ai-llm` — and orders the landing zone's
STACKIT Service Account Federation definition as a child of the Automation Identity, listing its
STACKIT definitions in `federated_building_block_definitions`.

No building block it orders outputs a secret. Each one that creates a credential writes it to the
Secrets Manager with the writer user, through its `output_to_vault` input. This run reads what a
definition needs with the reader user, as an ephemeral value, and registers it as a write-only
input. Its version is the `secret_hash` the writing block reports in its `vault_secret` output, so a
changed secret reaches the definitions on the next run.

Once `phase2_completed` is set, it also registers the phase 2 definitions — `stackit/git-repository`,
`ske/forgejo-connector` and `ske/ske-starterkit` — and orders a second STACKIT Service Account
Federation for the Git repository definition. The Git repository and Forgejo connector runs read
their secrets from the Secrets Manager themselves, with the reader login and the paths this run
registers them with. The connector also gets the service account kubeconfig as a write-only input.

Its variables are declared in [`variables.tf`](variables.tf).
