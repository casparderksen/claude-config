# Rules: Angular

---

## Project Structure

Follow a feature-based folder structure aligned with bounded contexts.
Each feature module is self-contained and maps to a single bounded context.

```
src/app/
├── core/                  # Singleton services, app-wide guards, interceptors
│   ├── auth/
│   └── http/
├── shared/                # Reusable presentational components, pipes, directives
│   ├── components/
│   └── pipes/
├── features/              # One folder per bounded context / feature
│   ├── feature1/
│   │   ├── data-access/   # Store (NgRx or signal-based), effects, selectors, API services
│   │   ├── ui/            # Smart (container) and dumb (presentational) components
│   │   └── util/          # Feature-specific pipes, helpers, validators
│   └── feature2/
│       ├── data-access/
│       ├── ui/
│       └── util/
└── app.routes.ts
```

### Rules

- `core/` is imported once in `app.config.ts`; never in feature modules.
- `shared/` must contain no business logic; components are purely presentational and driven by inputs/outputs.
- Feature modules must not import from other feature modules directly; communicate via the router or shared state.
- API response shapes (`Dto` types) live in `data-access/`; always map to view models before use in templates.
- All feature routes must be lazy-loaded via `loadComponent` or `loadChildren` in `app.routes.ts`.

---

## State Management

Angular's signals and NgRx serve complementary roles. Apply the right tool per scope:

| Scope                         | Approach                                          |
|-------------------------------|---------------------------------------------------|
| Local / ephemeral UI state    | Signals (`signal()`, `computed()`, `effect()`)    |
| Shared cross-feature state    | NgRx with effects and selectors                   |
| Server-fetched / cached state | NgRx + `@ngrx/signals` or `@ngrx/component-store` |

### Rules

- Prefer signals for state that does not leave the component or its direct children.
- Use NgRx when state must be shared across features, persist across
  navigation, or requires complex side-effect orchestration.
- Do not mix both patterns for the same slice of state — choose one and be consistent per feature.
- Facades are mandatory when NgRx is used; they are the only surface templates
  and smart components interact with for store access.
- One facade per feature, not per store slice, unless the feature is large enough to warrant subdivision.

---

## Code Style Conventions

- **Angular version:** Angular 17+ control flow syntax (`@if`, `@for`, `@switch`) — never `*ngIf`, `*ngFor`.
- **Components:** Standalone only — no NgModules unless integrating a legacy third-party library.
- **Change detection:** All components must use `ChangeDetectionStrategy.OnPush`.
- **Dependency injection:** `inject()` function only — no constructor injection.
  Note that `inject()` must be called in an injection context (field initialiser,
  constructor body, or factory function); never in lifecycle hooks or async callbacks.
- **View models:** Never bind raw `Dto` types to templates; always map to a `Vm` type first.
- **HTTP errors:** Centralise error handling in an `HttpInterceptor` in `core/http/`;
  do not handle HTTP errors ad hoc in services or components.
- **Environments:** Use Angular's `provideEnvironmentInitializer` or `environment.ts` / `environment.prod.ts`
  for config; never hardcode environment-specific values.
- **Documentation:** All public methods must have JSDoc.

---

## Naming Conventions

Use **PascalCase** for classes, **camelCase** for services and variables, **kebab-case** for file names.

### Files

| Artefact      | File name                                                     |
|---------------|---------------------------------------------------------------|
| Component     | `order-list.component.ts`                                     |
| API service   | `order-api.service.ts`                                        |
| Facade        | `order-facade.service.ts`                                     |
| NgRx store    | `order.store.ts`, `order.effects.ts`, `order.selectors.ts`    |
| Domain model  | `order.model.ts`                                              |
| DTO           | `order.dto.ts`                                                |
| Routes        | `order.routes.ts`                                             |

### Classes & Interfaces

| Artefact              | Convention            | Example                               |
|-----------------------|-----------------------|---------------------------------------|
| Component             | `PascalCase`          | `OrderListComponent`                  |
| API service           | `PascalCase` + suffix | `OrderApiService`                     |
| Facade                | `PascalCase` + suffix | `OrderFacadeService`                  |
| Interfaces (models)   | No prefix             | `Order`, `Customer`                   |
| View model            | Suffix `Vm`           | `OrderSummaryVm`, `CustomerDetailVm`  |
| DTO                   | Suffix `Dto`          | `OrderResponseDto`, `CreateOrderDto`  |

**Note:** Do not prefix interfaces with `I`. This is non-standard in Angular
and TypeScript communities. Use plain names for models; the `Dto` / `Vm`
suffixes provide sufficient disambiguation.

### Component Roles

- **Smart (container) components** coordinate data flow and call facades;
  no suffix beyond the entity name — `OrderDetailComponent`.
- **Dumb (presentational) components** render only and communicate via
  `@Input()` / `@Output()`; suffix with `-card`, `-list`, `-form` as
  appropriate — `OrderSummaryCardComponent`.

---

## Toolchain

| Concern               | Tool                                                          |
|-----------------------|---------------------------------------------------------------|
| Linting               | Angular ESLint (`@angular-eslint/eslint-plugin`)              |
| Formatting            | Prettier, integrated with ESLint via `eslint-config-prettier` |
| Unit testing          | Jest via `jest-preset-angular`                                |
| Integration testing   | Angular Testing Library (`@testing-library/angular`)          |
| E2E testing           | Playwright                                                    |
| Build                 | Angular CLI (`ng build`)                                      |

### Rules

- ESLint and Prettier must run as pre-commit hooks (e.g. via `lint-staged` + `husky`).
- The Jest configuration must include `jest-preset-angular` and `ts-jest` for TypeScript support.
- Do not mix `karma` / `jasmine` with Jest; remove them if present from a generated project.

---

## Testing Strategy

### Test Types & Scope

| Type          | Tool                      | Scope                                                             |
|---------------|---------------------------|-------------------------------------------------------------------|
| Unit          | Jest                      | Components, services, pipes, facades, NgRx reducers & selectors   |
| Integration   | Angular Testing Library   | Smart components wired to a real store with mocked API services   |
| E2E           | Playwright                | Critical user journeys only                                       |

### File Naming

- Unit tests: `order-list.component.spec.ts`, `order-facade.service.spec.ts`
- E2E tests: named after user journeys — `place-order.e2e.ts`, `cancel-subscription.e2e.ts`
- One `.spec.ts` per production file; collocate with the file under test.

### Rules by Artefact

- **Dumb components:** test inputs, outputs, and rendered output only; no store, no services.
- **Smart components:** test via Angular Testing Library with a real NgRx store;
  mock only API services (not the facade).
- **Facades:** test state transitions by dispatching actions and asserting via store selectors; mock effects.
- **API services:** mock `HttpClient` with `HttpTestingController`; assert on URL, method,
  and payload shape — not on the mapped result.
- **NgRx reducers:** test as pure functions directly — never indirectly through components.
- **NgRx selectors:** test as pure functions with a mock state object.
- **NgRx effects:** test via integration tests using `provideMockActions` and `provideMockStore`;
  assert on dispatched actions and side effects.
- **E2E tests** cover journeys, not components — do not duplicate unit test scenarios in Playwright.
- All test assertions must use `Vm` types, never raw `Dto` types.

### Coverage Expectations

- `shared/` components and pipes: high coverage — they are pure and reused widely.
- `data-access/` reducers and selectors: thorough unit coverage.
- `data-access/` effects: covered via integration tests using mock actions and store.
- `ui/` smart components: covered via integration tests, not unit tests.
- E2E: cover only the most critical and stable journeys to avoid brittle test suites.
