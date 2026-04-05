# Rules: UX

This file defines interaction patterns, states, accessibility requirements, and responsive
behaviour. These rules apply to all components and features regardless of which Angular
Material component is used to implement them.

---

## Component States

Every interactive UI element must handle all applicable states. Incomplete state handling
is a bug, not a design omission.

### Loading States

- Show a loading indicator immediately when an async operation begins — do not wait for a
  timeout before showing feedback.
- Use `MatProgressBar` (indeterminate) at the top of a page or card for background loads
  that do not block interaction.
- Use `MatProgressSpinner` (indeterminate) for operations that block the user until complete
  (e.g. form submission, initial data fetch blocking the view).
- Disable interactive controls (buttons, form fields) during submission to prevent double
  submission. Re-enable them on success or failure.
- Skeleton screens are preferred over spinners for initial page/card loads where the layout
  is known in advance.

### Empty States

- Every list, table, or data view must have an explicit empty state — never render an empty
  container silently.
- Empty states must communicate: what is absent, why, and (where applicable) what the user
  can do about it (a call-to-action).
- Do not reuse loading states as empty states; they are distinct conditions.

### Error States

- Distinguish between recoverable and non-recoverable errors in the UI.
- Recoverable errors (e.g. failed data fetch): show inline error message with a retry
  action. Do not navigate the user away.
- Non-recoverable errors (e.g. permissions, not found): show a dedicated error page or
  full-panel message with a clear next step (go back, go home).
- Never expose raw error messages, stack traces, or API error codes to the user.
- Form validation errors: display inline beneath the relevant field via `MatError`;
  never use alert dialogs for field-level validation.
- Global operation errors (e.g. save failed): use `MatSnackBar` with an action
  (e.g. "Retry") — auto-dismiss after 8 seconds minimum so the user has time to read it.

### Success States

- Confirm successful operations explicitly; do not leave the user uncertain about whether
  their action took effect.
- Use `MatSnackBar` for non-destructive, reversible operations (e.g. "Item saved").
- Navigate or update the view directly for operations whose success is self-evident from
  the resulting state change (e.g. item appears in list after creation).
- Do not show success dialogs for routine operations; reserve dialogs for significant
  completions (e.g. onboarding completion, order placed).

---

## Forms & Validation

- Validate on blur for individual fields, not on every keystroke. Exception: real-time
  validation is appropriate for fields with strict format requirements (e.g. password
  strength).
- Validate the entire form on submission attempt; mark all invalid fields simultaneously
  so the user can see all errors at once.
- Do not disable the submit button to indicate invalid state — this prevents users from
  discovering what is wrong. Show errors on submit attempt instead.
- Required fields must be marked visually with a clear convention (asterisk + legend, or
  alternatively marking optional fields).
- Preserve user input on error; never clear a form after a failed submission.
- Multi-step forms must show progress and allow backward navigation without data loss.
- Date inputs must use `MatDatepicker`; provide both keyboard input and calendar picker
  — do not force one modality.

---

## Destructive & Irreversible Actions

- Always require explicit confirmation before a destructive action (delete, cancel, revoke).
- Use `MatDialog` for confirmation — a single-line `MatSnackBar` is insufficient for
  destructive actions.
- Confirmation dialogs must:
  - Clearly state what will be deleted/lost.
  - Use a red/error-coloured confirm button (`color="warn"`).
  - Have a clearly labelled cancel option as the default focused element.
- Where possible, prefer soft-delete with undo over hard-delete with confirmation.
- Never place destructive actions adjacent to primary actions without visual separation.

---

## Navigation & Wayfinding

- The user must always be able to determine where they are in the application. Use
  breadcrumbs for hierarchical structures deeper than two levels.
- Active navigation items must have a clear visual indicator beyond colour alone (weight,
  background, indicator bar) to meet WCAG contrast requirements.
- Navigating to a new route must scroll the page to the top; do not preserve scroll
  position across route changes unless it is a deliberate UX pattern (e.g. back navigation).
- Browser back/forward navigation must work correctly; do not intercept or disable it.
- Deep links must be supported for all views; the application must be fully initialised from
  any URL, not just from the root.

---

## Feedback & Notifications

| Feedback type             | Component                             | Dismissal                 |
|---------------------------|---------------------------------------|---------------------------|
| Transient success/info    | `MatSnackBar`                         | Auto (4–8s)               |
| Transient error           | `MatSnackBar` with action             | Manual or long auto (8s+) |
| Persistent inline status  | `MatChip`, status badge               | Tied to data state        |
| Blocking confirmation     | `MatDialog`                           | Manual only               |
| Contextual field error    | `MatError` inside `MatFormField`      | Cleared on valid input    |
| Page-level warning/info   | `MatBanner` or inline alert component | Manual or contextual      |

### Rules

- Do not stack multiple `MatSnackBar` instances; queue them or consolidate into one message.
- Do not use `alert()`, `confirm()`, or `prompt()` — ever.
- Do not use `MatDialog` for non-blocking notifications; it demands user attention
  inappropriately.

---

## Accessibility (WCAG 2.1 AA)

The application must meet **WCAG 2.1 Level AA** as a minimum.

### Perceivable

- All non-decorative images must have descriptive `alt` text.
- Decorative images must have `alt=""` and `aria-hidden="true"`.
- Do not convey information through colour alone; pair colour with text, icon, or pattern.
- Minimum contrast ratio: **4.5:1** for normal text, **3:1** for large text and UI components.

### Operable

- All functionality must be reachable and operable via keyboard alone.
- Focus order must follow a logical reading order in the DOM — do not rely on CSS to reorder
  visually while leaving the DOM order illogical.
- Visible focus indicator must be present at all times; never `outline: none` without an
  alternative focus style.
- Interactive targets must be at least **44×44px** in touch area.
- Provide skip navigation links on every page for keyboard and screen reader users.
- No content must flash more than 3 times per second (seizure prevention).

### Understandable

- Form labels must be persistent and visible — do not use placeholder text as the only label.
- Error messages must identify the field and describe how to fix the error, not just that
  an error occurred.
- Language must be set on the `<html>` element: `lang="en"` (or the appropriate locale).

### Robust

- Use semantic HTML elements (`<main>`, `<nav>`, `<header>`, `<section>`, `<button>`)
  before reaching for `<div>` with ARIA roles.
- Do not add ARIA roles that duplicate native HTML semantics (e.g. `<button role="button">`).
- Interactive components that are not native HTML controls must implement the appropriate
  ARIA pattern from the WAI-ARIA Authoring Practices Guide (APG).
- Test with at least one screen reader (NVDA + Firefox on Windows, VoiceOver + Safari on
  macOS) as part of feature acceptance.

### Angular Material Specifics

- All `MatFormField` instances must have a `<mat-label>` or `aria-label`.
- All icon-only buttons (`mat-icon-button`) must have an `aria-label`.
- `MatDialog` must trap focus inside the dialog and restore focus to the triggering element
  on close — this is automatic if using `MatDialog` correctly; do not override it.
- Use `LiveAnnouncer` from `@angular/cdk/a11y` to announce dynamic content changes
  (e.g. filter results count) to screen readers.

---

## Responsive Behaviour

- Design mobile-first; expand layout at breakpoints rather than collapsing desktop layouts.
- Breakpoints are defined in `design-system.md`. Use them exclusively; do not add one-off
  `@media` queries with arbitrary values.
- Navigation: use `MatSidenav` in `mode="over"` on mobile (`xs`/`sm`), `mode="side"` on
  desktop (`lg`+).
- Tables: on mobile, prefer a list/card layout over a horizontally scrolling table.
  Use `MatTable` with responsive column hiding, or a dedicated mobile-friendly layout,
  not `overflow-x: auto` as a default fallback.
- Touch targets: all interactive elements must meet the 44×44px minimum on touch devices.
- Font sizes must not be set in `px` on body text; use `rem` so users can scale via browser
  settings.
- Do not disable user zoom (`<meta name="viewport" content="user-scalable=no">`) — ever.

---

## Performance & Perceived Performance

- Route transitions must be fast enough that no loading indicator is needed for
  pre-fetched or cached routes.
- Use route-level code splitting (lazy loading) for all features — never load the entire
  application upfront.
- Images must be appropriately sized and served in modern formats (WebP, AVIF); use
  `loading="lazy"` for below-the-fold images.
- Long lists (>50 items) must use `@angular/cdk/virtual-scroll` to avoid DOM bloat.
- Perceived performance is as important as actual performance: provide immediate visual
  feedback (button press state, skeleton screen) even when the operation takes time.
- Core Web Vitals targets:
  - LCP (Largest Contentful Paint): < 2.5s
  - CLS (Cumulative Layout Shift): < 0.1
  - INP (Interaction to Next Paint): < 200ms

---

## Internationalisation (i18n)

- All user-visible strings must be marked for translation using Angular's `i18n` attribute
  or `$localize` — no hardcoded English strings in templates or components.
- Do not construct sentences by concatenating translated fragments; word order differs
  across languages. Use ICU message format for pluralisation and gender.
- Dates, times, numbers, and currencies must be formatted using Angular's built-in pipes
  (`DatePipe`, `CurrencyPipe`, `DecimalPipe`) with the active locale, not manually formatted.
- Layout must not break when text expands by 30–40% (typical for Germanic or Slavic
  languages relative to English); test with pseudo-localisation.
- RTL support: use logical CSS properties (`margin-inline-start` rather than `margin-left`)
  to prepare for RTL layout without a full redesign.
