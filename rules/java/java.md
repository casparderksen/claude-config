# Rules: Java

---

## Code Style

- Prefer immutable objects — use records, `final` fields, and unmodifiable collections by default.
- Prefer `sealed` classes and interfaces when modelling a closed, known set of subtypes
  (e.g. result types, domain event hierarchies, exception hierarchies). Exhaustive `switch`
  expressions over sealed types eliminate the need for `default` branches and catch missing
  cases at compile time.
- Prefer functional style for data transformation (streams, method references); avoid it
  where imperative code is materially clearer — readability wins over style consistency.
- Write code that is self-explanatory; prefer expressive naming over inline comments.
- Use comments to explain **why**, never **what** — the code explains what.
- Annotate every method that overrides or implements a supertype method with `@Override` —
  it makes intent explicit and catches signature mismatches at compile time.

### Javadoc

- All public API boundaries (exported packages, public interfaces, public classes) must have
  Javadoc explaining purpose and usage.
- Public methods require Javadoc only when their intent is not immediately obvious from the
  name and signature. Self-explanatory methods (`getId()`, `isConfirmed()`) do not need it.
- Document **why** a design decision was made when it is non-obvious — not what the code does.
- Never leave generated Javadoc stubs (`@param foo the foo`) — either write meaningful content
  or omit the tag.

### Null Handling

- Never return `null` from a method — return `Optional<T>` when absence is a
  normal, expected outcome the caller must handle; throw a named unchecked
  exception when absence violates a precondition or contract.
- Never pass `null` as a method argument — use `Optional`, overloading, or named factory
  methods to express optionality explicitly.
- Use `Optional<T>` as a return type only — never as a field type, constructor parameter,
  or method parameter. `Optional` is a return-type API, not a general-purpose nullable wrapper.
- Validate method arguments at the entry point of public methods; throw
  `IllegalArgumentException` or a domain-specific exception immediately rather than allowing
  `NullPointerException` to propagate.

### Exception Handling

- Prefer unchecked exceptions (`RuntimeException` subtypes) — checked exceptions impose a
  handling burden on every caller and leak implementation detail through method signatures.
- Use checked exceptions only when the caller can reasonably be expected to recover and the
  recovery path is part of the method's documented contract.
- Never swallow exceptions silently — either handle with intent or rethrow.
- Never use exceptions for flow control.
- Catch the most specific exception type available; never catch `Exception` or `Throwable`
  unless at a top-level boundary (framework entry point, main method).

### Logging

- Use SLF4J (`org.slf4j.Logger`) as the logging facade in library and utility code;
  never depend on a logging implementation directly.
- In Quarkus services, use `io.quarkus.logging.Log` (static logger) — see Quarkus rules.
- Use parameterised log messages — never string concatenation: `log.debug("Order {}", id)`.
- Never log PII, credentials, tokens, or full object graphs.
- Log levels: `ERROR` for unrecoverable failures; `WARN` for recoverable anomalies;
  `INFO` for significant state transitions; `DEBUG` for diagnostic detail.

---

## Naming Conventions

### Packages

- All lowercase, singular, no hyphens or underscores: `order`, `payment`, `notification`.
- Package names map to a domain or module concern — not to a technical layer or pattern.

### Classes & Interfaces

- Classes and interfaces: `UpperCamelCase`.
- Sealed interface hierarchies: the sealed interface is the noun; implementations are
  qualified variants — `PaymentResult`, `PaymentResult.Success`, `PaymentResult.Failure`.
- Enum class names: singular noun — `OrderStatus`, `PaymentMethod`, not `OrderStatuses`.
- Enum values: `UPPER_SNAKE_CASE` — `OrderStatus.PENDING`, `OrderStatus.CONFIRMED`.
- Constants: `UPPER_SNAKE_CASE` — `MAX_ORDER_LINES`, `DEFAULT_CURRENCY`.

### Methods

- Verb + noun expressing intent: `calculateTotal()`, `findByCustomerId()`.
- Omit the noun when the method is defined on the type it operates on and the noun would
  repeat the class name: `order.confirm()`, not `order.confirmOrder()`.
- Boolean methods: `is` or `has` prefix — `isConfirmed()`, `hasPaymentFailed()`.
- Avoid generic, intent-free names: never `process()`, `handle()`, `execute()`,
  `manage()`, `do*()`.
- If a method name requires `And` or `Or` to describe its behaviour, it has more than one
  responsibility — split it.

### Fields & Variables

- `lowerCamelCase` for all fields and local variables.
- Boolean fields: `is` or `has` prefix — `isConfirmed`, `hasPaymentFailed`.
- Collections: plural noun — `lines`, `payments`, `events`; never `list`, `items`, `data`.
- Avoid abbreviations unless universally understood — `id`, `dto`, `url` are acceptable;
  `ord`, `cust`, `svc` are not.

### Generic Type Parameters

- Single uppercase letter for simple, conventional cases: `T` (type), `E` (element),
  `K` / `V` (key/value), `R` (return type).
- Use a descriptive name when the type parameter has domain meaning or when two parameters
  of the same kind appear together: `<Source, Target>`, `<RequestT, ResponseT>`.

### Constants

- Never use magic values — unnamed literals (`0`, `100`, `"PENDING"`, `"USD"`) in logic are
  a maintenance hazard. Every value with business or technical meaning must be named.
- Declare constants as `static final` fields on the class that owns the concept.
  Do not create a `Constants` or `Config` utility class as a dumping ground — it is a
  god object in disguise.
- If a constant is shared across multiple classes, it belongs on the type it describes:
  `Order.MAX_LINES`, not `OrderConstants.MAX_ORDER_LINES`.
- Enum values are preferred over `static final` constants when the set of values is closed
  and exhaustive — `OrderStatus.PENDING` is safer than `String STATUS_PENDING = "PENDING"`.
- Never duplicate a constant — if two classes reference the same value, one should own it
  and the other should reference it.

### Tests

- Test class: `<ProductionClass>Test` — `PlaceOrderUseCaseTest`, `OrderResourceTest`.
- Integration test class: `<ProductionClass>IT` — `PlaceOrderIT`.
- Test method: `should_<expectedBehaviour>_when_<condition>` —
  e.g. `should_throw_when_order_has_no_lines`,
  e.g. `should_return_confirmed_status_when_payment_succeeds`.

---

## Maven

### Structure

- Single `pom.xml` at project root for single-module projects.
- Multi-module: parent POM manages versions and plugin configuration only; no build logic
  or dependencies declared directly in the parent.
- Use a BOM (`<dependencyManagement>`) to centralise dependency versions; import
  third-party BOMs (e.g. Quarkus BOM) before declaring individual overrides.
- Builds must be environment-portable: no hardcoded local paths, no machine-specific
  plugin configuration. Enforce this with the Maven Enforcer Plugin.

### Dependencies

- Never add a dependency without explicit approval; every dependency is a maintenance
  and supply-chain risk.
- Declare test-scoped dependencies with `<scope>test</scope>`.
- Define all dependency versions in `<properties>` — never inline in `<dependency>`.
- Do not pin a version that is already governed by an imported BOM; let the BOM control it.
- Exclude transitive dependencies explicitly when a conflict cannot be resolved by
  BOM alignment — document the reason in a comment.

### Plugins

- Pin all plugin versions explicitly in `<build><pluginManagement>` — never rely on
  Maven default versions, which vary by Maven installation.
- Plugin configuration belongs in `<pluginManagement>`, not inline per-module.
- Required plugins for every project:

| Plugin                          | Purpose                                              |
|---------------------------------|------------------------------------------------------|
| `maven-compiler-plugin`         | Enforces Java version and compiler flags             |
| `maven-surefire-plugin`         | Runs unit tests (`*Test`)                            |
| `maven-failsafe-plugin`         | Runs integration tests (`*IT`); bound to `verify`    |
| `maven-enforcer-plugin`         | Enforces Java version, Maven version, and no banned dependencies |
| `jacoco-maven-plugin`           | Measures and enforces test coverage thresholds       |

### Properties

- Define all reusable values (versions, paths, flags) in `<properties>`.
- Java version: `<maven.compiler.release>25</maven.compiler.release>`.
- Encoding: `<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>`.

### Versioning

- Release versions: `<major>.<minor>.<patch>` — e.g. `1.4.2`. No `-SNAPSHOT` suffix.
- Development versions: append `-SNAPSHOT` — e.g. `1.5.0-SNAPSHOT`.
- Never release a `SNAPSHOT` artifact to a production environment.
- Version bumps follow semantic versioning: breaking API change → major; new feature → minor;
  bug fix → patch.

### Profiles

- Profiles for environment or build-variant concerns only — e.g. `native`, `docker-push`.
- A profile must never alter dependency versions or change test scope.
- Profiles are opt-in (`-P<name>`) — the default build must succeed without any profile active.

### Commands

| Goal                         | Command                          | Notes                                      |
|------------------------------|----------------------------------|--------------------------------------------|
| Full build and test          | `mvn verify`                     | Default; runs unit and integration tests   |
| Compile only                 | `mvn compile`                    | Safe fast-path; no tests skipped           |
| Skip tests (last resort)     | `mvn verify -DskipTests`         | Never use in CI; document the reason if used locally |
| Native build                 | `mvn verify -Pnative`            |                                            |
| Dependency vulnerability scan| `mvn dependency-check:check`     | Run before every release                   |
