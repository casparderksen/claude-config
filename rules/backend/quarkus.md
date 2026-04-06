# Rules: Java / Quarkus Backend Development

---

### Tech Stack

- **API**: RESTEasy Reactive + OpenAPI
- **Auth**: OIDC / OAuth2 via `quarkus-oidc`
- **Database**: PostgreSQL, JDBC Panache
- **Mapping**: MapStruct
- **Migrations**: Flyway
- **Messaging**: Apache Kafka via SmallRye Reactive Messaging; CloudEvents for integration events
- **Reactive patterns**: Mutiny (but prefer simple sync code for transactional business logic)
- **Build**: Maven
- **Unit & integration tests**: JUnit 5, Mockito
- **REST adapter tests**: `@QuarkusTest` + REST Assured
- **Infrastructure tests**: Testcontainers (database, Kafka), WireMock (REST clients)
- **Acceptance tests**: Cucumber

---

## Architecture

### Package Structure

```
src/main/java/<base-package>/
├── domain/                     # Innermost: pure Java, no framework dependencies
│   ├── model/                  # Entities, Value Objects (records), Aggregate Roots
│   ├── service/                # Domain Services - logic spanning multiple aggregates
│   ├── event/                  # Domain Events - past tense, represent facts
│   └── port/                   # Outbound ports - defines what the domain *needs*
├── application/                # Application Services (orchestration only)
│   ├── usecase/                # One class per use case - fetch, act, save, emit
│   └── port/                   # Inbound port interfaces - implemented by use cases, called by adapters
├── infrastructure/             # Implements domain ports; Quarkus/framework code lives here
│   ├── config/                 # @ConfigMapping interfaces - one per configuration concern
│   ├── persistence/            # Panache repositories, - implement domain ports
│   ├── messaging/              # Outbound event producers, OutboxPublisher
│   └── client/                 # Outbound REST clients
└── adapter/                    # Driving adapters - delegate to application/port
    ├── rest/                   # JAX-RS resources - HTTP in, DTO mapping (to command)
    └── event/                  # Inbound event consumers - DTO mapping (to command)
```

### Dependency Rules

- Dependencies point inward only: `adapter → application → domain` and `infrastructure → domain`.
- The `domain` layer must never import from `application`, `infrastructure`, or `adapter`.
- The `domain` layer must never import Quarkus, Jakarta EE, or any framework annotation,
  **with one deliberate exception**: JPA annotations (`@Entity`, `@Column`, `@OneToMany`, etc.)
  are permitted on domain entities because JPA entities *are* the domain model - see
  [JPA & Domain Model Strategy](#jpa--domain-model-strategy).
- Domain model classes (`domain/model`) never call ports; only use cases (`application/usecase`)
  call ports - the domain only enforces invariants and raises events.
- Dependency Injection via CDI (use `@ApplicationScoped`, `@RequestScoped`; never `new`)
- CDI injection crosses layers only downward (outer injects inner via interface).
- Quarkus and Jakarta EE annotations (`@ApplicationScoped`, `@Transactional`,
  `@Inject`, etc.) are allowed only in `application` and `infrastructure`
  layers, never in `domain` (except JPA annotations on entities;
  see [JPA & Domain Model Strategy](#jpa--domain-model-strategy)).

### Anti-patterns to Avoid

- Do not call repositories directly from REST adapters; always go through a use case.
- Do not expose domain classes in REST or event interfaces; always map to a
  dedicated request/response DTO in `adapter/rest` or `adapter/event`.
- Do not share DTOs between layers; map at each boundary.
- Do not create "god" application services that duplicate domain logic.

### JPA & Domain Model Strategy

JPA entities **are** the domain model - no separate mapping between domain and JPA classes.
Purity is traded for simplicity and performance; domain integrity is enforced through access
discipline (field access, no public setters, invariant-enforcing constructors).

JPA annotations from the `jakarta.persistence` package are the **only** framework annotations
permitted in `domain/model`. No other Jakarta EE, MicroProfile, or Quarkus annotations may
appear in the domain layer.

### Data Mapping Strategy

- Use MapStruct for cross-boundary mapping; never write manual mapping methods
  unless the transformation contains logic - in which case it belongs in a domain
  service or use case, not a mapper.
- Define one mapper interface per boundary and direction, e.g.
  `OrderRestMapper` (domain ↔ REST DTO).
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

- Accept `page` (0-based) and `size` (max 100, default 20) as query parameters
  on offset-based endpoints.
- Return a structured response wrapper that includes `content`, `totalElements`, `page`, and `size`.
- For large or append-only datasets, prefer keyset (cursor) pagination over offset to avoid
  performance degradation at high page numbers.
- Apply pagination at the repository level (JPQL `LIMIT`/`OFFSET` or `@EntityGraph` slice);
  never load all rows and slice in memory.

### Object Construction & Builders

- Builders are prohibited on domain objects; constructors and factory methods
  must enforce invariants at the moment of creation.
- Entities and aggregate roots use a static factory method
  (`Order.create(...)`) or an invariant-enforcing constructor.
- Generate aggregate IDs as UUIDs (v7) in the static factory method; never use
  database-generated sequences for aggregate root identity.
- Value objects, commands, domain events, and inbound/outbound message DTOs use
  Java records with a compact constructor.
- Request/response DTOs use a record for simple cases; Lombok `@Builder` when many fields are optional.
- Query/filter objects use Lombok `@Builder` for fluent construction.
- Test data uses a dedicated `*TestBuilder` in `src/test` only.
- Never place `@Builder` on an entity or aggregate - it bypasses invariant checks.
- Use `@Builder(toBuilder = true)` only where a copy-with-modification pattern is explicitly needed.

### Transaction Management

- Use `@Transactional` on use case methods, not on domain or adapter methods.
- Use `@Transactional(readOnly = true)` on use case methods that perform read-only operations
  (queries with no mutations). This allows Hibernate to skip dirty checking and flush, and
  allows the JDBC driver or connection pool to optimise accordingly.

### Transactional Outbox

- Use the transactional outbox pattern to publish domain events to Kafka; never publish directly
  from within a business transaction (dual-write problem).
- Outbox writes must occur inside the same `@Transactional` method that mutates business data;
  the outbox row and the business mutation commit atomically.
- The outbox payload is the serialised messaging DTO (from `infrastructure/messaging`), not the
  raw domain event - translate before writing.
- Retain published outbox rows for at least 7 days for auditability; purge on a schedule.

### Idempotent Consumer 

- Every `adapter/event` consumer must be idempotent; deduplicate by persisting processed message IDs
  inside the same transaction as the use case invocation.
- Resolve the idempotency key in priority order: CloudEvents `ce_id` header → Kafka record key →
  payload field. Reject as malformed and dead-letter if no reliable key is present.
- Duplicate messages must be acknowledged silently at `INFO` level - duplicates are expected, not anomalous.

---

## Naming Conventions

### Bounded Context & Packages

- Base package: `<company>.<product>.<boundedcontext>` - e.g. `com.acme.shop.orders`,
  `com.acme.shop.payments`. The base package maps to a bounded context, not a layer.
- Sub-packages below the base package (`domain`, `application`, `infrastructure`, `adapter`)
  map to architectural layers - see [Package Structure](#package-structure).
- Package names are lowercase, singular, and contain no hyphens or underscores.

### Classes

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
| Filtered collection      | `findBy<Criterion>` - e.g. `findByStatus`     |
| Persist (insert/update)  | `save`                                        |
| Remove                   | `delete`                                      |

Never use `get`, `fetch`, `retrieve`, or `load` as repository method prefixes.

#### Domain Behaviour Methods

- Use verb + noun to express intent: `allocateStock()`, `addOrderLine(...)`.
- Omit the noun when the method is defined on the aggregate it operates on - the class name
  already provides it: `order.confirm()`, `order.cancel()`, not `order.confirmOrder()`.
- Methods reveal *what* is happening in the domain - not *how* it is implemented.

#### Factory Methods

- Prefer static factory methods on aggregates over exposing public constructors:
  `Order.create(...)`, or delegation from the aggregate root: `customer.createOrder(...)`.
- Use the `create` prefix for static factories; the constructor remains package-private or
  `protected` (Hibernate no-arg constructor aside).

#### General

- Avoid generic, intent-free names: never `process()`, `handle()`, `execute()`,
  `manage()`, or `doSomething()`.
- If a method name requires `And`, `Or`, or a comment to be understood, it has
  more than one responsibility - split it.

---

## JPA Conventions

### Field Access

- Annotate fields, not getters (`@Access(AccessType.FIELD)`)
- Hibernate hydrates via reflection - no setters required

### Constructors

- `protected` no-arg constructor for Hibernate only - document as such
- All real constructors enforce invariants and are the intended entry point

### Mutation Control

- No public setters - state changes only through intent-revealing domain methods
  (e.g. `order.cancel()`, `order.addLine(...)`)

### Collections

- Initialised at field declaration
- Never expose raw collection - return unmodifiable view
- Domain methods do surgical `add`/`remove` - never replace the collection reference
- Use `orphanRemoval = true` for children with no meaning outside the parent

### Fetch Strategy

- `FetchType.LAZY` as default on all associations - no accidental over-fetching
- Fetch strategy is explicit per use case at the repository level (`JOIN FETCH` / `@EntityGraph`)
- No reliance on lazy loading as a safety net - fetch decisions are deliberate and inspectable

### Dirty Checking

- Keep entities managed within the transaction - Hibernate detects mutations automatically
- If re-attachment is needed, reload from repository before applying changes

---

## Flyway - Database Migration Strategy

### Configuration

- Configure one Flyway instance per datasource using Quarkus named datasource syntax.
- Name datasources meaningfully - for example `primary`, `secondary` - in `application.properties`.

```properties
quarkus.datasource.primary.db-kind=postgresql
quarkus.flyway.primary.locations=db/primary/migration
quarkus.flyway.primary.migrate-at-start=true
```

### Script Location & Naming

- Scripts live under `src/main/resources/db/<datasource>/migration/`.
- Script naming: `V<version>__<bounded_context>_<description>.sql`
- Version numbers are sequential integers per datasource; never reuse or skip.
- Descriptions are lowercase snake_case and describe the change, not the ticket.
- Repeatable migrations (views, functions) use `R__<description>.sql`.

### Rules

- Follow the expand-contract (parallel change) pattern: deploy schema changes first (expand),
  then the new application version, then clean up old artefacts in a follow-up migration (contract).
  New code must never depend on a schema version that has not yet been deployed.
- Column or table renames must be done in three steps: add new → migrate data → drop old;
  never in a single script.
- Keep a rollback plan for every migration; document it in a comment at the top of the script.
- Never modify an existing migration script; always add a new versioned one.
- Never share migration scripts across datasources; each datasource owns its schema independently.
- Never perform data migrations in the same script as schema migrations; separate them
  into distinct versioned scripts.

---

## Exception Handling Strategy

All exceptions are translated to HTTP or messaging responses at the adapter boundary.
No exception escapes its layer unmapped.

All exception mappers are `@ServerExceptionMapper` implementations in `adapter/rest`.
Responses use RFC 7807 Problem Details (`application/problem+json`).
Define one mapper per exception type - never a single catch-all mapper.

### Exception Hierarchy and Mapping

```
AppException                                    (abstract, unchecked; in `base-package/exception/`)
├── DomainException                             (abstract; in `domain/`)
│   ├── EntityNotFoundException                 → 404
│   ├── DuplicateEntityException                → 409
│   ├── InvalidStateTransitionException         → 422
│   └── BusinessRuleViolationException          → 422
└── ApplicationException                        (abstract; in `application/`)
    ├── OptimisticLockConflictException         → 409
    ├── ExternalServiceException                → 502
    └── ServiceUnavailableException             → 503
```

Framework-managed:
```
ConstraintViolationException                    → 400 (Bean Validation)
UnauthorizedException                           → 401 (quarkus-oidc)
ForbiddenException                              → 403 (quarkus-oidc)
All others                                      → 500
```

### Rules

- Never throw `AppException` directly - always throw a named subtype.
- Infrastructure exceptions (JDBC, network, serialisation) are caught in `infrastructure/`
  and rethrown as named `ApplicationException` subtypes.
- Never expose stack traces, internal class names, or SQL in any response body.
- Every `500` must be logged at `ERROR` with the OTel trace ID; suppress the trace ID from the response body.
- Domain and application layers must not import any Jakarta REST or HTTP types;
  exception translation is exclusively an adapter responsibility.
- Event consumers distinguish failure modes:
  - **Transient** (infrastructure unavailable, timeout) → `nack` to trigger Kafka retry.
  - **Permanent** (malformed payload, deserialisation failure, business rule violation)
    → log at `ERROR`, emit to dead-letter topic, `ack` to prevent infinite retry.

---

## Validation Strategy

- Validate structural correctness (presence, format, size) at the adapter
  boundary using Bean Validation;
  enforce business invariants programmatically inside domain constructors and methods - never conflate the two.
- Annotate `@Valid` on every JAX-RS resource method parameter accepting a request DTO;
  annotate `@Valid` on every `@ConfigMapping` injection point to fail fast at startup.
- Place Bean Validation annotations (`@NotNull`, `@NotBlank`, `@Size`, `@Pattern`, `@Min`, `@Max`)
  on request and event DTO fields only - never on domain model classes.
- Custom `ConstraintValidator` implementations belong in the adapter layer that owns the DTO.
- `application/` and `infrastructure/` layers perform no validation.
- A `ConstraintViolationException` must always be caught by an exception mapper and translated
  to a structured `400 Bad Request` - never let the default Quarkus response escape.

---

## Observability

Domain and application layers must not contain logging, metrics, or tracing code.

### Logging

- Use `io.quarkus.logging.Log` (static logger) in all application code; no field-injected logger instances.
- Log format: JSON in `staging` and `prod`; plain text in `dev` and `test`.
- Every log record in non-local environments must include the OTel trace ID and span ID via MDC -
  `quarkus-opentelemetry` injects these automatically; do not implement custom correlation.
- Log at `INFO` in `adapter/rest` (request method + path, no body, no PII) and `adapter/event`
  (topic, partition, offset); at `DEBUG` in `application/` (use case entry, command summary)
  and `infrastructure/` (repository calls; `WARN` on retry or fallback);
  at `ERROR` in exception mappers for `5xx`, `WARN` for `4xx`.
- Never log PII, credentials, tokens, or full request/response bodies.
- Never log inside domain classes.

### Metrics

Use `quarkus-micrometer` with the Prometheus registry. Metrics are defined in `infrastructure/`
or `adapter/` - never in domain or application layers.

- Expose a custom counter for each significant business event
  (`orders.placed`, `payments.failed`, `subscriptions.cancelled`); technical metrics alone
  are insufficient for production alerting.
- Tag metrics with `bounded_context` and `use_case` labels for dashboarding.
- Prefer injecting `MeterRegistry` directly and recording metrics programmatically in
  `infrastructure/` or `adapter/` classes; Micrometer's `@Timed` annotation requires
  a CDI interceptor binding and may not fire correctly on all proxy configurations -
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

## Configuration

All application configuration is managed through `@ConfigMapping` interfaces.
Raw `@ConfigProperty` field injection is not permitted.

### `@ConfigMapping` Interfaces

- Define one `@ConfigMapping` interface per configuration concern
  (e.g. `PaymentConfig`, `MessagingConfig`, `OidcClientConfig`).
- Place all `@ConfigMapping` interfaces in `infrastructure/config/`.
- The `prefix` attribute maps to the property namespace (e.g. `@ConfigMapping(prefix = "payment")`
  binds `payment.gateway-url`, `payment.timeout`, etc.).
- Use nested interfaces to model hierarchical property groups.
- Apply Bean Validation constraints on interface methods to enforce required values and ranges at startup.
- Annotate the **injection point** with `@Valid` (not the interface itself) to trigger validation at startup.
- Never inject a `@ConfigMapping` interface into `domain/` - configuration is an infrastructure concern.

### Property Files

- Use Quarkus profiles (`dev`, `test`, `staging`, `prod`) with dedicated
  `application-{profile}.properties` files; use `%dev.` / `%prod.` inline prefixes
  only for trivial dev-mode convenience settings.
- `application.properties` contains only non-sensitive, environment-independent defaults;
  it must be safely committable - if a property cannot be committed, it is misplaced.
- Never hardcode environment-specific values; express them as environment variable
  references (`${DB_URL}`) in profile files. The `${VAR:default}` syntax is permitted
  only for non-sensitive values with a sensible default.
- Environment variables take highest precedence; `.env` files are local-only and never committed.
- Never read `System.getenv()` or `System.getProperty()` directly - all access goes through
  `@ConfigMapping` interfaces.
- Fail fast: missing or invalid required configuration must prevent startup.
- Document every non-obvious configuration property with a comment in the properties file.

### Secrets

- Never store secrets (passwords, API keys, client secrets, private keys, tokens)
  in any properties file or in version control.
- Inject secrets exclusively via environment variables or a secrets manager
  (`quarkus-vault` for HashiCorp Vault, or the platform's native secret store).
- Reference secrets in properties files using environment variable expressions:
  `quarkus.oidc.credentials.secret=${OIDC_CLIENT_SECRET}`.
- `@ConfigMapping` methods representing secrets must be annotated with
  `@io.smallrye.config.Secret` to suppress their value from logs and config dumps.
- Never include secret values in health check responses, startup logs, or exception messages.

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
  identities without a running OIDC provider - do not mock `SecurityIdentity` with a mocking
  framework for HTTP-layer tests.
- In `application/` use case tests, inject a `SecurityIdentity` CDI test producer via
  `@Alternative` / `@Priority` - do not use a mocking framework stub.
- Use Quarkus OIDC Dev Services (Keycloak) for local development.

### Authorisation

- Apply coarse-grained authorisation with `@RolesAllowed` in `adapter/rest`
  to restrict endpoint access by role.
- Apply fine-grained authorisation with `@PermissionsAllowed` or programmatic
  `SecurityIdentity` checks in `application/usecase` to enforce ownership, tenancy,
  or resource-level rules.
- Every JAX-RS resource method must carry an explicit authorisation annotation
  - `@RolesAllowed`, `@Authenticated`, or `@PermitAll`. An unannotated method is a defect.
- `@PermitAll` requires a comment explaining why the endpoint is public.
- Fine-grained checks that require domain context belong in the use case,
  resolved against the domain object after it is loaded - never pre-checked solely from token claims.
- Inject `SecurityIdentity` into use cases via CDI when programmatic checks are
  needed; never pass raw tokens or claims as method arguments across layer boundaries.
- Domain classes must never reference `SecurityIdentity` or any security type.

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

- Deny by default: enable `quarkus.security.jaxrs.deny-unannotated-endpoints=true` at startup.
- Never trust claims from the request body or query string to establish identity;
  identity is derived exclusively from the validated bearer token.
- Validate that the token `aud` (audience) claim matches the service's expected identifier;
  configure `quarkus.oidc.token.audience` explicitly.
- Strip sensitive response headers (`Server`, `X-Powered-By`) via a server filter in `adapter/rest`.

### Security Testing

- Every protected endpoint must have a test asserting `401` when called without a token
  and `403` when called with a token that lacks the required role.
- Use `@TestSecurity` with named roles in `adapter/rest` tests.
- Fine-grained use case authorisation tests supply a controlled `SecurityIdentity` via a
  CDI `@Alternative` producer - they do not go through the HTTP layer.
- Never use `@PermitAll` on infrastructure endpoints (`/q/health`, `/q/metrics`) in production
  configuration; scope them to internal network access at the infrastructure level.

---

## Testing Strategy

Tests must be written alongside implementation, never deferred.

### Test Location and Responsibilities

- `domain/` - pure unit tests; domain classes testable with plain `new`, no framework context, no mocks.
- `application/` - use case tests; mock only outbound ports (`OrderRepository`, `PaymentGateway`);
  never mock domain objects.
- `infrastructure/persistence/` - integration tests with Testcontainers; no mocks.
- `infrastructure/messaging/` - Kafka integration tests with Testcontainers.
- `infrastructure/client/` - contract tests with WireMock; assert the domain port contract is honoured.
- `adapter/rest/` - `@QuarkusTest` + REST-assured; assert HTTP contract (status, headers, body shape);
  mock the use case only.
- `adapter/event/` - assert correct command reaches the use case and malformed payloads are handled
  gracefully; mock the use case only.

### Rules

- Do not test mappers in isolation unless they contain conditional logic; cover them
  implicitly through adapter or use case tests.
- Use `@QuarkusTest` only in `adapter/rest` tests; do not use it for domain or use case tests.
- One test class per production class; name it `<ProductionClass>Test`.
- Integration tests that require a running Quarkus instance are suffixed `IT` -
  `PlaceOrderIT` - and run in a separate Maven phase.

### Coverage Expectations

| Layer                          | Must cover                                                  | Target   |
|--------------------------------|-------------------------------------------------------------|----------|
| `domain/`                      | Every rule, invariant, state transition                     | 90–100%  |
| `application/`                 | Every use case path: success, not-found, domain exception   | 80–90%   |
| `infrastructure/persistence/`  | Happy path, optimistic lock failure, constraint violation   | 60–70%   |
| `infrastructure/messaging/`    | Successful publish, serialisation failure                   | 60–70%   |
| `infrastructure/client/`       | Success, timeout, error response mapping                    | 60–70%   |
| `adapter/rest/`                | Success, validation failure, not-found, unauthorised        | 70–80%   |
| `adapter/event/`               | Successful mapping, malformed payload                       | 70–80%   |

Overall target is 80%. Untested domain logic with high adapter coverage is worse than lower
overall coverage with complete domain coverage - adapters test wiring, not correctness.
