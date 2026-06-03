---
name: api-docs-generation
description: >
  Generates structured API documentation from source code. Covers public functions, classes,
  methods, exported constants, and API endpoints. Ensures source-driven accuracy, complete
  coverage of public interfaces, proper typing, and logical grouping. Use when the user
  asks to document an API, generate docs from code, or review API documentation completeness.
---

# API Documentation Generation

## When to use this skill

Activate this skill when the user:

- Asks to generate API documentation from source code
- Wants to document public interfaces, endpoints, or exported functions
- Needs to review existing API docs for completeness
- Is building an SDK or shared library that needs reference documentation
- Asks to create endpoint documentation for a REST/GraphQL/gRPC API

## Workflow

### Step 1: Identify scope

Determine what needs documenting:
- Which source files contain public interfaces?
- Is this a REST API, library, SDK, or mixed?
- What documentation format does the project use (or should use)?

### Step 2: Scan source code

Read the actual source files. Never infer or fabricate API signatures, parameters, or return types. Every documented item must reference real code.

### Step 3: Generate documentation

For each public item, produce:

1. **Name** — the function/class/endpoint name
2. **Signature** — full type signature or parameter list
3. **Description** — derived from inline comments, JSDoc, docstrings, or implementation
4. **Parameters** — name, type, required/optional, description for each
5. **Returns** — type and description of return value
6. **Throws/Errors** — documented or obvious error conditions
7. **Example** — minimal usage example when reasonably constructible

### Step 4: Organize output

Group related items logically mirroring the source code structure. Include a summary table at the top listing all documented items with one-line descriptions.

## Rules

### 1. Source-Driven Documentation

All API documentation MUST be generated from actual source code. Never infer or fabricate API signatures, parameters, or return types. Inferred types must be explicitly marked with "(inferred)".

### 2. Complete Public Interface Coverage

Every public function, class, method, exported constant, and API endpoint MUST be documented. Private/internal helpers are excluded unless explicitly requested.

### 3. Structured Item Documentation

Each documented item MUST include: Name, Signature, Description, Parameters, Returns, Throws/Errors, and Example (when constructible).

### 4. Logical Grouping

Related items MUST be grouped logically following the module/class organization of the source. A summary table at the top lists all items with one-line descriptions.

### 5. Naming Convention Preservation

Documentation MUST preserve original naming conventions from the codebase (camelCase, snake_case, PascalCase). No naming convention transformation applied.

### 6. REST Endpoint Format

REST endpoints MUST be documented as HTTP method + path (e.g., `GET /api/users/:id`), including path parameters, query parameters, request body, auth requirements, and response shapes.

### 7. Type Safety Marking

When type information is not explicitly declared in source code, inferred types MUST be marked with "(inferred)" to indicate they are not guaranteed by the type system.

## Example

**Input:** User asks to document a Node.js Express API with user routes.

**Output:**

```markdown
# Users API

| Endpoint | Method | Description |
|---|---|---|
| `/api/users` | GET | List all users with pagination |
| `/api/users/:id` | GET | Get user by ID |
| `/api/users` | POST | Create a new user |

## GET /api/users

List all users with pagination support.

**Query Parameters:**

| Name | Type | Required | Description |
|---|---|---|---|
| page | number | No | Page number (default: 1) |
| limit | number | No | Items per page (default: 20) |

**Response:** `200 OK`

| Field | Type | Description |
|---|---|---|
| data | User[] | Array of user objects |
| total | number | Total user count |
| page | number | Current page |

**Example:**
```
GET /api/users?page=1&limit=10
```
```
