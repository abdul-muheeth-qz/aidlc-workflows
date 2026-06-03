---
name: diagram-generation
description: >
  Generates professional diagrams in Draw.io XML, HTML, SVG, or Mermaid formats.
  Enforces audience-appropriate detail levels, real data sourcing, consistent styling,
  and proper layout patterns. Use when the user asks to create architecture diagrams,
  flowcharts, process diagrams, or any visual representation of systems or workflows.
---

# Diagram Generation

## When to use this skill

Activate this skill when the user:

- Asks to create an architecture diagram
- Wants to generate a flowchart, process diagram, or data flow diagram
- Needs a Draw.io, Mermaid, SVG, or HTML diagram
- Asks to visualize a system, workflow, or deployment topology
- Wants a diagram for a presentation, documentation, or design review

## Workflow

### Step 1: Determine requirements

Before generating, establish:
- **Target audience** — Executive, VP/Director, Solution Architect, or Development Team
- **Output format** — Draw.io XML, HTML, SVG, or Mermaid
- **Layout pattern** — Swimlane, Pipeline, Matrix, Pyramid, or Current→Future

### Step 2: Gather real data

Source all diagram elements from actual project artifacts. Never fabricate system names, component names, team names, or architecture details. Cite sources.

### Step 3: Select complexity level

| Audience | Max Elements | Content Focus |
|---|---|---|
| Executive | 5–7 boxes | Business outcomes, timelines, status |
| VP/Director | 10–15 elements | Capabilities, dependencies, phases |
| Solution Architect | 20+ elements | Components, integrations, data flow |
| Development Team | 20+ elements | APIs, services, code structure |

### Step 4: Generate diagram

Apply format-specific standards and ensure readability (minimum 11pt labels, 14pt headers, no overlaps, labeled connectors).

## Rules

### 1. Audience-Appropriate Detail

Every diagram MUST target a specific audience with appropriate complexity. Executive diagrams do not exceed 7 elements. Technical diagrams include sufficient implementation detail.

### 2. Data Source Integrity

Diagrams MUST be sourced from real project data. Never fabricate system names, component names, team names, or architecture details. Sources must be cited.

### 3. Output Format Standards

- **Draw.io XML** — valid mxGraph XML, `fontFamily=Segoe UI` on every element
- **HTML** — self-contained single file, no external dependencies, responsive
- **SVG** — valid SVG markup, accessible with text alternatives
- **Mermaid** — valid syntax that renders without errors

### 4. Naming Convention

Diagram files MUST follow: `[subject]-[type].[ext]` (e.g., `project-architecture.drawio`, `system-roadmap.drawio`)

### 5. Layout Pattern Selection

| Pattern | Best For |
|---|---|
| Swimlane Architecture | System domains, layered architectures |
| Pipeline/Pathway | Processes, deployments, CI/CD |
| Matrix/Assessment | Frameworks, comparisons, maturity |
| Pyramid/Hierarchy | Org structures, training levels |
| Current → Future State | Comparison diagrams |

### 6. Readability Standards

- Minimum 11pt for labels, 14pt for headers
- Consistent spacing and alignment
- Connectors labeled with relationship descriptions
- No overlapping elements or text

## Example

**Input:** "Create an architecture diagram for our microservices system targeting the solution architect audience"

**Output:** A Draw.io XML diagram with:
- 20+ elements showing all services, databases, queues, and external integrations
- Swimlane layout grouping services by domain
- Labeled connectors showing data flow direction and protocol (REST, gRPC, events)
- `fontFamily=Segoe UI` on all elements
- File named `system-architecture.drawio`
