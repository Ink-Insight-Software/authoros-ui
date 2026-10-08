/// The scene-break markers an author types.
///
/// A paragraph that is nothing but `***`, `---` or `<break>` is a break rather
/// than a line of prose, wherever it is read. Book Studio needs to know so it
/// does not set one as body text; the proof engine needs to know so it can
/// report a manuscript using three different markers for the same thing.
///
/// It sits beside `book/` rather than in it because it is a fact about **what
/// the author typed**, not about a book. In AOS-Write it lived in `lib/core/`
/// for that reason (ADR-0009: before it, it was a static on
/// `BookDocumentBuilder`, and the proof engine reached across into `lib/book/`
/// to ask it), and that path still re-exports it from here since it moved,
/// with the book exporters, on October 8, 2026. `BookDocumentBuilder` still exposes it
/// under its old name, delegating here, so nothing that already asks has to
/// change.
library;

/// Markers an author may already have typed into their prose.
///
/// Three or more of `* # ~ - – —` on a line of their own, or an explicit
/// `<break>` / `<scene>` tag.
final RegExp _sceneBreakMarker =
    RegExp(r'^\s*(?:[*#~\-–—]\s*){3,}$|^\s*<\s*(?:break|scene)\s*>\s*$');

/// Whether [paragraph] is a typed scene break rather than prose.
bool isSceneBreakMarker(String paragraph) =>
    _sceneBreakMarker.hasMatch(paragraph);
