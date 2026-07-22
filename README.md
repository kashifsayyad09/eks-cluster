# terraform-eks

Production-pattern Amazon EKS cluster, built with Terraform, designed to run
inside the **AWS Pluralsight Skills Sandbox** (or any standard AWS account).

```
terraform-eks/
├── backend.tf                # S3 remote state (no DynamoDB required)
├── providers.tf               # AWS provider + default tags
├── versions.tf                # Terraform + provider version pins
├── variables.tf                # Root input contract
├── locals.tf                   # Naming + subnet CIDR math
├── main.tf                     # Wires all modules together
├── outputs.tf                  # Cluster/network/IAM outputs
├── terraform.tfvars.example
├── env/
│   ├── dev/   backend.hcl + terraform.tfvars
│   ├── qa/    backend.hcl + terraform.tfvars
│   └── prod/  backend.hcl + terraform.tfvars
├── modules/
│   ├── vpc/               # 3-AZ, 3-tier networking
│   ├── iam/                 # cluster + node roles (reuse-if-exists)
│   ├── security-groups/    # least-privilege cluster/node SGs
│   ├── eks/                 # control plane + OIDC + IRSA
│   ├── node-group/          # managed node group + launch template
│   └── s3/                  # application/artifact bucket
└── scripts/
    ├── deploy.sh
    ├── destroy.sh
    ├── validate.sh
    └── get-kubeconfig.sh
```

## 1. Why every file exists

| File | Purpose |
|---|---|
| `versions.tf` | Pins Terraform `>= 1.12` and the AWS provider to a `>= 6.0, < 7.0` range so `terraform init -upgrade` never silently pulls a breaking major version. |
| `backend.tf` | Declares an S3 backend with no hardcoded bucket/key — those come from `-backend-config=env/<env>/backend.hcl`, so one codebase serves dev/qa/prod. |
| `providers.tf` | Configures the AWS provider region and `default_tags` (applied to every taggable resource automatically) plus caller-identity/partition/region data sources reused across modules. |
| `variables.tf` | The full input contract for the root module, each variable documented and validated (e.g. `environment` must be `dev`/`qa`/`prod`, `vpc_cidr` must be a real CIDR). |
| `locals.tf` | Derives `name_prefix` (`<project>-<environment>`) and slices the `/16` VPC CIDR into `/20` public / private-app / private-db subnet CIDRs per AZ using `cidrsubnet()`. |
| `main.tf` | The composition root: wires `vpc → security-groups → iam → eks → node-group`, plus the standalone `s3` module. |
| `outputs.tf` | Surfaces everything you need afterward: cluster name/ARN/endpoint, OIDC provider, subnet IDs, security group IDs, and a ready-to-copy `update_kubeconfig_command`. |

## 2. Networking design

Each of the 3 Availability Zones gets three subnets:

- **Public** — hosts the NAT Gateway(s); tagged `kubernetes.io/role/elb` so the
  AWS Load Balancer Controller can place internet-facing load balancers here.
- **Private application** — where EKS worker nodes and pods actually run; no
  public IP, egress only via NAT; tagged `kubernetes.io/role/internal-elb`.
- **Private database** — reserved for RDS/stateful services; isolated from
  Kubernetes load-balancer subnet discovery entirely.

Routing: one public route table (→ Internet Gateway) shared by all public
subnets, and one private route table **per AZ** (→ that AZ's NAT Gateway),
so switching `single_nat_gateway` from `true` to `false` only changes which
NAT Gateway each route points at — no restructuring needed.

`single_nat_gateway = true` is the **dev/qa default** (cheaper, fewer EIPs —
matches Pluralsight Sandbox EIP/NAT Gateway caps). `env/prod/terraform.tfvars`
sets it to `false` for full per-AZ isolation in production.

## 3. IAM: reuse-if-exists pattern

Terraform can't imperatively "check if a role exists, else create it" — it's
declarative. The correct pattern (implemented in `modules/iam`) is a
caller-supplied variable:

- `existing_cluster_role_name = ""` (default) → Terraform **creates** a new
  `aws_iam_role.cluster`.
- `existing_cluster_role_name = "my-existing-role"` → Terraform instead reads
  it via `data "aws_iam_role"` and reuses its ARN everywhere downstream.

Same pattern for `existing_node_role_name`. This shows up correctly in
`terraform plan` and never swallows a "not found" error.

## 4. Security groups (least privilege)

- **Cluster SG**: ingress 443 from the node SG only; egress all (control
  plane needs to reach arbitrary webhook ports on nodes).
- **Node SG**: ingress 443 and 10250 from the cluster SG only, plus a
  self-referencing all-ports rule (required for VPC CNI / CoreDNS / pod-to-pod
  traffic), and egress all (NAT-bound).

No rule ever opens ingress to `0.0.0.0/0` — the only internet-facing surface
is the EKS public API endpoint (gated by `public_access_cidrs`, not a
security group) and any ALB/NLB the AWS Load Balancer Controller creates
per-Service/Ingress.

## 5. EKS control plane → worker node communication

1. `aws_eks_cluster.this` is created with `vpc_config.subnet_ids` pointed at
   the private application subnets and `security_group_ids` set to the
   cluster SG — AWS provisions control-plane ENIs directly into your VPC.
2. Worker nodes join by calling the EKS API (port 443, node SG → cluster SG
   rule) and running `aws-iam-authenticator`/`aws eks get-token` under the
   hood via the node IAM role.
3. The control plane reaches back into nodes on port 10250 (kubelet API) for
   `kubectl exec/logs/port-forward` and for the metrics pipeline.

## 6. How `kubectl` authenticates

`aws eks update-kubeconfig` writes a kubeconfig whose `user` entry doesn't
contain a static credential — it shells out to `aws eks get-token` at request
time, which uses your local AWS credentials (SSO, IAM user, or an assumed
role) to generate a short-lived, signed bearer token accepted by the EKS API
server's built-in `aws-iam-authenticator` webhook. That's why anyone with
`aws sts get-caller-identity` working locally, and an entry in the cluster's
`aws-auth` ConfigMap / access entries, can run `kubectl` with zero extra
secrets to manage.

## 7. OIDC / IRSA

`modules/eks` registers the cluster's OIDC issuer as an
`aws_iam_openid_connect_provider` and creates one example IRSA role (for the
AWS Load Balancer Controller) whose trust policy restricts
`sts:AssumeRoleWithWebIdentity` to the exact ServiceAccount
`system:serviceaccount:kube-system:aws-load-balancer-controller` via the
OIDC `sub` claim — not "any pod in the cluster." Use the same pattern
(`aws_iam_openid_connect_provider.eks.arn` + a scoped trust policy) for any
future controller (Cluster Autoscaler, External DNS, EBS CSI driver, etc.).

## 8. Managed node group

- Launch template (`modules/node-group`) sets a 30 GiB `gp3` encrypted root
  volume, attaches the least-privilege node security group, and enforces
  IMDSv2 (`http_tokens = "required"`).
- Scaling: desired `2`, min `2`, max `4` (dev/qa) — `3/3/6` in prod.
- `lifecycle.ignore_changes` on `desired_size` so the Kubernetes Cluster
  Autoscaler (or manual scaling) doesn't fight Terraform on every plan.
- The node IAM role includes `AmazonSSMManagedInstanceCore`, so you can
  `aws ssm start-session --target <instance-id>` for troubleshooting without
  opening any SSH ingress rule.

## 9. Remote state: why no DynamoDB lock table

The Pluralsight Skills Sandbox restricts IAM (no `dynamodb:CreateTable`), so
the classic S3 + DynamoDB locking pattern isn't available. Terraform ≥ 1.10
added native S3 locking (`use_lockfile = true` in the backend config), which
uses S3's own conditional-write semantics to place a `.tflock` object next to
the state file — real mutual exclusion, zero DynamoDB dependency. Every
`env/*/backend.hcl` sets `use_lockfile = true`; there is no `dynamodb_table`
argument anywhere in this repo.

The state bucket itself (`qwertsgitlabinfra`) must have **versioning**,
**default encryption**, and a **public access block** enabled before first
`terraform init` — either pre-create it once by hand/CLI, or provision it out
of band, since a backend bucket cannot be created by the same configuration
that stores its own state in it.

## 10. Deploying

```bash
# One-time: make sure the state bucket exists and is hardened
aws s3api create-bucket --bucket qwertsgitlabinfra --region us-east-1
aws s3api put-bucket-versioning --bucket qwertsgitlabinfra \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket qwertsgitlabinfra \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket qwertsgitlabinfra \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Format, init, validate, plan, apply against dev
terraform fmt -recursive
terraform init -backend-config=env/dev/backend.hcl
terraform validate
terraform plan -var-file=env/dev/terraform.tfvars
terraform apply -var-file=env/dev/terraform.tfvars

# Verify identity and connect kubectl
aws sts get-caller-identity
aws eks update-kubeconfig --name veera-dev-eks --region us-east-1
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

Or use the wrapper script, which runs the same sequence end-to-end:

```bash
./scripts/deploy.sh dev
```

Switch environments by changing the argument (`qa`, `prod`) — each has its
own state key and its own tfvars, so `dev` and `prod` never collide.

## 11. Tearing down

```bash
./scripts/destroy.sh dev
```

Destroy order is the reverse of creation and is handled automatically by
Terraform's dependency graph: node group → EKS cluster/OIDC → IAM → security
groups → VPC (NAT Gateways, EIPs, subnets, IGW) → S3 bucket.
