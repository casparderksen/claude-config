# Rules: TypeScript

---

## Compiler Configuration

Always enforce the strictest compiler settings. The following flags are mandatory in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "exactOptionalPropertyTypes": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": false
  }
}
```

### Rules

- Never disable strict flags per file using `// @ts-ignore` or `// @ts-nocheck`.
  Use `// @ts-expect-error` with a comment explaining the reason when bypassing is genuinely unavoidable.
- `skipLibCheck: false` is preferred; enable it only when a third-party library
  ships broken types and there is no alternative.
- Use project references (`references`) for monorepos to enforce compilation
  boundaries.

---

## Type Definitions

### `interface` vs `type`

| Use case                                          | Prefer        |
|---------------------------------------------------|---------------|
| Object shapes (models, DTOs, view models)         | `interface`   |
| Union types, intersection types, mapped types     | `type`        |
| Function signatures as standalone declarations    | `type`        |
| Extending or merging external library types       | `interface`   |

### Rules

- Do not use `interface` and `type` interchangeably — choose based on the use case above.
- Do not prefix interfaces with `I`. Use plain descriptive names;
  suffixes (`Dto`, `Vm`, `Config`) provide disambiguation where needed.
- Prefer `interface` for public API shapes; they produce clearer error messages and support declaration merging.

### Enums vs. Union Types

Prefer string literal union types over TypeScript enums:

```typescript
// Preferred
type OrderStatus = 'pending' | 'confirmed' | 'shipped' | 'cancelled';

// Avoid
enum OrderStatus { Pending, Confirmed, Shipped, Cancelled }
```

**Rationale:** Numeric enums are unsound (any number is assignable), const
enums have module boundary issues, and string unions are more idiomatic and
tree-shakeable. Use `const` objects with `as const` only when you need runtime
access to the set of values:

```typescript
const ORDER_STATUS = {
  Pending: 'pending',
  Confirmed: 'confirmed',
} as const;

type OrderStatus = typeof ORDER_STATUS[keyof typeof ORDER_STATUS];
```

---

## Type Safety

### Avoiding `any`

- Never use `any` in production code. Use `unknown` when the type is genuinely unknown, then narrow before use.
- Prefer `unknown` over `any` for external data (API responses, JSON parsing, event payloads).
- `any` in test files is acceptable only for partial mock construction.

### Type Narrowing

Use explicit narrowing; never rely on type assertions to bypass the type system:

```typescript
// Preferred — narrow with a type guard
function isApiError(value: unknown): value is ApiError {
  return (
    typeof value === 'object' &&
    value !== null &&
    'code' in value &&
    'message' in value
  );
}

// Avoid — assertion bypasses safety
const error = response as ApiError;
```

### Rules

- Use discriminated unions for modelling states that change shape:
  ```typescript
  type RequestState<T> =
    | { status: 'idle' }
    | { status: 'loading' }
    | { status: 'success'; data: T }
    | { status: 'error'; error: Error };
  ```
- Use `satisfies` when you want to validate a value against a type without widening it.
- Avoid non-null assertion (`!`); use optional chaining (`?.`) and nullish coalescing (`??`) instead.

### Null & Undefined

- `null` and `undefined` are not interchangeable. Use `undefined` for absent
  optional values; reserve `null` for intentional empty values (e.g. clearing a field).
- With `exactOptionalPropertyTypes` enabled, do not assign `undefined`
  explicitly to optional properties — omit them instead.

---

## Generics

- Name type parameters meaningfully when context allows: `TEntity`, `TResponse`, `TError`
  rather than bare `T`, `U`, `V` in complex signatures.
- Single-letter names (`T`) are acceptable only for simple, self-evident utility functions.
- Constrain generics appropriately; avoid unconstrained `T extends any`:
  ```typescript
  // Preferred
  function mapList<TInput, TOutput>(
    items: TInput[],
    mapper: (item: TInput) => TOutput
  ): TOutput[]
  ```
- Avoid over-engineering with generics; if a generic has one concrete
  realisation in the codebase, use the concrete type.

---

## Utility Types

Use built-in utility types; do not reimplement them:

| Utility                           | Use case                                                  |
|-----------------------------------|-----------------------------------------------------------|
| `Partial<T>`                      | Optional version of all properties (e.g. update payloads) |
| `Required<T>`                     | All properties mandatory                                  |
| `Readonly<T>`                     | Immutable shape; prefer for function inputs               |
| `Pick<T, K>`                      | Subset of an interface                                    |
| `Omit<T, K>`                      | Exclude specific properties                               |
| `Record<K, V>`                    | Dictionary / map shapes                                   |
| `ReturnType<T>`                   | Infer return type of a function                           |
| `Parameters<T>`                   | Infer parameter tuple of a function                       |
| `NonNullable<T>`                  | Exclude `null` and `undefined`                            |
| `Extract<T, U>` / `Exclude<T, U>` | Union filtering                                           |

### Rules

- Prefer `Readonly<T>` for function parameters that must not be mutated.
- Do not chain utility types more than two levels deep; extract an intermediate named type for readability.

---

## Functions & Methods

- Prefer explicit return types on all public functions and methods. Type
  inference on implementation details is fine; exported surface area must be explicit.
- Prefer named functions over anonymous arrow functions for top-level
  declarations; use arrow functions for callbacks and single-expression utilities.
- Do not use `function` overloads to paper over poor API design; prefer
  discriminated unions or optional parameters with clear intent.
- Avoid functions with more than three parameters; group related parameters
  into a typed options object.
- Avoid side effects in pure utility functions; keep them deterministic and
  testable.

---

## Async Patterns

- Always use `async` / `await` over raw `.then()` / `.catch()` chains for readability.
- Always handle promise rejections — either via `try/catch` in `async`
  functions or with an explicit `.catch()` when not awaiting.
- Type `async` functions with a concrete `Promise<T>` return type — never `Promise<any>`.
- Do not `await` inside loops where parallelism is possible; use `Promise.all()`:
  ```typescript
  // Preferred
  const results = await Promise.all(ids.map(id => fetchItem(id)));

  // Avoid
  for (const id of ids) {
    const result = await fetchItem(id); // serialises unnecessarily
  }
  ```
- Use `Promise.allSettled()` when partial failure is acceptable and each result must be inspected individually.

---

## Error Handling

- Do not throw raw strings; always throw `Error` instances or typed custom error classes.
- Define custom error classes for distinct failure domains:
  ```typescript
  class ValidationError extends Error {
    constructor(
      message: string,
      public readonly field: string
    ) {
      super(message);
      this.name = 'ValidationError';
    }
  }
  ```
- Catch blocks must not be empty and must not silently swallow errors. Log or rethrow.
- Narrow the type of caught values before use — `catch (error)` gives `unknown`
  under `useUnknownInCatchVariables` (enabled by `strict`).

---

## Imports & Module Boundaries

- Use absolute path aliases over deep relative imports (`@app/`, `@features/`, etc.)
  configured in `tsconfig.json` `paths`.
- Group imports in this order, separated by a blank line:
  1. Node built-ins
  2. Third-party packages
  3. Internal absolute imports
  4. Relative imports
- Do not use barrel files (`index.ts`) in deeply nested feature folders — they
  create circular dependency risk and slow down compilation. Use them only at
  the public API boundary of a library or feature.
- Never import from a sibling feature module directly; go through the public
  barrel at the feature root.
- Prefer named exports over default exports for all production code. Default
  exports impede renaming, auto-import resolution, and re-export.

---

## Immutability

- Prefer `const` over `let`; never use `var`.
- Mark object and array parameters as `Readonly<T>` or `readonly T[]` when the function must not mutate them.
- Use `as const` to freeze literal objects and tuples used as configuration or lookup tables.
- Avoid mutating function arguments; return new values instead.

---

## Naming Conventions

| Artefact                  | Convention                                | Example                           |
|---------------------------|-------------------------------------------|-----------------------------------|
| Classes                   | PascalCase                                | `OrderService`                    |
| Interfaces                | PascalCase, no `I` prefix                 | `OrderSummary`, `PageConfig`      |
| Type aliases              | PascalCase                                | `OrderStatus`, `RequestState<T>`  |
| Enums (if used)           | PascalCase name, PascalCase members       | `Direction.North`                 |
| Functions & methods       | camelCase                                 | `calculateTotal()`                |
| Variables & parameters    | camelCase                                 | `orderItems`                      |
| Constants (module-level)  | SCREAMING_SNAKE_CASE                      | `MAX_RETRY_COUNT`                 |
| Generic type parameters   | Prefixed with `T` for complex signatures  | `TEntity`, `TResponse`            |
| Files                     | kebab-case                                | `order-summary.model.ts`          |

---

## Documentation

- All exported functions, classes, interfaces, and type aliases must have JSDoc.
- Document *why*, not *what* — the code describes what; JSDoc should explain
  intent, constraints, and non-obvious behaviour.
- Use `@param`, `@returns`, `@throws`, and `@example` tags where they add value.
- Do not add JSDoc to private implementation details unless the logic is genuinely complex.
