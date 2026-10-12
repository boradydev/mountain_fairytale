# Flutter project instructions

## Project structure

- Keep feature folders as flat siblings under `lib/features/`. Do not nest one
  feature inside another unless the user asks for it.
- Put feature-specific screens, widgets, and state providers in that feature's
  `ui/` folder. Put its models, repositories, and data sources in `data/`.
- Put feature-specific services beside their feature. For example, route-sheet
  PDF generation and Windows printing belong to `features/delivery_route/`.
- Use `lib/core/` for technical foundations shared across the app, such as the
  HTTP client, network errors, theme definitions, and generic state helpers.
- Use `lib/shared/widgets/` for reusable UI components and
  `lib/shared/providers/` for shared app-wide providers such as locale and
  theme. Keep feature-specific providers inside their feature.
- Keep app startup, dependency composition, and routing in `lib/app/` when
  those files are moved or added; do not perform broad moves as part of an
  unrelated feature task.

## Reuse UI components

- Before adding a button, dropdown, dialog, form field, or other common UI
  element, search `lib/shared/widgets/` and the relevant feature's `ui/` folder
  for an existing component with the same purpose.
- Reuse an existing component when it fits. If it needs a small variation,
  extend it with parameters instead of copying its implementation or styling.
- Add a new shared widget only when no existing component can reasonably serve
  the use case. Keep widgets used by one feature inside that feature.
- Prefer existing project widgets over raw Material controls when an equivalent
  project widget exists (for example, use `AppDropdown` for project dropdowns).
- In the final response, name the reused widgets. If a new reusable widget was
  necessary, briefly explain why.

## Text field style

- Use one consistent Material text-field style throughout the app for new
  features and when refactoring existing fields. Keep the normal field
  appearance consistent with the project's outlined fields, including its
  label, hint, spacing, and any prefix icon.
- Show field-specific validation errors inside the field using Flutter's
  `TextFormField` / `InputDecoration` error state. Use `validator` for local
  validation and `forceErrorText` (or the matching `FormField` error API) for
  server validation such as a duplicate name. Let Material render the error
  text and red error border together.
- Do not put a field-specific validation message in a separate red `Text`,
  `SnackBar`, or dialog-level error below the form. Reserve separate messages
  for request or form errors that are not tied to one field.
- Clear a server-side field error as soon as the user changes that field's
  value. The field must return to the same normal style used by fields without
  an error.

## State and data flow

- Preserve the project's understandable flow:
  `UI/provider -> repository -> data source or API`.
- Keep the repository layer when it separates UI state from data access,
  converts models, or allows demo and API sources to be substituted.
- Do not add use-case classes or mirror the backend's full architecture without
  a concrete need.
- Keep feature state in that feature's provider. Shared provider base classes
  and generic state utilities belong in `core/state/`.
- Avoid broad refactors and unrelated file moves. Follow the existing feature
  structure and naming in the files being changed.

## Backend integration

- Treat the FastAPI backend and its `docs/contracts/` documents as authoritative
  for API behavior. Read the relevant contract before implementing or changing
  an API data source; do not infer API behavior from demo JSON or old Flutter
  models.
- Match backend identifiers and JSON contracts, including UUID string IDs,
  camelCase fields, response envelopes, status codes, and soft-deactivation
  behavior where specified.
- Keep API-specific data sources inside their feature's `data/`; use the shared
  HTTP client from `core/network/`.

### Confirmed driver behavior

- Driver duplicate search includes active and deactivated records. A match is a
  warning only; it must not prevent creating another driver.
- Show the matched driver's active/deactivated status. For a deactivated match,
  offer activation.
- The route driver's dropdown has a persistent “show deactivated drivers”
  setting, saved across app launches and off by default. Use the backend's
  `include_deactivated` query parameter to load the matching list.
- Clearly mark deactivated drivers in the dropdown. They cannot be assigned to
  a route while inactive. Choosing one offers “Activate and select”; after
  successful activation, refresh the active driver list and select that driver
  in the route dropdown.
- Driver deactivation is a soft state change via `PATCH isActive: false`, not a
  physical `DELETE`. Reactivation uses `PATCH isActive: true`.
