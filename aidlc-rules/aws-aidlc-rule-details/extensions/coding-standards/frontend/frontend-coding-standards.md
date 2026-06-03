# Frontend Coding Standards Rules

## Overview

These rules enforce industry-level frontend coding standards for production-grade web applications. They cover architecture, component design, state management, accessibility, performance, and testing.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Frontend Standards Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until resolved
3. Non-compliance with any applicable FRONTEND rule is a blocking finding

---

## Rule FRONTEND-01: Component Architecture

**Rule**: Frontend code MUST follow a structured component architecture:
- **Feature-based folder structure** — group by feature/domain, not by file type
- **Component composition** — prefer composition over inheritance
- **Single responsibility** — each component does one thing
- **Separation of concerns** — UI rendering separate from business logic (hooks, services)

**Verification**:
- Components are organized by feature, not by type (no `components/`, `containers/` split)
- Each component file contains one primary component
- Business logic extracted to custom hooks or service modules
- No God components handling multiple unrelated responsibilities

---

## Rule FRONTEND-02: TypeScript Strictness

**Rule**: TypeScript MUST be used with strict configuration:
- `strict: true` in tsconfig
- No `any` type without documented justification
- No non-null assertions (`!`) without proper null handling
- Explicit return types on exported functions
- Zod or equivalent for runtime validation of external data

**Verification**:
- tsconfig has `strict: true`
- No untyped `any` usage in production code
- External API responses validated with runtime schemas
- Props interfaces defined for all components

---

## Rule FRONTEND-03: State Management

**Rule**: State MUST be managed with clear patterns:
- **Local state** — component-scoped with useState/useReducer
- **Shared state** — Zustand, Context, or equivalent for cross-component state
- **Server state** — TanStack Query, SWR, or equivalent for API data
- **No prop drilling** beyond 2 levels — use context or state management

**Verification**:
- Props are not passed through more than 2 intermediate components
- Server data uses a dedicated data-fetching library with caching
- Global state is minimal and well-scoped
- State location matches its usage scope

---

## Rule FRONTEND-04: Accessibility Compliance

**Rule**: All UI components MUST be accessible:
- Semantic HTML elements used appropriately
- Interactive elements keyboard-navigable
- ARIA attributes used correctly (not as a substitute for semantic HTML)
- Color contrast meets WCAG 2.1 AA minimum (4.5:1 for text)
- Focus management for dynamic content and modals
- Form inputs have associated labels

**Verification**:
- No `<div>` or `<span>` used for interactive elements (use `<button>`, `<a>`, etc.)
- All images have alt text
- Form inputs have associated `<label>` elements
- Keyboard navigation works for all interactive elements
- Focus is managed when content changes dynamically

---

## Rule FRONTEND-05: Performance Standards

**Rule**: Applications MUST follow performance best practices:
- Code splitting at route level (lazy loading)
- Images optimized and lazy-loaded below the fold
- Memoization used for expensive computations (`useMemo`, `useCallback`)
- No unnecessary re-renders (verified with React DevTools profiling)
- Bundle size monitored — no single chunk > 250KB gzipped

**Verification**:
- Route-level code splitting implemented
- Large lists use virtualization
- Heavy computations wrapped in useMemo
- No import of entire libraries when tree-shaking available

---

## Rule FRONTEND-06: Testing Requirements

**Rule**: Frontend code MUST include tests:
- **Component tests** — render, interaction, accessibility (React Testing Library)
- **Integration tests** — user flows across multiple components
- **E2E tests** — critical user paths (Playwright or Cypress)
- Tests MUST test behavior, not implementation details

**Verification**:
- Components have render and interaction tests
- Tests query by role/label/text, not by CSS class or test ID
- Critical user flows have E2E coverage
- Test descriptions explain the scenario being tested

---

## Rule FRONTEND-07: Error Handling and Boundaries

**Rule**: Applications MUST handle errors gracefully:
- Error boundaries at route and feature level
- User-friendly error messages (no raw error objects displayed)
- Retry mechanisms for failed network requests
- Loading and empty states handled for all async operations

**Verification**:
- Error boundaries wrap major application sections
- Network failures show user-friendly messages with retry options
- Loading states exist for all data-fetching operations
- Empty states are designed and implemented

---

## Guiding Principles

- **Clarity over cleverness** — code should be readable without a mental debugger
- **Consistency** — follow standards; propose changes through PRs, not exceptions
- **Accessibility is not optional** — every feature must be operable regardless of how someone interacts with a browser
- **Performance is a feature** — perceived speed directly impacts user experience
- **Leave it better than you found it** — every PR is an opportunity for improvement

---

## Enforcement Integration

These rules apply primarily during:
- **Application Design** — component architecture decisions
- **NFR Design** — accessibility, performance patterns
- **Code Generation** — all rules enforced during implementation
- **Build and Test** — test coverage and accessibility verification
