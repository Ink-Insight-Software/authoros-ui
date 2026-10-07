# Changelog

## 0.2.0

- **`FieldWithTruth`, moved in from AOS-Write's bible pages** (October 7,
  2026): one field and, where the author wants one, the hidden truth beside
  it (`HiddenTruths`, `_truth.values` in the core). AOS Worldsmith edits a
  civilisation's public identity and hidden reality with it.
- Who may add a truth is the caller's: `truthsOpen` and `onLocked`. AOS-Write
  and Worldsmith both sell hidden truths with Codex Bibles; this package
  knows no product. A truth already written is always shown and editable.
- Additive: `RecordFieldInputs` and `OptionLabel` are unchanged.

## 0.1.1

- Pins `authoros_core` at 0.12.0 (`6945873`, the merge of
  authoros-core#12), in step with `authoros_persistence` 0.2.4, since pub
  takes one ref per package. No code changed.

## 0.1.0

- **`RecordFieldInputs` and `OptionLabel`, moved in from AOS-Write's
  `lib/ui/`** (October 5, 2026), so AOS Worldsmith draws record fields with
  the renderer AuthorOS Write uses rather than a fourth copy of it.
- Two changes on the way, both additive:
  - **`offer`** replaces `ownedProductIds`. Field ownership is AOS-Write's
    (its `field_ownership.dart` reads its own capabilities), so the widget
    takes a function that narrows the configured fields given the stored
    values, and AOS-Write's wrapper applies ownership through it. Null offers
    every configured field, which is what a null `ownedProductIds` did.
  - **`definition`**: given the record's type, a choice field's options and
    their explanations resolve through the type's option sets. Before, only
    inline options were offered, so a set-backed choice reported as
    unsupported.
