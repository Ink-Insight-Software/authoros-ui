# Changelog

## 0.7.1

- **Pins authoros-core 0.21.0** (October 21, 2026): the `claims`
  connection and a title's `heldThrough`, `heldSince`, `regent` and
  `regency`. Nothing here changes: the core's change is additive, and pub
  allows an application one core ref, so this package moves with it.

## 0.7.0

- **The Linguist's Study's panels** (October 16, 2026, for AOS Worldsmith's
  Linguist's Study). `lib/language_forge/`: `study_panels.dart`,
  `grammar_panel.dart`, `evolution_panels.dart` and
  `profile_and_naming_panels.dart`, moved from AOS-Write's
  `lib/expansions/language_forge/`, where each becomes a one-line export.
  They depended only on the core and Flutter. Changed on the way:
  - imports name the core's `language_forge/` files directly;
  - `StudyContext.recordHome`, *the Codex* by default, names where a host
    makes a record in the panels' notices, so Worldsmith's do not send an
    author to a Codex it does not have;
  - the Grammar panel's *Open in the Codex* reads *Open the record*, as the
    Profile's already did, its empty notice drops *under Culture*, and the
    Family panel's subtitle says *the records' links* for *the Codex's
    links*. Every other string, key and behaviour is as it was.
  `test/language_forge/study_panels_test.dart` mounts each panel on its own
  over an in-memory host (eight tests).

## 0.6.1

- **A large Word file is set about four times faster, with the same bytes**
  (October 16, 2026, for AOS Worldsmith's whole-world bible).
  `BookDocxExporter` now writes the document part straight to text instead
  of building it as an `XmlBuilder` tree and then serialising it; the other
  parts are small and still use `XmlBuilder`. The escaping is the `xml`
  package's own (`defaultEntityMapping`), with a check that skips it for
  text it would not change. `BookSceneContent.wordCount` counts with one
  pattern instead of making one, and a list of words, per paragraph. On
  AOS Worldsmith's large-world fixture (a 6 MB document part) the export
  went from about 0.95 s to about 0.25 s once warm (1.3 to 1.7 s to about
  0.4 s on a first run), in a debug test. The bytes are unchanged:
  `test/book_docx_identity_test.dart` holds four documents, both flavours,
  every kind of matter and every character the escaping treats specially,
  to 0.6.0's SHA-256, and Worldsmith holds its large world to 0.6.0's bytes.

## 0.6.0

- **A host chooses how a family is drawn** (October 12, 2026, for AOS
  Worldsmith's styled family trees). Three new `GraphCanvas` parameters,
  each read in the Family mode only, each defaulting to what was drawn
  before:
  - `familyNodeStyle`: `FamilyNodeStyle.portrait` draws a `FamilyNodeCard`
    per person, as before; `FamilyNodeStyle.compact` paints every person as
    a small ring and a name (`FamilyMarkPainter`), in a card's footprint so
    every line still meets it, with no widget per person. A tap, a double
    tap and a drag still work, found by `FamilyMarkPainter.personAt`, and
    each mark gives a screen reader the name and lifespan a card would. On
    AOS Worldsmith's large-world fixture the family tree, fitted to the
    screen, went from 26,000 elements to under 5,000.
  - `ringColours`: a colour for particular people, in place of their
    descent line's, on their ring and on the lines drawn from them
    (`FamilyEdgePainter.ringColours`). A host colours by House with it.
  - `captions`: the line under a person's name, in place of their lifespan,
    passed to `FamilyNodeCard.caption`, which the roster already used.

## 0.5.0

- **The Word exporter, moved in from AOS-Write's `lib/book/`** (October 11,
  2026): `BookDocxExporter` and `DocxFlavour` (`book/book_docx_exporter.dart`)
  set a `BookDocument` as a `.docx`, in either flavour, the same bytes for
  the same document and `modified` time. AOS Worldsmith offers a world bible
  and a civilisation dossier as Word files through it. The code is
  AOS-Write's, unchanged; AOS-Write's file becomes a re-export when it moves
  its pin, as the other exporters' did.
- Depends on `archive` (`^4.0.9`, the range `authoros_core` already uses).
- **`GraphCanvas` builds only the nodes on its canvas** once a graph has
  more than `GraphCanvas.cullAbove` (200) nodes. Off the canvas a node was
  clipped and never seen, but still built: on AOS Worldsmith's large-world
  fixture the systems view was 118,000 elements and the family tree 67,000
  (now 4,500 and 26,000). A graph of 200 or fewer builds every node, as
  before.

## 0.4.3

- Pins `authoros_core` at 0.17.0 (`65a0c48`, the merge of
  authoros-core#18), which moves `BranchService` into the core and adds
  nine consequence rules. No code changed.

## 0.4.2

- Pins `authoros_core` at 0.16.0 (`9372516`, the merge of
  authoros-core#17), which moves Language Forge's model into the core and
  carries extension documents in the archive. No code changed.

## 0.4.1

- Pins `authoros_core` at 0.15.0 (`782b4d9`, the merge of
  authoros-core#16), so hosts that need the Worldsmith Phase 6 to 10 types
  can resolve one core. No code changed.

## 0.4.0

- **The Loom, moved in from AOS-Write's `lib/knowledge_graph/`** (October 10,
  2026): `GraphCanvas`, `GraphPalette`, the graph layouts, the family tree
  and roster structures and their cards. AOS Worldsmith's Ancestry Room
  draws a family tree through them.
- Decoupled from the host on the way: `GraphPalette.of` (AOS-Write's Theme
  Engine) became `GraphPalette.fromTheme(ThemeData)`, and the stored
  `RecordAvatar` and local-path portraits became `portraits`, an
  `ImageProvider` per record id that the host resolves. Otherwise the code is
  AOS-Write's, unchanged but for its imports.
- Needs `authoros_core` 0.13.0, which carries `story_graph.dart`.

## 0.3.0

- **The book exporters, moved in from AOS-Write's `lib/book/`** (October 8,
  2026): `BookDocument` and `BookDocumentBuilder`, the Markdown and plain
  text exporters, the layout engine and the PDF renderer, and what they need
  (`BookFormat`, `BookFontAssets`, inline markup, EPUB settings, the
  marketing kit and quote a `BookProject` carries). `scene_break_markers.dart`
  comes too, at the top level. AOS Worldsmith exports a civilisation dossier
  through them. The code is AOS-Write's, unchanged but for its imports:
  manuscript types now come from `authoros_core/manuscript_model.dart`.
- Depends on `pdf`, `xml` and `crypto`, at the ranges AOS-Write already uses.
- The fonts stay the application's: `BookFontAssets.load()` reads
  `assets/fonts/` from its bundle.
- Additive: the widgets are unchanged.

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
