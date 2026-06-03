# CCP Next Terraform Migration Patterns

## Overview

These IaC migration rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when planning, designing, or executing migrations from CloudFormation or manually-created AWS infrastructure to CCP Next Terraform. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking IaC Migration Finding Behavior

A **blocking IaC migration finding** means:
1. The finding MUST be listed in the stage completion message under an "IaC Migration Findings" section with the IAC-MIGRATE rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the IAC-MIGRATE rule ID, description, and stage context

If an IAC-MIGRATE rule is not applicable to the current project (e.g., IAC-MIGRATE-05 when no VPC migration is needed), mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking IaC migration finding — follow the blocking finding behavior defined above.

### Partial Enforcement Mode

If the user selected **Partial** enforcement during opt-in, only rules IAC-MIGRATE-01 and IAC-MIGRATE-03 are enforced as blocking. All other rules are treated as advisory (non-blocking). Log the enforcement mode in `aidlc-docs/aidlc-state.md` under `## Extension Configuration`.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule IAC-MIGRATE-01: Terraform Import Prohibition

**Rule**: `terraform import` is STRONGLY DISCOURAGED and MUST NOT be used for most resource types. It creates a dual-control situation where both Terraform and CloudFormation believe they own the same resources, leading to drift, conflicts, and potential outages.

DO NOT use `terraform import` for:
- VPCs and networking resources — rebuild using `ccp-next-vpc-module`
- Lambda functions, API Gateways, SQS queues, SNS topics — recreate fresh with CCP Next conventions
- IAM roles and policies — recreate with proper labels and least-privilege patterns
- Most other resources — a clean-slate CCP Next deployment is safer and more maintainable

Acceptable exceptions (MUST be documented with justification):
- **Large S3 buckets** with significant data where recreating and migrating terabytes is expensive with minimal benefit
- Import the bucket first, then update CloudFormation to retain/release the resource

NOT acceptable as import exceptions:
- **Large databases (RDS, DynamoDB)**: Snapshot the existing database and restore into a new Terraform-managed resource instead. This keeps Terraform as the sole owner from the start.

For any import exception:
- Coordinate with the CCP Next platform team before attempting
- Never have two systems controlling the same resource simultaneously
- The import-then-release pattern has not been fully validated end-to-end — proceed with caution

**Verification**:
- No `terraform import` commands appear in migration runbooks or instructions without documented exception
- Databases are migrated via snapshot/restore, NOT terraform import
- VPCs, Lambdas, API Gateways, SQS, SNS, and IAM are recreated fresh (not imported)
- Any approved import exception has: documented justification, platform team coordination, and a plan to release from CloudFormation after import
- No resource is simultaneously managed by both Terraform and CloudFormation

---

## Rule IAC-MIGRATE-02: Blue-Green Migration Strategy

**Rule**: The recommended migration approach for CloudFormation applications is blue-green. New CCP Next infrastructure MUST be stood up side-by-side with existing CloudFormation stacks — NOT as replacements-in-place.

Required blue-green approach:
1. Stand up new CCP Next infrastructure alongside existing CloudFormation stack in the same AWS account
2. Use separate CCP Next namespaces (e.g., `dev0` for new stack while old CF stack remains)
3. Migrate workloads incrementally to the new CCP Next infrastructure
4. Validate on the new stack — integration tests, smoke tests, data flow verification
5. Decommission the old CloudFormation stack ONLY after full validation

Benefits that MUST be preserved:
- Avoids dual-control problem — each system manages its own resources
- Provides clean rollback path — old stack remains operational until confidence is established
- Ensures all CCP Next conventions (labels, tags, naming, security) apply from the start
- Allows incremental migration rather than risky big-bang cutover

**Verification**:
- Migration plan specifies side-by-side deployment (not in-place replacement)
- CCP Next infrastructure uses separate namespaces from the existing CF stack
- Migration plan includes incremental workload migration steps (not big-bang)
- Validation criteria are defined before decommissioning is allowed
- Rollback plan exists that preserves the old stack until migration is complete
- No step in the migration plan destroys or modifies existing CF resources before the new stack is validated

---

## Rule IAC-MIGRATE-03: Dual-Control Prevention

**Rule**: At NO point during migration may two systems (Terraform and CloudFormation) simultaneously believe they control the same resource. Dual-control leads to drift, reconciliation conflicts, and potential outages.

Requirements:
- Each resource MUST have exactly ONE owner at any point in time
- During migration, ownership transitions MUST be atomic — release from one system before the other assumes control
- For approved import exceptions (IAC-MIGRATE-01): import into Terraform first, then update CloudFormation to retain/release
- Document the ownership state of every migrated resource
- Include a resource ownership matrix in migration documentation

Ownership states:
- **CF-Owned**: Resource managed by CloudFormation (pre-migration)
- **Transitioning**: Resource is being migrated (brief window, requires platform team coordination)
- **TF-Owned**: Resource managed by Terraform (post-migration)
- **Decommissioned**: Old resource destroyed after migration complete

**Verification**:
- Migration documentation includes a resource ownership matrix
- No resource is listed as owned by both CF and TF simultaneously
- The transition plan for each resource defines the exact handoff sequence
- For import exceptions: the plan specifies CF retain/release AFTER successful TF import
- No migration step has both systems actively managing the same resource
- Each resource's ownership state is tracked and updated during execution

---

## Rule IAC-MIGRATE-04: Incremental Validation

**Rule**: Migration MUST include defined validation gates before proceeding to the next phase or decommissioning old infrastructure.

Requirements:
- Define acceptance criteria for each migration phase
- Run integration tests against new CCP Next infrastructure before migrating traffic
- Run smoke tests after each workload migration step
- Verify data flow end-to-end on the new stack
- Document validation results before proceeding
- Maintain the old stack operational until all validations pass

Validation gates:
1. **Infrastructure deployed** — new CCP Next resources are created and healthy
2. **Configuration validated** — security groups, IAM, networking verified
3. **Application migrated** — workload running on new infrastructure
4. **Traffic validated** — real traffic flowing correctly through new stack
5. **Performance validated** — latency, throughput, error rates within acceptable bounds
6. **Decommission approved** — explicit human approval to remove old stack

**Verification**:
- Migration plan defines specific validation criteria for each phase
- Integration test plan exists for the new CCP Next infrastructure
- Smoke test plan exists for post-migration workload verification
- Data flow verification steps are documented
- Decommissioning requires explicit approval gate (not automated)
- Old stack is not destroyed until all validation gates pass

---

## Rule IAC-MIGRATE-05: VPC Migration via Module

**Rule**: VPC migration MUST use `ccp-next-vpc-module`. Do NOT attempt to replicate its behavior manually or import existing VPCs.

Required approach:
1. Deploy new VPC using `ccp-next-vpc-module` alongside existing VPC
2. Migrate application workloads to new VPC incrementally (update subnet references, security groups)
3. Once all workloads are on the new VPC, decommission the old one

The `ccp-next-vpc-module` provides:
- Standardized subnet layouts
- NACLs
- NAT gateways
- Routes
- Endpoints

Trying to replicate this manually is significantly more work and risk than using the module directly.

**Verification**:
- VPC migration plan uses `ccp-next-vpc-module` (not manual VPC creation or import)
- New VPC is deployed alongside old VPC (not as replacement)
- Workload migration to new VPC is incremental (not big-bang subnet swap)
- Old VPC decommissioning happens only after all workloads are migrated and validated
- No `terraform import` is used for VPC or networking resources
- If no VPC migration is needed, mark as N/A

---

## Rule IAC-MIGRATE-06: SWA Module Usage

**Rule**: Before building custom resources during migration, teams MUST check if an SWA module exists for the resource type. VPC and WAF modules are essentially required — opting out requires achieving equivalent security and configuration outcomes.

Requirements:
- Check the [ccp-next-modules GitLab group](https://southwest.gitlab-dedicated.com/swa-common/devplat/ccp-next/ccp-next-modules) for available modules before building custom
- Use CCP Next modules where they exist — don't recreate equivalent functionality
- If choosing not to use VPC or WAF modules, document how equivalent security outcomes are achieved
- Custom resources are acceptable ONLY when no suitable module exists

**Verification**:
- Migration plan references CCP Next modules for standard resource types (VPC, WAF, etc.)
- No custom resource implementation duplicates functionality available in an existing CCP Next module
- If VPC or WAF modules are not used, documentation explains how equivalent security is achieved
- Module selection is documented with rationale for any custom-built alternatives

---

## Rule IAC-MIGRATE-07: CloudFormation Decommissioning

**Rule**: CloudFormation stack decommissioning MUST follow a safe, validated sequence to prevent accidental resource deletion.

Requirements:
- NEVER delete a CloudFormation stack that still owns resources needed by the application
- Before deleting a CF stack, verify all resources are either:
  - Recreated under Terraform management (blue-green)
  - Set to `DeletionPolicy: Retain` in CloudFormation (for import exceptions)
- Decommissioning order:
  1. Verify all workloads are running on new CCP Next infrastructure
  2. Remove DNS/traffic routing from old infrastructure
  3. Wait observation period (minimum 24 hours for production)
  4. Set `DeletionPolicy: Retain` on any resources to be preserved
  5. Delete the CloudFormation stack
  6. Clean up retained resources if no longer needed
- Document the decommissioning runbook with rollback steps

**Verification**:
- Decommissioning plan exists with explicit steps and rollback procedures
- No CF stack deletion happens before workload migration is validated
- `DeletionPolicy: Retain` is set for any resources that must survive stack deletion
- Observation period is defined before final decommission (minimum 24h for production)
- DNS/traffic cutover happens before stack deletion (not simultaneously)
- Decommissioning requires explicit human approval

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Requirements Analysis | IAC-MIGRATE-01, IAC-MIGRATE-02, IAC-MIGRATE-06 | Migration strategy and constraints must be captured |
| Application Design | IAC-MIGRATE-02, IAC-MIGRATE-05, IAC-MIGRATE-06 | Blue-green architecture and module selection |
| Infrastructure Design | ALL | All rules apply to migration infrastructure design |
| Code Generation (Planning) | ALL | Code generation plan must address migration patterns |
| Code Generation (Generation) | IAC-MIGRATE-01, IAC-MIGRATE-03, IAC-MIGRATE-05, IAC-MIGRATE-06 | Generated code must not use import, must use modules |
| Build and Test | IAC-MIGRATE-04, IAC-MIGRATE-07 | Validation gates and decommissioning runbooks |

At each applicable stage:
- Evaluate all IAC-MIGRATE rule verification criteria against the artifacts produced
- Include an "IaC Migration Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking IaC migration finding — follow the blocking finding behavior defined in the Overview
- Include IAC-MIGRATE rule references in design documentation and migration runbooks
