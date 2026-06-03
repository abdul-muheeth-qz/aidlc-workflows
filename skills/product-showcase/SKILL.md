---
name: product-showcase
description: >
  Generates shareable product presentations as paired .md and .html files from real project
  context. Covers discovery, structured content, self-contained HTML, and audience targeting.
  Use when the user asks to create a product overview, executive summary, showcase presentation,
  or project documentation for stakeholders.
---

# Product Showcase Generation

## When to use this skill

Activate this skill when the user:

- Asks to create a product overview or showcase
- Wants to generate an executive summary or presentation
- Needs a shareable project description for stakeholders
- Asks for a product demo document or all-hands presentation
- Wants paired markdown + HTML presentation artifacts

## Workflow

### Step 1: Discovery

Before generating any showcase artifact, determine:
- **Target audience** — Executive, Engineering, All-hands, or External
- **Output format** — Markdown, HTML, or Both
- **Content focus** — Overview, Technical, Value proposition, or Full

### Step 2: Gather real data

Source all content from the knowledge base, codebase, and project documentation. Never fabricate features, metrics, architecture details, or team information.

### Step 3: Generate structured content

Follow the standard structure (see Rules below) and produce the artifacts in `docs/presentations/`.

### Step 4: Sync paired files

If both markdown and HTML versions exist, ensure they are kept in sync. Updating one requires updating the other.

## Rules

### 1. Discovery Before Generation

Target audience, output format, and content focus MUST be established before generating any artifact.

### 2. Real Data Only

Presentations MUST use real project data. Never fabricate features, metrics, architecture details, or team information. All content must reference actual project artifacts.

### 3. Structured Content

Markdown overviews MUST follow this structure:
1. Product name and tagline
2. Metadata (team, date, audience)
3. What the product is
4. Problem it solves
5. What it does (at a glance)
6. How it works (process flow)
7. Key features (deep dive)
8. Architecture overview
9. Value delivered
10. Roadmap
11. Getting started

### 4. Self-Contained HTML

HTML presentations MUST be:
- Single self-contained file with no external dependencies
- Responsive (works on desktop, tablet, prints well)
- Include print styles for PDF export (`print-color-adjust: exact`)
- Use CSS custom properties for theming

### 5. Paired File Sync

When both markdown and HTML versions exist, they MUST be kept in sync. Updating one requires updating the other.

### 6. Output Location

Showcase files MUST be placed in `docs/presentations/` with naming:
- Markdown: `[project-name]-overview.md`
- HTML: `[project-name]-showcase.html`

## Example

**Input:** "Create a product showcase for our API Gateway project targeting the engineering team"

**Output:**
- `docs/presentations/api-gateway-overview.md` — full structured markdown with all 11 sections populated from real project data
- `docs/presentations/api-gateway-showcase.html` — self-contained responsive HTML with inline styles, print stylesheet, CSS custom properties, and matching content
