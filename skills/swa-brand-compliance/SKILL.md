---
name: swa-brand-compliance
description: >
  Enforces Southwest Airlines brand standards across all branded artifacts including UI,
  content, diagrams, and customer-facing output. Covers color palette, typography, voice
  register, logo/visual assets, and icon standards. Use when generating or reviewing any
  SWA-branded customer-facing content, UI components, or marketing materials.
---

# SWA Brand Compliance

## When to use this skill

Activate this skill when the user:

- Is building a customer-facing SWA application or UI
- Asks to review branded content for compliance
- Is generating marketing materials, presentations, or customer-facing text
- Needs to check color, typography, or logo usage against SWA standards
- Is designing UI components that will carry SWA branding

## Rules

### 1. Color Palette Adherence

All branded artifacts MUST use only the approved SWA color palette:

| Color | Hex | Usage |
|---|---|---|
| Bold Blue | `#304CB2` | Primary, headers |
| Warm Red | `#D5152E` | Accent, Heart symbol |
| Sunrise Yellow | `#FFBF27` | Highlights, CTAs |
| Summit Silver | `#E5E3E3` | Backgrounds |
| Deep Silver | `#5E7E95` | Copy color, gradients |
| Dark Blue | `#1A2C80` | Dark containers |
| Midnight Blue | `#111B40` | Title bars, deep backgrounds |
| Turquoise | `#00A9E0` | Digital accents |
| White | `#FFFFFF` | Backgrounds |

- No off-palette colors in UI components or branded content
- No red-on-blue or blue-on-red type combinations
- Black (`#000000`) used only as last resort

### 2. Typography Standards

All branded text MUST follow typography rules:

- Primary font: Southwest Sans (Bold/Regular default; Medium/Bold headlines)
- Fallback: Arial (Word, PowerPoint, email, dynamic web)
- Case: Sentence case general; Title Case for naming treatments only; ALL CAPS for flight info/labels only
- Alignment: Flush left, rag right — never center, never justify
- Copy color: Deep Silver primary; Midnight Blue secondary; Black last resort

### 3. Voice Register Compliance

Content MUST match the appropriate voice register:

| Register | Audience | Attributes |
|---|---|---|
| External | Customer-facing | Friendly, warm, genuine, simple, bold; light-hearted humor |
| Internal | Coheart-facing | Same warmth; Warrior Spirit, Servant's Heart, Fun-LUVing Attitude |
| Technical | Neutral | Direct, clear, factual; no brand personality required |

### 4. Logo and Visual Asset Rules

Logo usage MUST follow placement rules:

- One logo only (wordmark + Heart)
- Position: top-right or bottom-right (marketing); top-left (web/email)
- Never manipulate, flip, or use legacy logos
- Never place text over photography (use gradient canvas)
- Brand bar required for advertisements

### 5. Icon Standards

Icons MUST follow:

- Flat 2-D only (no perspective, gradients, or 3-D effects)
- Blue preferred color
- Brand Identity approved icons only
- Only icons from the permitted topics list may be used

## Example

**Input:** User asks to create a login page for an SWA customer-facing app.

**Application:**
- Page background uses Summit Silver (`#E5E3E3`) or White (`#FFFFFF`)
- Primary button uses Bold Blue (`#304CB2`) with white text
- Accent elements use Warm Red (`#D5152E`) sparingly
- Font stack: `'Southwest Sans', Arial, sans-serif`
- Text is left-aligned, sentence case
- Logo placed top-left (web pattern)
- Welcome copy uses External register: warm, friendly, simple
- No 3D icons; flat 2D blue icons from approved set
