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
- **`FieldWithTruth`** (`field_with_truth.dart`): one field and the hidden
  truth beside it, when the author adds one (`HiddenTruths` in the core).
  Whether a new truth may be added is the caller's to say (`truthsOpen`,
  `onLocked`); a truth already written always shows.

None reads a database or an entitlement: definitions and values in, values
out.

### The book exporters (`book/`)

Moved in from AOS-Write's `lib/book/` on October 8, 2026, so AOS Worldsmith
exports a civilisation dossier through the same Markdown and PDF exporters a
manuscript goes through, not a second pair (the owner's choice). AOS-Write
keeps its old import paths as re-exports, so nothing there changed but where
the code lives.

- **`BookDocument`** (`book/book_document.dart`): a book in reading order:
  metadata, front matter, parts and chapters of paragraphs, back matter.
  `BookDocumentBuilder` builds one from a manuscript (`ManuscriptChapter`
  and friends in the core); an application with no manuscript builds one by
  hand.
- **`BookMarkdownExporter`** and **`BookTextExporter`**: a `BookDocument`
  to Markdown or plain text.
- **`BookLayoutEngine`** and **`BookPdfRenderer`**: a `BookDocument` laid out
  in a `BookFormat` (`BookFormatPresets`), then rendered to the same PDF
  bytes every time.
- What they need: `BookFormat`, `BookFontAssets` and its metrics,
  `inline_markup.dart`, `epub_settings.dart`, and the marketing kit and quote
  a `BookProject` carries. Plus `scene_break_markers.dart`, at the top level
  because it is a fact about what an author typed, not about a book.

**The fonts are the application's.** `BookFontAssets.load()` reads
`assets/fonts/Merriweather-*.ttf` and `assets/fonts/Inter-*.ttf` from the
application's own bundle (the paths are `BookFontAssets.assetPaths`), so an
application that lays books out ships those eight files and declares them as
assets. They are not package assets because AOS-Write already bundles them
for its interface, and a second copy would ship twice. `load()` expects all
eight and fails without them; a caller holding fewer builds `BookFontAssets`
from the bytes it has, and the layout substitutes the faces it lacks. The one
face under `test/fonts/` is a test fixture, used that way.

The EPUB and DOCX exporters, the preview, proofing and the marketing renderer
stay in AOS-Write: nothing outside it uses them yet.

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
