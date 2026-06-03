# Backend Coding Standards Rules

## Overview

These rules enforce industry-level backend coding standards for production-grade server-side applications and APIs. They are language- and framework-agnostic at the principles level.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Existing Project Detection

Before applying rules, detect if this is an existing project (source files, package manifests, migration folders, CI config). For existing projects, match current patterns and only flag genuine problems. For new projects, apply full standards.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Backend Standards Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until resolved
3. Non-compliance with any applicable rule is a blocking finding

---

## Rule BACKEND-01: Layered Architecture

**Rule**: Backend code MUST follow a layered architecture with clear separation of concerns:
- **Route/Controller layer** — HTTP handling, request parsing, response formatting
- **Service layer** — business logic, orchestration
- **Data access layer** — database queries, external API calls
- **Domain layer** — entities, value objects, business rules

No layer may skip levels (controllers must not call data access directly).

**Verification**:
- Route handlers do not contain business logic
- Service functions do not import HTTP-specific types
- Database queries are isolated in dedicated modules
- Each layer has clear, single-direction dependencies

---

## Rule BACKEND-02: Explicit Error Handling

**Rule**: Every external call (database, API, file I/O) MUST have explicit error handling. Error responses MUST include:
- Appropriate HTTP status code
- Structured error body with error code and user-safe message
- No stack traces or internal details in production responses
- Correlation/request ID for tracing

**Verification**:
- All async operations have try/catch or .catch() handlers
- No empty catch blocks
- Error responses follow a consistent schema
- No `console.log(error)` as sole error handling

---

## Rule BACKEND-03: Input Validation at Boundaries

**Rule**: Every API endpoint MUST validate all input before processing:
- Type checking on all parameters
- Length/size bounds on strings and arrays
- Format validation using allowlists for structured inputs
- Request body size limits configured at framework level

**Verification**:
- Every route handler uses a validation library or schema (Zod, Joi, class-validator, etc.)
- No raw user input passes directly to business logic unvalidated
- String inputs have explicit max-length constraints

---

## Rule BACKEND-04: Structured Logging

**Rule**: Applications MUST use structured logging with:
- A configured logging framework (not ad-hoc console statements)
- Fields: timestamp, correlation ID, log level, message, context
- No sensitive data (passwords, tokens, PII) in log output
- Log levels used appropriately (error, warn, info, debug)

**Verification**:
- A logging library is configured and used consistently
- No `console.log` in production code paths
- Sensitive fields are redacted or excluded
- Every request has a correlation ID in logs

---

## Rule BACKEND-05: Test Coverage

**Rule**: Backend code MUST include tests covering:
- **Unit tests** — pure business logic, service functions, utilities
- **Integration tests** — API endpoint behavior with real/mocked dependencies
- **Error path tests** — validation failures, not-found scenarios, auth failures

**Verification**:
- Service layer functions have unit tests
- API endpoints have integration tests covering success and error paths
- Test files exist alongside or in a dedicated test directory
- Tests use descriptive names explaining the scenario

---

## Rule BACKEND-06: Configuration Management

**Rule**: Application configuration MUST be:
- Externalized (not hardcoded in source)
- Environment-specific (dev, staging, prod)
- Validated at startup (fail fast on missing required config)
- Typed where possible

**Verification**:
- No hardcoded connection strings, API keys, or environment-specific values in source
- A configuration module validates required values at startup
- Secrets are loaded from environment variables or a secrets manager

---

## Rule BACKEND-07: API Design Consistency

**Rule**: REST APIs MUST follow consistent conventions:
- Resource-based URL patterns (`/api/resources/:id`)
- Appropriate HTTP methods (GET for reads, POST for creates, PUT/PATCH for updates, DELETE for removes)
- Consistent response envelope or structure
- Pagination for list endpoints
- Versioning strategy documented

**Verification**:
- URLs follow RESTful resource patterns
- HTTP methods match CRUD semantics
- List endpoints support pagination parameters
- Response shapes are consistent across endpoints

---

## Guiding Principles

These apply in every interaction:

- **Boring is good** — choose proven, well-maintained technology over novelty
- **Explicit over implicit** — be clear about function contracts
- **Fail fast, recover gracefully** — validate at boundaries, propagate errors with context
- **Security is not a layer** — woven into every decision
- **Observability from day one** — structured logs, request tracing, health endpoints
- **Test behaviour, not implementation** — tests should survive refactors
- **Respect existing patterns** — consistency matters more than perfection in brownfield

---

## Enforcement Integration

These rules apply primarily during:
- **Functional Design** — architecture and layering decisions
- **NFR Design** — logging, error handling, configuration patterns
- **Code Generation** — all rules enforced during implementation
- **Build and Test** — test coverage verified
