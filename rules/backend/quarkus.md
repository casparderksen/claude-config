# Rules: Java / Quarkus Backend Development

---

## Standards

- Import interfaces of specifications (Jakarta EE, MicroProfile) instead of implementations (Quarkus)
- Use CDI (`@ApplicationScoped`, `@RequestScoped`) — never `new`
- Prefer `@QuarkusTest` + REST Assured for integration tests
- Use Mutiny for reactive patterns where the operation is I/O-bound or explicitly non-blocking;
  prefer imperative (synchronous) code for transactional business logic — do not introduce
  reactive pipelines solely for style. Avoid raw `CompletableFuture` where Mutiny applies.
- Annotate JAX-RS methods with `@Blocking` when they perform blocking I/O (database, outbound
  HTTP) so RESTEasy Reactive dispatches them to a worker thread pool.
- Application config via `@ConfigMapping` interfaces, not raw `@ConfigProperty` on classes
- Native image compatibility: register reflection in `@RegisterForReflection` or `reflect-config.json`
- API: RESTEasy Reactive with OpenAPI spec; include annotations for documentation
- Auth: OIDC / OAuth2
- Database: PostgreSQL
- Messaging: Apache Kafka (via SmallRye Reactive Messaging)
- Integration Events: CloudEvents via Apache Kafka
- Use MapStruct for mapping from/to DTOs
- Use Flyway for database migrations
- Maven as build system

---

## Naming Conventions

### Bounded Context & Packages

- Base package: `<company>.<product>.<boundedcontext>` — e.g. `com.acme.shop.orders`,
  `com.acme.shop.payments`. The base package maps to a bounded context, not a layer.
- Sub-packages below the base package (`domain`, `application`, `infrastructure`, `adapter`)
  map to architectural layers — see [Package Structure](#package-structure).
- Package names are lowercase, singular, and contain no hyphens or underscores.

### Classes

Follow the naming pattern established in [Classes by Layer](#classes-by-layer):

| Type                | Convention                                        | Example                                      |
|---------------------|---------------------------------------------------|----------------------------------------------|
| Use case            | `<Verb><Noun>UseCase`                             | `PlaceOrderUseCase`                          |
| Command             | `<Verb><Noun>Command`                             | `PlaceOrderCommand`                          |
| Inbound port        | `<Verb><Noun>Port`                                | `PlaceOrderPort`                             |
| Domain event        | Past-tense noun phrase                            | `OrderPlaced`, `PaymentFailed`               |
| Entity / Aggregate  | Noun (no suffix)                                  | `Order`, `Customer`                          |
| Value Object        | Noun describing the concept                       | `Money`, `EmailAddress`, `OrderId`           |
| Repository port     | `<Aggregate>Repository`                           | `OrderRepository`                            |
| Repository impl     | `Panache<Aggregate>Repository`                    | `PanacheOrderRepository`                     |
| JAX-RS resource     | `<Aggregate>Resource`                             | `OrderResource`                              |
| Event consumer      | `<Aggregate>EventConsumer`                        | `OrderEventConsumer`                         |
| REST request DTO    | `<Verb><Noun>RequestDto`                          | `CreateOrderRequestDto`                      |
| REST response DTO   | `<Noun><Qualifier>ResponseDto`                    | `OrderResponseDto`, `OrderSummaryResponseDto`|
| Messaging DTO       | `<EventName>Event`                                | `OrderPlacedEvent`                           |
| Mapper              | `<Aggregate><Layer>Mapper`                        | `OrderRestMapper`, `OrderMessagingMapper`    |
| Config interface    | `<Concern>Config`                                 | `PaymentConfig`, `MessagingConfig`           |
| Exception           | Descriptive noun phrase ending in `Exception`     | `OptimisticLockConflictException`            |

### Methods

#### Use Case Entry Points

- Named as verb + noun, matching the command: `placeOrder(PlaceOrderCommand)`,
  `cancelSubscription(CancelSubscriptionCommand)`.
- Use case classes expose a single public entry point method; additional methods are private.

#### Repository Methods

Use the `findBy*` / `save` / `delete` / `existsBy*` vocabulary consistently:

| Purpose                  | Naming                                        |
|--------------------------|-----------------------------------------------|
| Lookup by identifier     | `findById`, `findByCustomerId`                |
| Existence check          | `existsById`                                  |
| Unbounded collection     | `findAll`                                     |
| Filtered collection      | `findBy<Criterion>` — e.g. `findByStatus`     |
| Persist (insert/update)  | `save`                                        |
| Remove                   | `delete`                                      |

Never use `get`, `fetch`, `retrieve`, or `load` as repository method prefixes.

#### Domain Behaviour Methods

- Use verb + noun to express intent: `allocateStock()`, `addOrderLine(...)`.
- Omit the noun when the method is defined on the aggregate it operates on — the class name
  already provides it: `order.confirm()`, `order.cancel()`, not `order.confirmOrder()`.
- Methods reveal *what* is happening in the domain — not *how* it is implemented.

#### Factory Methods

- Prefer static factory methods on aggregates over exposing public constructors:
  `Order.create(...)`, or delegation from the aggregate root: `customer.createOrder(...)`.
- Use the `create` prefix for static factories; the constructor remains package-private or
  `protected` (Hibernate no-arg constructor aside).

#### General

- Avoid generic, intent-free names: never `process()`, `handle()`, `execute()`, `manage()`, `do*()`, or `doSomething()`.
- If a method name requires `And`, `Or`, or a comment to be understood, it has more than one responsibility — split it.

---

## Architecture

- Follow Domain-Driven Design (DDD) patterns
- Structure packages in a layered architecture combining Onion, Clean, and Hexagonal architecture principles
- Domain classes and API contracts evolve independently and must not be coupled.

### Package Structure

```
src/main/java/<base-package>/
├── domain/                     # Innermost: pure Java, no framework dependencies
│   ├── model/                  # Entities, Value Objects (records), Aggregate Roots
│   ├── service/                # Domain Services — logic spanning multiple aggregates
│   ├── event/                  # Domain Events — past tense, represent facts
│   └── port/                   # Outbound ports — defines what the domain *needs*
├── application/                # Application Services (orchestration only)
│   ├── usecase/                # One class per use case — fetch, act, save, emit
│   └── port/                   # Inbound port interfaces — implemented by use cases, called by adapters
├── infrastructure/             # Implements domain ports; Quarkus/framework code lives here
│   ├── config/                 # @ConfigMapping interfaces — one per configuration concern
│   ├── persistence/            # Panache repositories, mappers
│   ├── messaging/              # Outbound evet producers, OutboxPublisher
│   └── client/                 # Outbound REST clients
└── adapter/                    # Driving adapters — delegate to application/port
    ├── rest/                   # JAX-RS resources — HTTP in, DTO mapping (to command)
    └── event/                  # Inbound event consumers — DTO mapping (to command)
```

### Classes by Layer

| Layer                        | Type                  | Example                                                    |
|------------------------------|-----------------------|------------------------------------------------------------|
| `domain/model`               | Entity                | `Order`, `Customer`, `Payment`                             |
| `domain/model`               | Value Object (record) | `OrderId`, `Money`, `EmailAddress`                         |
| `domain/model`               | Aggregate Root        | Same as Entity — implied by design                         |
| `domain/service`             | Domain Service        | `PricingService`, `OrderAllocationService`                 |
| `domain/event`               | Domain Event          | `OrderPlaced`, `PaymentFailed`, `CustomerActivated`        |
| `domain/port`                | Outbound Port         | `OrderRepository`, `PaymentGateway`, `NotificationService` |
| `application/usecase`        | Use Case              | `PlaceOrderUseCase`, `CancelSubscriptionUseCase`           |
| `application/usecase`        | Command               | `PlaceOrderCommand`, `CancelSubscriptionCommand`           |
| `application/port`           | Inbound Port          | `PlaceOrderPort`, `CancelSubscriptionPort`                 |
| `application/port`           | Outbox Port           | `OutboxRepository`                                         |
| `infrastructure/config`      | Config Interface      | `PaymentConfig`, `MessagingConfig`                         |
| `infrastructure/persistence` | Repository Impl       | `PanacheOrderRepository`, `PanacheCustomerRepository`      |
| `infrastructure/messaging`   | Event Publisher Impl  | `OutboxPublisher`                                          |
| `infrastructure/messaging`   | Outbound message DTO  | `SubscriptionCancelledEvent`                               |
| `infrastructure/messaging`   | Mapper                | `OrderMessagingMapper`, `PaymentMessagingMapper`           |
| `infrastructure/client`      | REST Client           | `PaymentGatewayClient`, `NotificationClient`               |
| `adapter/rest`               | Resource              | `OrderResource`, `CustomerResource`                        |
| `adapter/rest`               | Request DTO           | `CreateOrderRequestDto`, `UpdateCustomerRequestDto`        |
| `adapter/rest`               | Response DTO          | `OrderResponseDto`, `CustomerSummaryResponseDto`           |
| `adapter/rest`               | Mapper                | `OrderRestMapper`, `CustomerRestMapper`                    |
| `adapter/event`              | Consumer              | `OrderEventConsumer`, `PaymentEventConsumer`               |
| `adapter/event`              | Inbound message DTO   | `OrderPlacedEvent`, `PaymentFailedEvent`                   |
| `adapter/event`              | Mapper                | `OrderEventMapper`, `PaymentEventMapper`                   |

### Dependency Rules

- Dependencies point inward only: `adapter → application → domain` and `infrastructure → domain`.
- The `domain` layer must never import from `application`, `infrastructure`, or `adapter`.
- The `domain` layer must never import Quarkus, Jakarta EE, or any framework annotation,
  **with one deliberate exception**: JPA annotations (`@Entity`, `@Column`, `@OneToMany`, etc.)
  are permitted on domain entities because JPA entities *are* the domain model — see
  [JPA & Domain Model Strategy](#jpa--domain-model-strategy) for the full rationale and trade-offs.
- Domain model classes (`domain/model`) never call ports; only use cases (`application/usecase`)
  call ports — the domain only enforces invariants and raises events.

### JPA & Domain Model Strategy

JPA entities **are** the domain model — no separate mapping between domain and JPA classes.
Purity is traded for simplicity and performance; domain integrity is enforced through access
discipline (field access, no public setters, invariant-enforcing constructors).

This decision has one consequence for the dependency rules: JPA annotations from the
`jakarta.persistence` package are the **only** framework annotations permitted in `domain/model`.
No other Jakarta EE, MicroProfile, or Quarkus annotations may appear in the domain layer.

Full conventions for how JPA and the domain model co-exist are in the
[JPA Conventions](#jpa-conventions) section.

### Data Mapping Strategy

- Use MapStruct for cross-boundary mapping; never write manual mapping methods
  unless the transformation contains logic — in which case it belongs in a domain
  service or use case, not a mapper.
- Define one mapper interface per boundary and direction, e.g. `OrderRestMapper` (domain ↔ REST DTO).
- Mappers live in the layer that owns the non-domain type: REST mappers in `adapter/rest`,
  event mappers in `adapter/event`, messaging mappers in `infrastructure/messaging`.
- Annotate all mappers with `@Mapper(componentModel = "cdi")` for CDI injection.
- Mappers must never contain business logic; if a field requires computation or
  a rule, delegate to the domain or use case before mapping.
- Never expose domain classes in REST interfaces; always map to a dedicated
  request/response DTO in `adapter/rest`. Domain classes and API contracts evolve
  independently and must not be coupled.
- Use MapStruct's `nullValueMappingStrategy` and `nullValuePropertyMappingStrategy`
  explicitly on every mapper to avoid inconsistent null handling across the codebase.

### Pagination

All collection endpoints must support cursor- or offset-based pagination; unbounded queries
are not permitted.

- Accept `page` (0-based) and `size` (max 100, default 20) as query parameters on offset-based endpoints.
- Return a structured response wrapper that includes `content`, `totalElements`, `page`, and `size`.
- For large or append-only datasets, prefer keyset (cursor) pagination over offset to avoid
  performance degradation at high page numbers.
- Apply pagination at the repository level (JPQL `LIMIT`/`OFFSET` or `@EntityGraph` slice);
  never load all rows and slice in memory.

### Quarkus-Specific Rules

- Quarkus and Jakarta EE annotations (`@ApplicationScoped`, `@Transactional`, `@Inject`, etc.)
  are allowed only in `application` and `infrastructure` layers, never in `domain`
  (except JPA annotations on entities — see [JPA & Domain Model Strategy](#jpa--domain-model-strategy)).
- Panache repositories live in `infrastructure/persistence` and implement the domain repository interface.
- CDI injection crosses layers only downward (outer injects inner via interface).
- Use `@Transactional` on use case methods, not on domain or adapter methods.
- Use `@Transactional(readOnly = true)` on use case methods that perform read-only operations
  (queries with no mutations). This allows Hibernate to skip dirty checking and flush, and
  allows the JDBC driver or connection pool to optimise accordingly.

### Object Construction & Builders

Builders are prohibited on domain objects. Constructors and factory methods must enforce
invariants at the moment of creation — a builder allows objects to exist in an intermediate,
invalid state, which undermines aggregate and value object integrity.

| Context                        | Convention                                                                        |
|--------------------------------|-----------------------------------------------------------------------------------|
| Entity / Aggregate Root        | Static factory method (`Order.create(...)`) or constructor                        |
| Value Object                   | Record with compact constructor — no builder needed                               |
| Command                        | Record with compact constructor — immutable by nature; enforce null checks here   |
| Domain Event                   | Record — represents an immutable fact; no builder needed                          |
| Request / Response DTO         | Record for simple cases; Lombok `@Builder` when many fields are optional          |
| Inbound / Outbound message DTO | Record — serialisation frameworks (Jackson, Avro) support records natively        |
| Query / filter object          | Lombok `@Builder` — fluent construction aids readability                          |
| Test data                      | Dedicated `*TestBuilder` in `src/test` only                                       |

#### Lombok `@Builder`

- Permitted on request/response DTOs and query objects only.
- Never place `@Builder` on an entity or aggregate — it generates a public no-arg constructor
  path that bypasses invariant checks.
- Use `@Builder(toBuilder = true)` only where a copy-with-modification pattern is explicitly
  needed; do not apply it by default.

### Anti-patterns to Avoid

- Do not call repositories directly from REST adapters; always go through a use case.
- Do not expose domain classes in REST or event interfaces; always map to a dedicated request/response
  DTO in `adapter/rest` or `adapter/event`.
- Do not share DTOs between layers; map at each boundary.
- Do not create "god" application services that duplicate domain logic.

### DDD Patterns

- **Entities**: Have identity (`id`); encapsulate invariants; never expose setters.
- **Value Objects**: Immutable; equality by value; use Java `record` types.
- **Aggregates**: One Entity acts as root; enforce consistency boundaries; only the root is referenced externally.
- **Domain Services**: Stateless logic involving multiple aggregates or external resolution.
- **Domain Events**: Represent facts; named in past tense (`OrderPlaced`, `PaymentFailed`).
  Raised inside aggregates or domain services; collected by the use case after the domain
  operation for publishing via the outbox.
- **Repositories**: Interfaces in `domain/port`; return domain objects.
- **Application Services / Use Cases**: Coordinate domain objects and ports; handle transactions;
  emit domain events via the outbox.

### Ports & Adapters (Hexagonal)

- **Inbound ports**: Interfaces in `application/port` implemented by use case classes.
- **Outbound ports**: Interfaces in `domain/port` implemented by infrastructure classes.
- **Adapters** never contain business logic; they translate and delegate.

### SOLID & GRASP Principles

#### SOLID

- **Single Responsibility (SRP)**: One class, one reason to change. Use cases orchestrate;
  domain enforces invariants; adapters translate. Never mix these responsibilities.
- **Open / Closed (OCP)**: Extend behaviour by adding new classes, not modifying existing ones.
  New use cases get new classes; new adapters implement existing ports.
- **Liskov Substitution (LSP)**: Any implementation of a port must be substitutable without
  changing behaviour. `PanacheOrderRepository` must honour the full contract of `OrderRepository`.
- **Interface Segregation (ISP)**: Define narrow, focused port interfaces. Prefer
  `OrderRepository` with three methods over a generic `Repository<T>` with twenty.
- **Dependency Inversion (DIP)**: High-level modules never depend on low-level modules;
  both depend on abstractions. Use cases depend on port interfaces, never on infrastructure classes.

#### GRASP

- **Information Expert**: Assign responsibility to the class that has the information needed.
  Invariant checks belong on the aggregate, not the use case or adapter.
- **Low Coupling**: Depend on interfaces, not implementations. Cross-layer dependencies
  always point inward via port interfaces.
- **High Cohesion**: Keep classes focused. A use case that does too much is a signal to
  split the use case or move logic into the domain.
- **Controller**: Adapters (`OrderResource`, `OrderEventConsumer`) are controllers —
  they receive external input and delegate; they never contain logic.
- **Pure Fabrication**: Ports and mappers are pure fabrications — they do not represent
  domain concepts but exist to maintain low coupling and high cohesion.
- **Indirection**: Ports introduce indirection between use cases and infrastructure;
  this is intentional and the foundation of the hexagonal architecture.
- **Protected Variations**: Encapsulate what varies behind a port interface. Infrastructure
  details (Kafka, Panache, REST clients) are hidden behind domain ports so they can change
  without affecting the domain or use cases.

---

## JPA Conventions

### Field Access

- Annotate fields, not getters (`@Access(AccessType.FIELD)`)
- Hibernate hydrates via reflection — no setters required

### Constructors

- `protected` no-arg constructor for Hibernate only — document as such
- All real constructors enforce invariants and are the intended entry point

### Mutation Control

- No public setters — state changes only through intent-revealing domain methods (e.g. `order.cancel()`,
  `order.addLine(...)`)

### Collections

- Initialised at field declaration
- Never expose raw collection — return unmodifiable view
- Domain methods do surgical `add`/`remove` — never replace the collection reference
- Use `orphanRemoval = true` for children with no meaning outside the parent

### Fetch Strategy

- `FetchType.LAZY` as default on all associations — no accidental over-fetching
- Fetch strategy is explicit per use case at the repository level (`JOIN FETCH` / `@EntityGraph`)
- No reliance on lazy loading as a safety net — fetch decisions are deliberate and inspectable

### Dirty Checking

- Keep entities managed within the transaction — Hibernate detects mutations automatically
- If re-attachment is needed, reload from repository before applying changes

### Accepted Trade-offs

- Hibernate field access bypasses constructor invariants — acceptable as it reconstitutes previously-valid state
- `final` fields avoided on entity state — incompatible with Hibernate field access in practice
- `protected` no-arg constructor is a minor purity compromise — mitigated by access modifier and documentation

---

## Flyway — Database Migration Strategy

### Configuration

- Configure one Flyway instance per datasource using Quarkus named datasource syntax.
- Name datasources meaningfully — for example `primary`, `secondary` — in `application.properties`.
- Never use the default unnamed datasource when managing multiple databases; always name explicitly.

```properties
# Primary datasource (PostgreSQL)
quarkus.datasource.primary.db-kind=postgresql
quarkus.flyway.primary.locations=db/primary/migration
quarkus.flyway.primary.migrate-at-start=true

# Secondary datasource (PostgreSQL)
quarkus.datasource.secondary.db-kind=postgresql
quarkus.flyway.secondary.locations=db/secondary/migration
quarkus.flyway.secondary.migrate-at-start=true
```

### Script Location & Naming

```
src/main/resources/
└── db/
    ├── primary/
    │   └── migration/
    │       ├── V1__orders_create_table.sql
    │       └── V2__orders_add_confirmed_at_column.sql
    └── secondary/
        └── migration/
            └── V1__audit_create_log_table.sql
```

- Script naming: `V<version>__<bounded_context>_<description>.sql`
- Version numbers are sequential integers per datasource; never reuse or skip.
- Descriptions are lowercase snake_case and describe the change, not the ticket.
- Repeatable migrations (views, functions) use `R__<description>.sql`.

### Rules

- Follow the expand-contract (parallel change) pattern: the application codebase must tolerate
  running against a schema that is one migration version ahead. This means: deploy schema changes
  first (expand), deploy the new application version second, then clean up old schema artefacts
  in a follow-up migration (contract). New code must never depend on a schema version that has
  not yet been deployed.
- Column or table renames must be done in three steps: add new → migrate data → drop old;
  never in a single script.
- Keep a rollback plan for every migration; document it in a comment at the top of the script.
- Tag the Git commit that introduces a migration with the version number for traceability.
- All destructive changes (`DROP`, `DELETE`, `TRUNCATE`) require a peer review before merge.
- Never modify an existing migration script; always add a new versioned one.
- Never share migration scripts across datasources; each datasource owns its schema independently.
- Never use Flyway's `clean` in any environment other than local development;
  disable it explicitly in production configuration.
- Never perform data migrations in the same script as schema migrations; separate them
  into distinct versioned scripts.

---

## Error / Exception Handling Strategy

All exceptions are translated to HTTP or messaging responses at the adapter boundary.
Domain and application layers throw specific exception subtypes; adapters map them to
protocol-level responses. No exception escapes its layer unmapped.

### Exception Hierarchy

A single hierarchy rooted in `AppException` (abstract, extends `RuntimeException`).
Callers are never forced to declare or catch — exceptions propagate freely to the adapter
boundary where exception mappers handle them.

```
AppException (abstract, unchecked)              — base-package/exception/
├── DomainException (abstract)                  — domain/
│   ├── EntityNotFoundException                 → 404
│   └── BusinessRuleViolationException          → 422
└── ApplicationException (abstract)             — application/
    └── OptimisticLockConflictException         → 409
```

- `DomainException` subtypes originate in `domain/` — they represent violated business rules
  or unresolvable domain conditions.
- `ApplicationException` subtypes originate in `infrastructure/` or `application/` —
  they represent coordination or infrastructure failures that are not domain rule violations.
- `OptimisticLockConflictException` is thrown by `infrastructure/persistence` when
  `jakarta.persistence.OptimisticLockException` is caught; the domain has no knowledge
  of versioning or locking.
- Infrastructure exceptions (JDBC, network, serialisation) are caught in `infrastructure/`
  and rethrown as `ApplicationException` subtypes, or allowed to propagate as uncaught
  `AppException` subclasses that the 500-mapper handles as a last resort.
- Never throw `AppException` directly — always throw a named subtype.

### HTTP Exception Mapping

All exception mappers are `@ServerExceptionMapper` implementations in `adapter/rest`.
Responses use RFC 7807 Problem Details (`application/problem+json`).
Define one mapper per exception type — never a single catch-all mapper.

| Exception                          | HTTP Status | Notes                                                       |
|------------------------------------|-------------|-------------------------------------------------------------|
| `ConstraintViolationException`     | 400         | Include field-level violation details in body               |
| `EntityNotFoundException`          | 404         | Suppress internal identifiers in the response body          |
| `BusinessRuleViolationException`   | 422         | Include a machine-readable `type` URI                       |
| `OptimisticLockConflictException`  | 409         | Client must retry with refreshed state                      |
| `UnauthorizedException` (Quarkus)  | 401         | Thrown by the OIDC layer; map to RFC 7807 body              |
| `ForbiddenException` (Quarkus)     | 403         | Thrown by the OIDC layer; map to RFC 7807 body              |
| All others                         | 500         | Log with full stack trace and trace ID; return generic body |

Use `io.quarkus.security.UnauthorizedException` and `io.quarkus.security.ForbiddenException`
as the exception types in security mappers — not `java.lang.SecurityException`.

### Rules

- Every `500` response must be logged at `ERROR` level with the OpenTelemetry trace ID
  included in the log record; the trace ID must be suppressed from the response body.
- Never expose stack traces, internal class names, or SQL in any response body.
- Domain and application layers must not import any Jakarta REST or HTTP types;
  exception translation is exclusively an adapter responsibility.
- Event consumers distinguish failure modes:
  - **Transient** (infrastructure unavailable, timeout) → `nack` to trigger Kafka retry.
  - **Permanent** (malformed payload, failed deserialisation, business rule violation)
    → log at `ERROR`, emit to dead-letter topic, `ack` to prevent infinite retry.

---

## Validation Strategy

Validation enforces structural and syntactic correctness at the boundary — it is not a substitute
for domain invariants. Domain objects enforce their own rules programmatically; adapters validate
that incoming data is well-formed before it reaches the application layer.

### Responsibility Split

| Layer              | Responsibility                                                       | Mechanism                            |
|--------------------|----------------------------------------------------------------------|--------------------------------------|
| `adapter/rest`     | Validate request DTOs — presence, format, size, pattern              | Bean Validation (`@Valid` on param)  |
| `adapter/event`    | Validate inbound message DTOs — required fields, known enum values   | Bean Validation (`@Valid` on param)  |
| `domain/`          | Enforce business invariants — consistency rules, state constraints   | Constructor / domain method guards   |
| `application/`     | No validation — orchestration only                                   | —                                    |
| `infrastructure/`  | No validation — delegate to DB constraints as a last-resort backstop | —                                    |

### Rules

- Annotate `@Valid` on every JAX-RS resource method parameter that accepts a
  request DTO; RESTEasy Reactive triggers Bean Validation automatically.
- Place Bean Validation annotations (`@NotNull`, `@NotBlank`, `@Size`,
  `@Pattern`, `@Min`, `@Max`) on request and event DTO fields only — never on
  domain model classes.
- Never duplicate domain invariant checks as Bean Validation constraints;
  structural validity (non-null, max-length) and business validity (sufficient
  funds, valid state transition) are different concerns and must not be
  conflated.
- Custom `ConstraintValidator` implementations belong in the adapter layer that
  owns the DTO.
- `@ConfigMapping` injection points must be annotated with `@Valid` to fail fast
  at startup on missing or invalid configuration.
- A `ConstraintViolationException` must always be caught by an exception mapper
  (see Error/Exception Handling Strategy) and translated to a structured `400
  Bad Request` — never let the default Quarkus response escape.

---

## Observability

Observability is an infrastructure and adapter concern — domain and application layers must not
contain logging, metrics, or tracing code. All cross-cutting instrumentation is applied at the
boundaries.

### Logging

- Use `io.quarkus.logging.Log` (static logger) in all application code; no field-injected logger instances.
- Log format: JSON in `staging` and `prod`; plain text in `dev` and `test`.
- Every log record in non-local environments must include the OpenTelemetry trace ID and span ID
  via MDC — `quarkus-opentelemetry` injects these automatically; do not implement custom correlation.
- Log levels by layer:

| Layer              | Level           | Content                                               |
|--------------------|-----------------|-------------------------------------------------------|
| `adapter/rest`     | `INFO`          | Incoming request method + path (no body, no PII)      |
| `adapter/event`    | `INFO`          | Consumed Kafka topic, partition, offset               |
| `application/`     | `DEBUG`         | Use case entry, command summary (no sensitive fields) |
| `infrastructure/`  | `DEBUG` / `WARN`| Repository calls; warn on retry or fallback           |
| Exception mappers  | `ERROR`         | Full exception for 500s; `WARN` for 4xx               |

- Never log PII, credentials, tokens, or full request/response bodies.
- Never log inside domain classes.

### Metrics

Use `quarkus-micrometer` with the Prometheus registry. Metrics are defined in `infrastructure/`
or `adapter/` — never in domain or application layers.

- Expose a custom counter for each significant business event
  (`orders.placed`, `payments.failed`, `subscriptions.cancelled`); technical metrics alone
  are insufficient for production alerting.
- Tag metrics with `bounded_context` and `use_case` labels for dashboarding.
- Prefer injecting `MeterRegistry` directly and recording metrics programmatically in
  `infrastructure/` or `adapter/` classes; Micrometer's `@Timed` annotation requires
  a CDI interceptor binding and may not fire correctly on all proxy configurations —
  use it only when the interceptor behaviour has been verified in tests.
- Use `@Counted` on exception mapper handlers to track error rates by type.

### Tracing

- Enable `quarkus-opentelemetry`; automatic instrumentation covers JAX-RS, Panache,
  Kafka producers and consumers, and outbound REST clients.
- Add manual `@WithSpan` on use case methods to make business operations visible
  as named spans in distributed traces.
- Propagate the trace context across Kafka messages using the standard
  OpenTelemetry propagation headers (`traceparent`, `tracestate`).

### Health

- Implement `HealthCheck` in `infrastructure/` for every external dependency:
  database, Kafka broker, and each outbound REST client.
- Liveness (`/q/health/live`): JVM alive; never check external dependencies here.
- Readiness (`/q/health/ready`): all infrastructure dependencies reachable and schema migrated.
- Never expose internal topology or version details in health check responses in production.

---

## Transactional Outbox and Idempotent Consumer

### Transactional Outbox

Publishing domain events directly to Kafka inside a business transaction creates
a dual-write problem: the database commit and the broker publish are not atomic. The transactional
outbox pattern resolves this by writing events to an `outbox` table in the same transaction as
the business data; a separate publisher reads and forwards them to Kafka.

#### Outbox Table Schema

```sql
CREATE TABLE outbox (
    id             UUID         PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id   VARCHAR(100) NOT NULL,
    event_type     VARCHAR(200) NOT NULL,
    payload        JSONB        NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at   TIMESTAMPTZ
);

CREATE INDEX idx_outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;
```

#### Package Placement

The `OutboxRepository` port lives in `application/port`, not `domain/port`, because the
transactional outbox is a messaging reliability pattern — an application-layer concern — not a
domain concept. The domain raises events; the use case decides how they are durably forwarded.

| Class                     | Package                       | Responsibility                                      |
|---------------------------|-------------------------------|-----------------------------------------------------|
| `OutboxEntry`             | `infrastructure/persistence`  | JPA entity for the outbox table                     |
| `OutboxRepository`        | `application/port`            | Outbound port; use case writes events through this  |
| `PanacheOutboxRepository` | `infrastructure/persistence`  | Implements port; inserts outbox rows                |
| `OutboxPublisher`         | `infrastructure/messaging`    | Reads unpublished rows; publishes; marks published  |

#### Rules

- Use cases write to the outbox via the `OutboxRepository` port inside the same `@Transactional`
  method that mutates business data — never outside the transaction.
- Prefer Debezium CDC (PostgreSQL WAL → Kafka) as the outbox publisher; it has zero polling delay
  and does not require a scheduled job or application-level locking.
- If Debezium is not available, implement a polling publisher with `@Scheduled` in
  `infrastructure/messaging`; use `SELECT … FOR UPDATE SKIP LOCKED` to prevent concurrent
  publisher instances from processing the same row.
- The outbox payload is the serialised messaging DTO from `infrastructure/messaging`, not the
  domain event — the translation happens before insertion.
- Retain published outbox rows for at least 7 days for auditability; purge with a scheduled cleanup job.
- Route to the correct Kafka topic using the `event_type` column; the publisher must not contain
  topic-selection logic beyond a mapping table — new event types extend the map, not the publisher.

### Idempotent Consumer

At-least-once delivery guarantees that a Kafka consumer may receive the same message more than once.
Every `adapter/event` consumer must be idempotent: processing a duplicate message must produce
the same outcome as processing it once, with no side effects.

#### Processed Messages Table

```sql
CREATE TABLE processed_messages (
    message_id     UUID         PRIMARY KEY,
    consumer_group VARCHAR(200) NOT NULL,
    processed_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
```

Clean up records older than the Kafka broker's retention window on a scheduled basis.

#### Idempotency Protocol

Within a single `@Transactional` method in `adapter/event`:
1. Resolve the idempotency key from the message (CloudEvents `ce_id` header, Kafka record key,
   or a field in the payload — in that priority order).
2. Attempt to insert into `processed_messages`; if the row already exists, `ack` the message
   and return without calling the use case.
3. Execute the use case.
4. Commit — the `processed_messages` insert and the business mutation commit atomically.

#### Package Placement

`IdempotencyGuard` lives in `infrastructure/persistence` and is injected directly into
`adapter/event` consumers. This is a deliberate exception to the strict dependency rule:
the idempotency check must participate in the same transaction as the use case, and
wrapping it in a port would add indirection with no benefit. Document this at each
injection site with a comment.

| Class                 | Package                       | Responsibility                                          |
|-----------------------|-------------------------------|---------------------------------------------------------|
| `ProcessedMessage`    | `infrastructure/persistence`  | JPA entity                                              |
| `IdempotencyGuard`    | `infrastructure/persistence`  | Checks and records message IDs; injected into consumers |
| `OrderEventConsumer`  | `adapter/event`               | Calls `IdempotencyGuard` before delegating to use case  |

#### Rules

- Never rely on business-level deduplication (e.g., checking whether an order already exists)
  as the sole idempotency mechanism; it conflates two concerns and breaks when the business
  condition is ambiguous.
- The idempotency check and the use case invocation must be in the same transaction;
  a rollback on the use case must also roll back the `processed_messages` insert.
- If no reliable idempotency key is present in the message, reject it as malformed
  and route to the dead-letter topic — do not invent a key.
- `IdempotencyGuard` must not appear in use case code.
- Consumers must handle the idempotency check failure (duplicate) silently at `INFO` level,
  not `WARN` — duplicates are expected, not anomalous.

---

## Event Schema Versioning

Kafka messages are durable and consumers may lag behind producers by hours or days. Schema
changes must never break existing consumers.

- Use Apache Avro or JSON Schema with a Schema Registry (Confluent or Apicurio) for all
  Kafka message types; register schemas as part of the CI pipeline.
- Follow backward-compatible evolution rules: add optional fields only; never remove or rename
  fields; never change field types.
- When a breaking change is unavoidable, introduce a new event type (e.g., `OrderPlacedV2`)
  and publish both versions in parallel until all consumers have migrated.
- Include a `schemaVersion` field in every message DTO so consumers can branch on version
  when compatibility cannot be maintained.
- Version changes to the schema must be reviewed and approved before merge — treat them as
  a breaking API change.

---

## Configuration

All application configuration is managed through `@ConfigMapping` interfaces.
Raw `@ConfigProperty` field injection is not permitted. Configuration is grouped
by concern, typed, validated at startup, and never scattered across classes.

### `@ConfigMapping` Interfaces

- Define one `@ConfigMapping` interface per configuration concern
  (e.g. `PaymentConfig`, `MessagingConfig`, `OidcClientConfig`).
- Place all `@ConfigMapping` interfaces in `infrastructure/config/`.
- Use nested interfaces to model hierarchical property groups.
- Annotate the **injection point** with `@Valid` (not the interface itself) and apply Bean
  Validation constraints on interface methods to enforce required values and ranges at startup.
- Never inject a `@ConfigMapping` interface into `domain/` — configuration is an
  infrastructure concern.

```java
@ConfigMapping(prefix = "payment")
public interface PaymentConfig {
    @NotBlank URI gatewayUrl();
    @DurationMin("1s") Duration timeout();
    RetryConfig retry();

    interface RetryConfig {
        @Min(1) @Max(10) int maxAttempts();
        @DurationMin("100ms") Duration backoff();
    }
}

// Injection point — @Valid triggers validation at startup
@Inject
@Valid
PaymentConfig paymentConfig;
```

### Property Files

Quarkus resolves configuration in priority order (highest first):

1. Environment variables
2. `.env` file (local only — never committed)
3. `application-{profile}.properties`
4. `application.properties`

- `application.properties` contains only non-sensitive, environment-independent defaults
  and structural settings (datasource kind, Flyway locations, extension configuration).
- Never put environment-specific values in `application.properties` — they belong in a
  profile-specific file or are injected via environment variable.

### Environment-Dependent Variables

Use Quarkus profiles to separate environment-specific configuration:

```
src/main/resources/
├── application.properties            # Shared defaults; no secrets; no env-specific values
├── application-dev.properties        # Local development overrides
├── application-test.properties       # Test profile — in-memory or Testcontainers config
├── application-staging.properties    # Staging — references env var expressions
└── application-prod.properties       # Production — references env var expressions only
```

In `staging` and `prod` profiles, all environment-specific values are expressed as
environment variable references — never hardcoded:

```properties
# application-prod.properties
quarkus.datasource.primary.jdbc.url=${DB_PRIMARY_URL}
quarkus.datasource.primary.username=${DB_PRIMARY_USER}
quarkus.datasource.primary.password=${DB_PRIMARY_PASSWORD}
quarkus.oidc.auth-server-url=${OIDC_AUTH_SERVER_URL}
payment.gateway-url=${PAYMENT_GATEWAY_URL}
payment.timeout=${PAYMENT_TIMEOUT:10s}
```

The `${VAR:default}` syntax is permitted only for non-sensitive values where a
sensible default exists; never use it for secrets or environment-specific URLs.

### Secrets

- Never store secrets in any properties file or in version control.
- Secrets are injected exclusively via environment variables or a secrets manager
  (`quarkus-vault` for HashiCorp Vault, or the platform's native secret store).
- A secret is any value that grants access or could cause harm if exposed:
  passwords, API keys, client secrets, private keys, tokens.
- `@ConfigMapping` interface methods that represent secrets must be annotated with
  `@io.smallrye.config.Secret` to suppress their value from logs and config dumps.
- Never include secret values in health check responses, startup logs, or exception messages.

### Rules

- `application.properties` must be committable without exposing any secret or
  environment-specific value — if it cannot be committed safely, a property is misplaced.
- Do not use `%dev.`, `%prod.` inline profile prefixes in `application.properties`
  for anything beyond trivial dev-mode convenience settings;
  use dedicated profile files instead.
- Never read `System.getenv()` or `System.getProperty()` directly in application code;
  all configuration access goes through `@ConfigMapping` interfaces.
- Fail fast: missing or invalid required configuration must prevent startup, not cause a
  runtime failure after the service has begun handling requests.
- Document every non-obvious configuration property with a comment in the properties file.

---

## Security

Authentication and coarse-grained authorisation are enforced at the adapter boundary by the
Quarkus OIDC filter before any application code runs. Fine-grained, business-aware authorisation
is enforced in the use case. The domain layer has no knowledge of the security context.

### Authentication

- Use `quarkus-oidc` exclusively; never implement custom token parsing or session management.
- Configure the OIDC provider in `application.properties` via `quarkus.oidc.*`;
  use `@ConfigMapping` for any application-level OIDC properties.
- Bearer token authentication is the default for machine-to-machine and SPA clients;
  enable Authorization Code Flow only when the Quarkus service itself serves a browser UI.
- In `adapter/rest` tests, use `@TestSecurity` with `@OidcSecurity` to simulate authenticated
  identities without a running OIDC provider — do not mock `SecurityIdentity` with a mocking
  framework for HTTP-layer tests.
- In `application/` use case tests (which do not go through the HTTP layer), inject a
  `SecurityIdentity` CDI test producer to supply a controlled identity without a live OIDC
  provider. This is distinct from mocking: it uses CDI's `@Alternative` / `@Priority`
  mechanism, not a mocking framework stub.
- Use Quarkus OIDC Dev Services (Keycloak) for local development; it spins automatically
  and eliminates the need for a shared or mocked OIDC provider in `dev` mode.

### Authorisation

Authorisation operates at two levels:

| Level          | Mechanism                                                     | Location              | Use for                                             |
|----------------|---------------------------------------------------------------|-----------------------|-----------------------------------------------------|
| Coarse-grained | `@RolesAllowed`                                               | `adapter/rest`        | Restrict endpoint access by role                    |
| Fine-grained   | `@PermissionsAllowed` / programmatic `SecurityIdentity` check | `application/usecase` | Enforce ownership, tenancy, or resource-level rules |

- Every JAX-RS resource method must carry an explicit authorisation annotation —
  `@RolesAllowed`, `@Authenticated`, or `@PermitAll`. An unannotated method is a defect.
- `@PermitAll` requires a comment explaining why the endpoint is public.
- Fine-grained checks that require domain context (e.g., "only the order owner may cancel")
  belong in the use case, resolved against the domain object after it is loaded —
  never pre-checked solely from token claims.
- Inject `SecurityIdentity` into use cases via CDI when programmatic checks are needed;
  never pass raw tokens or claims as method arguments across layer boundaries.
- Domain classes must never reference `SecurityIdentity` or any security type.

### Secrets Management

- Never store secrets (client secrets, private keys, database passwords, API keys)
  in any properties file or in version control.
- Inject secrets via environment variables or a secrets manager
  (`quarkus-vault` for HashiCorp Vault, or the platform's native secret store).
- Reference secrets in properties files using environment variable expressions:
  `quarkus.oidc.credentials.secret=${OIDC_CLIENT_SECRET}`.
- `@ConfigMapping` interface methods that represent secrets must be annotated with
  `@io.smallrye.config.Secret` to suppress their value from logs and config dumps.
- Never include secret values in health check responses, startup logs, or exception messages.

### Transport Security

- Terminate TLS at the load balancer or ingress; configure `quarkus.http.insecure-requests=redirect`
  to enforce HTTPS at the application level in non-local environments.
- Never disable hostname verification on outbound REST clients (`quarkus-rest-client-reactive`);
  trust store configuration is mandatory for clients calling internal services over TLS.
- Do not log request or response bodies on TLS-terminated traffic; assume all traffic
  may contain sensitive payloads.

### CORS

- Configure CORS explicitly via `quarkus.http.cors.*`; never rely on the default permissive
  configuration in non-local environments.
- Restrict `quarkus.http.cors.origins` to known, enumerated origins in `staging` and `prod`.
- Do not use wildcard (`*`) origins in any environment where authentication cookies or
  `Authorization` headers are sent.

### Secure Defaults

- Deny by default: a new endpoint is locked down until an explicit authorisation annotation
  is added. Enable `quarkus.security.jaxrs.deny-unannotated-endpoints=true` to enforce this
  at startup.
- Never trust claims from the request body or query string to establish identity;
  identity is derived exclusively from the validated bearer token.
- Validate that the token `aud` (audience) claim matches the service's expected identifier;
  configure `quarkus.oidc.token.audience` explicitly.
- Strip sensitive response headers (`Server`, `X-Powered-By`) via a server filter in `adapter/rest`.

### Security Testing

- Every protected endpoint must have a test asserting `401` when called without a token
  and `403` when called with a token that lacks the required role.
- Use `@TestSecurity` with named roles in `adapter/rest` tests to cover role-based paths
  without a live OIDC provider.
- Fine-grained use case authorisation tests supply a controlled `SecurityIdentity` via a
  CDI `@Alternative` producer — they do not go through the HTTP layer and do not use
  a mocking framework to stub `SecurityIdentity`.
- Never use `@PermitAll` on infrastructure endpoints (`/q/health`, `/q/metrics`) in production
  configuration; scope them to internal network access at the infrastructure level.

---

## Testing Strategy

Tests must be written alongside implementation, never deferred.

### Test Types and Location

```
src/test/java/<base-package>/
├── domain/           # Pure unit tests; no mocks of domain internals
├── application/      # Use case tests; mock outbound ports
├── infrastructure/   # Integration tests; real DB via Testcontainers
├── adapter/rest/     # API tests via Quarkus @QuarkusTest + REST-assured
└── adapter/event/    # Consumer tests; assert correct command reaches use case and
                      # malformed payload is handled gracefully; mock use case only
```

### Rules

- Domain classes must be testable with plain `new` — no Quarkus context, no mocks.
- Use case tests mock only outbound ports (`OrderRepository`, `PaymentGateway`); never mock domain objects.
- Do not test mappers in isolation unless they contain conditional logic; cover them
  implicitly through adapter or use case tests.
- Use Testcontainers for all infrastructure tests involving a real database or Kafka broker.
- Use `@QuarkusTest` only in `adapter/rest` tests; do not use it for domain or use case tests.
- Use REST-assured for REST adapter tests; assert on HTTP contract (status, headers, body shape),
  not on internal domain state.
- One test class per production class; name it `<ProductionClass>Test`.
- Integration tests that require a running Quarkus instance are suffixed `IT` —
  `PlaceOrderIT` — and run in a separate Maven phase.

### Test Responsibilities

Each test class has a single responsibility. Tests trust that other layers are verified
by their own tests — never re-test logic that belongs to another layer.

| Test location                | Verifies                                              | Mocked                                  |
|------------------------------|-------------------------------------------------------|-----------------------------------------|
| `domain/`                    | Business rules, invariants, state transitions         | Nothing — plain `new`, no mocks         |
| `application/`               | Use case orchestration — fetch, act, save, emit       | Outbound ports (repositories, gateways) |
| `infrastructure/persistence` | Domain object persisted and rehydrated correctly      | Nothing — Testcontainers only           |
| `infrastructure/messaging`   | Event serialised and published correctly              | Kafka broker (Testcontainers)           |
| `infrastructure/client`      | Domain port contract honoured under success and error | External HTTP (WireMock)                |
| `adapter/rest`               | HTTP contract — request mapped, response shaped       | Use case                                |
| `adapter/event`              | Message mapped to correct command                     | Use case                                |

### The Testing Chain

Each layer trusts the layer below it is already verified:
- `adapter/event`        proves:  message        → correct command
- `adapter/rest`         proves:  HTTP request   → correct command
- `application/`         proves:  command        → correct domain orchestration
- `domain/`              proves:  domain         → invariants enforced
- `infrastructure/`      proves:  domain object  → correctly persisted / published

A failure at any link in the chain is caught by that link's own tests —
not by re-testing it from above.

### Coverage Expectations

- `domain/`: every business rule, invariant, and state transition must have a dedicated test;
  untested domain logic is a defect waiting to happen. Target 90–100%.
- `application/`: every use case path — success, not-found, and domain exception — must be
  covered; orchestration errors are as critical as domain errors. Target 80–90%.
- `infrastructure/persistence/`: cover happy path, optimistic locking failure, and constraint
  violation scenarios per repository; exhaustive coverage has diminishing returns. Target 60–70%.
- `infrastructure/messaging/`: cover successful publish and serialisation failure; do not
  re-test domain logic here. Target 60–70%.
- `infrastructure/client/`: cover successful call, timeout, and error response mapping
  per client; assert that domain port contract is honoured. Target 60–70%.
- `adapter/rest/`: cover success, validation failure, not-found, and unauthorised per endpoint;
  assert on HTTP contract only — never on internal domain state. Target 70–80%.
- `adapter/event/`: cover successful mapping and malformed payload handling per consumer;
  assert that the correct command reaches the use case. Target 70–80%.

Overall target is 80%. This number is only meaningful if the lower-coverage layers are
infrastructure and adapters. Untested domain logic with high adapter coverage is worse
than lower overall coverage with complete domain coverage — adapters test wiring,
not correctness.
