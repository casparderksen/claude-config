# Rules: Design System

This file defines the visual foundation of the application. It is the single source of truth
for theming, tokens, typography, colour, spacing, and iconography. All styling decisions in
component stylesheets must be consistent with what is defined here.

Applications use **Angular Material v20+ with the Material 3 (M3) theming system**.

---

## Theme Definition

Define the application theme once in `src/styles/theme.scss` and import it into the global
`styles.scss`. Do not define or re-apply themes anywhere else.

```scss
// src/styles/theme.scss
@use '@angular/material' as mat;

$app-theme: mat.define-theme((
  color: (
    theme-type: light,            // or dark — see Section 2
    primary: mat.$violet-palette, // replace with brand palette
    tertiary: mat.$rose-palette,
  ),
  typography: (
    brand-family: 'Inter, sans-serif',
    plain-family: 'Inter, sans-serif',
  ),
  density: (
    scale: 0,                     // 0 = default; negative values increase density
  ),
));

:root {
  @include mat.all-component-themes($app-theme);
}
```

### Rules

- The theme object (`$app-theme`) must be defined in exactly one place.
- Apply the theme to `:root` so CSS custom properties (tokens) are globally available.
- Never call `mat.all-component-themes()` inside a component stylesheet — it bloats output.
- Use `mat.component-theme()` mixins only when overriding a specific component's tokens
  within a scoped context (e.g. a dark sidebar).

---

## Colour

### Palettes

Angular Material M3 generates a full tonal palette from a seed colour. Do not hand-pick
individual shades — let the M3 system derive them.

| Role          | Token                     | Usage                                 |
|---------------|---------------------------|---------------------------------------|
| Primary       | `--mat-sys-primary`       | Main actions, key UI elements         |
| On Primary    | `--mat-sys-on-primary`    | Text/icons on primary surfaces        |
| Secondary     | `--mat-sys-secondary`     | Supporting UI elements                |
| Tertiary      | `--mat-sys-tertiary`      | Accent, highlights                    |
| Error         | `--mat-sys-error`         | Validation errors, destructive states |
| Surface       | `--mat-sys-surface`       | Card and sheet backgrounds            |
| Background    | `--mat-sys-background`    | Page background                       |
| Outline       | `--mat-sys-outline`       | Borders and dividers                  |

### Rules

- Always reference colours via `--mat-sys-*` CSS custom properties or M3 Sass tokens —
  never hardcode hex/rgb values in component stylesheets.
- Do not introduce custom colour variables that duplicate or shadow M3 system tokens.
- Application-specific semantic colours (e.g. status indicators) must be defined as
  additional CSS custom properties in `:root` within `theme.scss`, not scattered across
  component stylesheets.

### Dark Mode

- Dark mode is implemented by applying a second theme to a `.dark-theme` class on `<html>`
  or `<body>`, not via `@media (prefers-color-scheme: dark)` alone, so users can toggle it.
- Always test both light and dark themes when building new components.

---

## Typography

Typography is configured through the Material theme. Do not override Material typography
by targeting CSS classes directly.

### Type Scale (M3)

| Role              | Token                         | Typical use           |
|-------------------|-------------------------------|-----------------------|
| Display Large     | `--mat-sys-display-large`     | Hero headings         |
| Headline Large    | `--mat-sys-headline-large`    | Page titles           |
| Headline Medium   | `--mat-sys-headline-medium`   | Section headings      |
| Title Large       | `--mat-sys-title-large`       | Card headings         |
| Title Medium      | `--mat-sys-title-medium`      | Sub-section labels    |
| Body Large        | `--mat-sys-body-large`        | Primary body text     |
| Body Medium       | `--mat-sys-body-medium`       | Secondary body text   |
| Label Large       | `--mat-sys-label-large`       | Buttons, tabs         |
| Label Medium      | `--mat-sys-label-medium`      | Chips, badges         |
| Label Small       | `--mat-sys-label-small`       | Captions, overlines   |

### Rules

- Apply type roles semantically — use `Headline` for structural headings, not for visual
  weight alone.
- Use Angular Material's typography directives (`matTypography`, or the role attribute on
  Material components) where available rather than applying `font-*` properties manually.
- Line length for body text must not exceed 75 characters (approximately 680px at 16px base).
- Do not mix font families within the same UI region; the theme defines one brand family
  and one plain family — stick to them.

---

## Spacing & Layout

### Spacing Scale

Use a base-8 spacing scale. All spacing values must be multiples of 4px, with the preferred
unit being 8px increments.

| Token         | Value | Use                                           |
|---------------|-------|-----------------------------------------------|
| `--space-1`   | 4px   | Tight internal padding (e.g. chip padding)    |
| `--space-2`   | 8px   | Default inner component padding               |
| `--space-3`   | 12px  | Form field internal spacing                   |
| `--space-4`   | 16px  | Component gap, card padding                   |
| `--space-6`   | 24px  | Section padding                               |
| `--space-8`   | 32px  | Page section separation                       |
| `--space-12`  | 48px  | Large layout gaps                             |
| `--space-16`  | 64px  | Page-level vertical rhythm                    |

Define these tokens in `:root` within `theme.scss`. Do not use arbitrary pixel values in
component stylesheets.

### Layout Grid

- Use a 12-column grid for page layouts.
- Standard content max-width: `1280px`, centred.
- Page-level horizontal padding: `--space-6` (24px) on desktop, `--space-4` (16px) on mobile.
- Use CSS Grid for two-dimensional layouts; Flexbox for one-dimensional alignment.

### Breakpoints

| Name  | Min-width | Targets                           |
|-------|-----------|-----------------------------------|
| `xs`  | 0px       | Mobile portrait                   |
| `sm`  | 600px     | Mobile landscape, small tablet    |
| `md`  | 960px     | Tablet, small desktop             |
| `lg`  | 1280px    | Desktop                           |
| `xl`  | 1920px    | Large desktop                     |

Define breakpoints as SCSS variables in a shared `_breakpoints.scss` partial. Do not
hardcode pixel values in media queries within component stylesheets.

---

## Elevation & Shape

### Elevation

Material M3 uses tonal elevation (colour overlay) rather than shadows alone.

- Use `--mat-sys-level0` through `--mat-sys-level5` tokens for surface elevation.
- Do not add custom `box-shadow` values to Material surfaces; use the tonal elevation system.
- Reserve `level4` and `level5` for modal overlays and dialogs only.

### Shape

M3 defines shape using corner radius roles:

| Role          | Token                             | Typical use                   |
|---------------|-----------------------------------|-------------------------------|
| Extra Small   | `--mat-sys-corner-extra-small`    | Chips, tooltips               |
| Small         | `--mat-sys-corner-small`          | Buttons                       |
| Medium        | `--mat-sys-corner-medium`         | Cards, menus                  |
| Large         | `--mat-sys-corner-large`          | Navigation drawers            |
| Extra Large   | `--mat-sys-corner-extra-large`    | Bottom sheets, large cards    |
| Full          | `--mat-sys-corner-full`           | FABs, badges                  |

- Do not introduce custom `border-radius` values; use the M3 shape tokens.
- If a custom component must deviate from the default shape, override the token locally
  within the component stylesheet.

---

## Iconography

- Use **Material Symbols** (the variable icon font), not the legacy Material Icons font.
- Configure the icon font with the correct `font-variation-settings` for weight, fill, and
  optical size consistent with the M3 theme.
- All icon usage must go through `<mat-icon>` — do not embed raw SVGs inline unless the
  icon is not available in Material Symbols and a custom icon is registered via `MatIconRegistry`.
- Register custom SVG icons in a dedicated `IconRegistryService` in `core/`; never call
  `MatIconRegistry.addSvgIcon()` from a component.
- Icon size must be contextually appropriate: 18px for inline/label use, 24px for standard
  UI, 36–48px for feature illustrations.

---

## Motion & Animation

Follow the M3 motion system: use easing curves and durations from the Material spec rather
than arbitrary values.

| Category                          | Easing                        | Duration  |
|-----------------------------------|-------------------------------|-----------|
| Standard (most transitions)       | `cubic-bezier(0.2, 0, 0, 1)`  | 300ms     |
| Decelerate (enter screen)         | `cubic-bezier(0, 0, 0, 1)`    | 300ms     |
| Accelerate (exit screen)          | `cubic-bezier(0.3, 0, 1, 1)`  | 200ms     |
| Emphasised (large transitions)    | `cubic-bezier(0.2, 0, 0, 1)`  | 500ms     |

### Rules

- Define easing values as CSS custom properties in `:root` within `theme.scss`.
- Respect `prefers-reduced-motion`; wrap non-essential animations:
  ```scss
  @media (prefers-reduced-motion: reduce) {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
  ```
- Do not animate properties that trigger layout (e.g. `width`, `height`, `margin`);
  prefer `transform` and `opacity`.

---

## Design Token Governance

- All design decisions (colour, spacing, shape, motion) must trace back to a token defined
  in `theme.scss` or a shared SCSS partial. Magic values in component stylesheets are a
  code smell and must be flagged in code review.
- When Angular Material does not provide a token for a needed value, define a new custom
  CSS property in `theme.scss` under a namespaced convention:
  `--app-[component]-[property]-[state]` (e.g. `--app-sidebar-width: 280px`).
- Review token usage as part of design reviews; stale or duplicated tokens must be removed.
