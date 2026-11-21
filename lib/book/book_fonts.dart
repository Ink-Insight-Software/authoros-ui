/// Book Studio Phase 1 — font loading and text measurement.
///
/// Everything that decides how wide a string is lives behind
/// [BookFontMetrics]. The layout engine measures through this interface, and so
/// does the preview: the on-screen surface must not measure with Flutter's own
/// text shaper, because then the preview and the exported PDF would break lines
/// in different places and the page counts would disagree.
///
/// The authoritative measurer is therefore the one the exporter actually uses —
/// the PDF font. `package:pdf` parses TrueType in pure Dart with no platform
/// channel, so the same code runs on web, on device, and under `flutter_test`.
///
/// Metrics are returned in **em units**. A glyph advance scales linearly with
/// point size, so a string is measured once and reused at any size.
library;

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';

import 'book_format.dart';

/// Measures text for the layout engine.
abstract class BookFontMetrics {
  /// The advance width of [text] in [face], in em units.
  double advanceEm(String text, BookFontFace face);

  /// Distance from the baseline to the top of the face, in em units.
  double ascentEm(BookFontFace face);

  /// Distance from the baseline to the bottom of the face, in em units.
  /// Positive, unlike the PDF convention.
  double descentEm(BookFontFace face);

  /// The face actually available for [requested].
  ///
  /// A format may name a face this build does not ship. Rather than fail, the
  /// nearest available face is substituted and [substitutions] records it.
  BookFontFace resolve(BookFontFace requested);

  /// Faces that were requested but substituted, as `requested -> used`.
  Map<BookFontFace, BookFontFace> get substitutions;

  /// The advance width of [text] in points.
  double advancePt(String text, BookFontFace face, double sizePt) =>
      advanceEm(text, face) * sizePt;

  double ascentPt(BookFontFace face, double sizePt) =>
      ascentEm(face) * sizePt;

  double descentPt(BookFontFace face, double sizePt) =>
      descentEm(face) * sizePt;

  /// The advance of a single space, in points. Justification needs this to know
  /// how much slack it is redistributing.
  double spacePt(BookFontFace face, double sizePt) =>
      advancePt(' ', face, sizePt);
}

/// The TrueType bytes for every face this build ships.
///
/// Held as bytes rather than parsed fonts because a `PdfFont` belongs to the
/// document it was built against: the measurement pass and the render pass each
/// build their own from these same bytes, which is why their metrics agree.
class BookFontAssets {
  const BookFontAssets(this._data);

  final Map<BookFontFace, ByteData> _data;

  /// The asset path for each face, or null when this build does not ship it.
  /// The face used when a requested one is not shipped at all.
  ///
  /// This lives with the assets rather than with the metrics because it is a
  /// question of what the build contains, not of how text is measured.
  static const fallbackFace = BookFontFace.merriweatherRegular;

  static final Map<BookFontFace, String> assetPaths = {
    BookFontFace.merriweatherRegular: 'assets/fonts/Merriweather-400.ttf',
    BookFontFace.merriweatherBold: 'assets/fonts/Merriweather-700.ttf',
    BookFontFace.merriweatherItalic:
        'assets/fonts/Merriweather-400-Italic.ttf',
    const BookFontFace(
            BookFontFamilyId.merriweather, BookFontStyleId.boldItalic):
        'assets/fonts/Merriweather-700-Italic.ttf',
    BookFontFace.interRegular: 'assets/fonts/Inter-400.ttf',
    BookFontFace.interBold: 'assets/fonts/Inter-700.ttf',
    BookFontFace.interItalic: 'assets/fonts/Inter-400-Italic.ttf',
    const BookFontFace(BookFontFamilyId.inter, BookFontStyleId.boldItalic):
        'assets/fonts/Inter-700-Italic.ttf',
    // The owner's choices, November 21, 2026. A family ships the styles its
    // designer drew; a style it lacks degrades through [resolve] to the
    // family's own regular, never to another family.
    const BookFontFace(BookFontFamilyId.radley, BookFontStyleId.regular):
        'assets/fonts/Radley-400.ttf',
    const BookFontFace(BookFontFamilyId.radley, BookFontStyleId.italic):
        'assets/fonts/Radley-400-Italic.ttf',
    const BookFontFace(BookFontFamilyId.gentiumPlus, BookFontStyleId.regular):
        'assets/fonts/GentiumPlus-400.ttf',
    const BookFontFace(BookFontFamilyId.gentiumPlus, BookFontStyleId.bold):
        'assets/fonts/GentiumPlus-700.ttf',
    const BookFontFace(BookFontFamilyId.gentiumPlus, BookFontStyleId.italic):
        'assets/fonts/GentiumPlus-400-Italic.ttf',
    const BookFontFace(
            BookFontFamilyId.gentiumPlus, BookFontStyleId.boldItalic):
        'assets/fonts/GentiumPlus-700-Italic.ttf',
    const BookFontFace(BookFontFamilyId.solway, BookFontStyleId.regular):
        'assets/fonts/Solway-400.ttf',
    const BookFontFace(BookFontFamilyId.solway, BookFontStyleId.bold):
        'assets/fonts/Solway-700.ttf',
    // Solway Light: the Light weight as the text, Medium as its bold.
    const BookFontFace(BookFontFamilyId.solwayLight, BookFontStyleId.regular):
        'assets/fonts/Solway-300.ttf',
    const BookFontFace(BookFontFamilyId.solwayLight, BookFontStyleId.bold):
        'assets/fonts/Solway-500.ttf',
    const BookFontFace(BookFontFamilyId.antic, BookFontStyleId.regular):
        'assets/fonts/Antic-400.ttf',
    const BookFontFace(BookFontFamilyId.anticDidone, BookFontStyleId.regular):
        'assets/fonts/AnticDidone-400.ttf',
    const BookFontFace(BookFontFamilyId.lancelot, BookFontStyleId.regular):
        'assets/fonts/Lancelot-400.ttf',
  };

  /// The families [load] reads when it is not told which: the two the engine
  /// began with. A caller that sets a book in another passes it, so nobody
  /// pays for a face no page uses.
  static const defaultFamilies = {
    BookFontFamilyId.merriweather,
    BookFontFamilyId.inter,
  };

  /// The families a format's pages are set in.
  static Set<BookFontFamilyId> familiesFor(BookFormat format) => {
        format.typography.bodyFamily,
        format.typography.displayFamily,
      };

  ByteData? bytesFor(BookFontFace face) => _data[face];

  /// The face in hand that stands in for [requested], or null when not even
  /// the fallback is.
  ///
  /// Degrades along the axis that costs the least: the slope first, then the
  /// weight, then the family. One rule, used by the measurer and by every
  /// renderer, so a title measured in a family's regular is drawn in it. A
  /// renderer with a rule of its own drew a bold-less family's headings in
  /// the fallback family while the layout had measured them in its own.
  BookFontFace? nearest(BookFontFace requested) {
    for (final candidate in [
      requested,
      if (requested.style == BookFontStyleId.boldItalic)
        requested.withStyle(BookFontStyleId.bold),
      requested.withStyle(BookFontStyleId.regular),
      fallbackFace,
    ]) {
      if (_data.containsKey(candidate)) return candidate;
    }
    return null;
  }

  Iterable<BookFontFace> get availableFaces => _data.keys;

  bool has(BookFontFace face) => _data.containsKey(face);

  /// Loads every shipped face from the asset bundle.
  ///
  /// The result is cached for the session: parsing is not free and the studio
  /// repaginates on every format tweak.
  ///
  /// [families] are the ones wanted beyond [defaultFamilies], which are
  /// always read: the fallback face is among them, and every caller that
  /// predates the choice of a family expects both. Each face is read once
  /// however often it is asked for.
  static Future<BookFontAssets> load({
    Iterable<BookFontFamilyId> families = const [],
  }) async {
    final wanted = {...defaultFamilies, ...families};
    final data = <BookFontFace, ByteData>{};
    for (final entry in assetPaths.entries) {
      if (!wanted.contains(entry.key.family)) continue;
      data[entry.key] =
          _faces[entry.key] ??= await rootBundle.load(entry.value);
    }
    return BookFontAssets(data);
  }

  /// Whether every family in [families] is already in hand.
  bool covers(Iterable<BookFontFamilyId> families) => families.every(
        (family) => _data.keys.any((face) => face.family == family),
      );

  static final Map<BookFontFace, ByteData> _faces = {};

  /// Drops the cache. For tests.
  static void resetCache() => _faces.clear();
}

/// Measures with the same font objects the PDF exporter will use.
class PdfBookFontMetrics implements BookFontMetrics {
  PdfBookFontMetrics._(this._fonts, this._substitutions);

  final Map<BookFontFace, PdfFont> _fonts;
  final Map<BookFontFace, BookFontFace> _substitutions;

  /// Builds metrics from [assets].
  ///
  /// The fonts are built against a throwaway document. That document is never
  /// written; it exists only because `PdfFont` requires one. Metrics come from
  /// the TrueType tables, so a font built here measures identically to the one
  /// the renderer builds against its own document.
  factory PdfBookFontMetrics(BookFontAssets assets) {
    final scratch = PdfDocument();
    final fonts = <BookFontFace, PdfFont>{};
    for (final face in assets.availableFaces) {
      final bytes = assets.bytesFor(face);
      if (bytes == null) continue;
      fonts[face] = PdfTtfFont(scratch, bytes);
    }
    return PdfBookFontMetrics._(fonts, <BookFontFace, BookFontFace>{});
  }

  @override
  Map<BookFontFace, BookFontFace> get substitutions =>
      Map.unmodifiable(_substitutions);

  @override
  BookFontFace resolve(BookFontFace requested) {
    if (_fonts.containsKey(requested)) return requested;

    // Degrade along the axis that costs the least: drop the slope first, then
    // the weight, then the family.
    final candidates = <BookFontFace>[
      if (requested.style == BookFontStyleId.boldItalic)
        requested.withStyle(BookFontStyleId.bold),
      if (requested.style == BookFontStyleId.boldItalic ||
          requested.style == BookFontStyleId.italic)
        requested.withStyle(BookFontStyleId.regular),
      requested.withStyle(BookFontStyleId.regular),
      BookFontAssets.fallbackFace,
    ];
    for (final candidate in candidates) {
      if (_fonts.containsKey(candidate)) {
        _substitutions[requested] = candidate;
        return candidate;
      }
    }

    // Nothing in the degradation chain is bundled — not even the fallback.
    // This was recording nothing, so the substitution was invisible and the
    // book exported in the wrong face with no report anywhere.
    _substitutions[requested] = BookFontAssets.fallbackFace;
    return BookFontAssets.fallbackFace;
  }

  PdfFont _font(BookFontFace face) =>
      _fonts[resolve(face)] ?? _fonts.values.first;

  @override
  double advanceEm(String text, BookFontFace face) {
    if (text.isEmpty) return 0;
    return _font(face).stringMetrics(text).advanceWidth;
  }

  @override
  double ascentEm(BookFontFace face) => _font(face).ascent;

  @override
  double descentEm(BookFontFace face) => -_font(face).descent;

  @override
  double advancePt(String text, BookFontFace face, double sizePt) =>
      advanceEm(text, face) * sizePt;

  @override
  double ascentPt(BookFontFace face, double sizePt) =>
      ascentEm(face) * sizePt;

  @override
  double descentPt(BookFontFace face, double sizePt) =>
      descentEm(face) * sizePt;

  @override
  double spacePt(BookFontFace face, double sizePt) =>
      advancePt(' ', face, sizePt);
}

/// Deterministic metrics for tests.
///
/// Every glyph has the same advance, so expected line breaks can be computed by
/// hand and the layout rules can be asserted without loading a font.
class FakeBookFontMetrics implements BookFontMetrics {
  FakeBookFontMetrics({
    this.perCharacterEm = 0.5,
    this.ascent = 0.8,
    this.descent = 0.2,
    this.italicFactor = 1.0,
  });

  final double perCharacterEm;
  final double ascent;
  final double descent;

  /// How much wider a slanted face is than its upright.
  ///
  /// One by default, so every existing arithmetic layout test is unaffected by
  /// emphasis existing. A test that sets it to something else can prove the
  /// line breaker is really measuring each segment in its own face rather than
  /// getting the right answer because every face happened to be identical.
  final double italicFactor;

  double _factor(BookFontFace face) =>
      face.style == BookFontStyleId.italic ||
              face.style == BookFontStyleId.boldItalic
          ? italicFactor
          : 1.0;

  @override
  Map<BookFontFace, BookFontFace> get substitutions => const {};

  @override
  BookFontFace resolve(BookFontFace requested) => requested;

  @override
  double advanceEm(String text, BookFontFace face) =>
      text.length * perCharacterEm * _factor(face);

  @override
  double ascentEm(BookFontFace face) => ascent;

  @override
  double descentEm(BookFontFace face) => descent;

  @override
  double advancePt(String text, BookFontFace face, double sizePt) =>
      advanceEm(text, face) * sizePt;

  @override
  double ascentPt(BookFontFace face, double sizePt) => ascent * sizePt;

  @override
  double descentPt(BookFontFace face, double sizePt) => descent * sizePt;

  @override
  double spacePt(BookFontFace face, double sizePt) =>
      perCharacterEm * sizePt;
}
