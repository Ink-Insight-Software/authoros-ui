# authoros_ui

**Flutter widgets AuthorOS Write and the standalone applications share.** It
sits over `authoros_core`, which holds the record model and is pure Dart, and
holds the drawing of that model where more than one application draws it, so
a field is drawn and edited the same way wherever a record is.

It began on October 5, 2026 with the record field editor. AOS-Write's
`lib/ui/record_field_inputs.dart` had recorded itself as the third copy of
field rendering in that application and asked whoever came to add a fourth to
extract instead. AOS Worldsmith's record pages were the fourth, and Worldsmith
cannot import AOS-Write's `lib/` (AOS-Write is private). The owner chose a
shared package over a fourth copy.

**A change to a shared widget is made here first.** It reaches an
application only when that application moves its pin, and that application's
suite runs against it before it ships.

## What is in it

- **`RecordFieldInputs`** (`record_field_inputs.dart`): inputs for a list of
  `RecordFieldDefinition`s, seeded from values, reporting every edit. Empty
  is absent, never stored as empty. Fields it cannot edit yet are named in
  the UI and their values kept. Given the record's `RecordTypeDefinition`,
  choice fields resolve their options through the type's option sets. A
  caller narrows what is offered through `offer`, which is shown the stored
  values: AOS-Write applies its field ownership there.
- **`OptionLabel`** (`option_label.dart`): an option, with what it means
  underneath when something describes it.

Neither reads a database or an entitlement: definitions and values in,
values out.

## Using it

Depend on a commit, never a branch, and pin `authoros_core` at the commit
this package's `pubspec.yaml` pins:

```yaml
dependencies:
  authoros_ui:
    git:
      url: https://github.com/Ink-Insight-Software/authoros-ui.git
      ref: <commit>
  authoros_core:
    git:
      url: https://github.com/Ink-Insight-Software/authoros-core.git
      ref: <the commit this package pins>
```

Two git refs for one package do not resolve, so pub reports a mismatch
rather than building two cores. Move the pins together.

## Checks

`flutter analyze` and `flutter test`, on Flutter 3.44.9, the SDK AOS-Write
and AuthorOS-Expansions pin. CI runs both on every pull request.
