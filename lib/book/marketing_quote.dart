/// A quote lifted from the manuscript, stored as a citation and not a copy.
///
/// The whole point of the marketing kit is that nothing on the card was
/// written for the author. The title is the book's title, the name is the
/// author's name — and the quote is the author's own sentence, lifted whole.
/// A copy taken the day the card was made stops being that the moment the
/// sentence is rewritten, and says nothing about it.
///
/// So the kit stores where the sentence is, not what it said: a scene, a span
/// inside that scene, and the words that were there when it was picked. On
/// every open the citation is resolved against the live manuscript, and the
/// answer is one of four standings — the sentence is still exactly there, it
/// has moved within its scene, it has been rewritten, or the scene is gone.
/// The card only claims to be canon in the first two cases, and says so
/// plainly in the other two rather than printing prose the book no longer
/// contains.
library;

import 'package:authoros_core/manuscript_model.dart';

/// Where a quote came from, and what it said when it was taken.
class QuoteCitation {
  const QuoteCitation({
    required this.chapterId,
    required this.sceneId,
    required this.start,
    required this.end,
    required this.verbatim,
    required this.capturedAt,
  });

  final String chapterId;
  final String sceneId;

  /// The span inside the scene's prose, as character offsets into
  /// [ManuscriptScene.content].
  final int start;
  final int end;

  /// The words that stood at [start]..[end] when the author picked them.
  ///
  /// Not a fallback for display — it is the evidence. Without it a citation
  /// cannot tell a sentence that moved from a sentence that was rewritten,
  /// because both leave different words at the same offsets.
  final String verbatim;

  final DateTime capturedAt;

  /// Whether this citation says anything at all.
  bool get isEmpty => sceneId.isEmpty || verbatim.trim().isEmpty;

  QuoteCitation reanchored(int start, int end) => QuoteCitation(
        chapterId: chapterId,
        sceneId: sceneId,
        start: start,
        end: end,
        verbatim: verbatim,
        capturedAt: capturedAt,
      );

  Map<String, Object?> toJson() => {
        'chapterId': chapterId,
        'sceneId': sceneId,
        'start': start,
        'end': end,
        'verbatim': verbatim,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory QuoteCitation.fromJson(Map<String, dynamic> json) => QuoteCitation(
        chapterId: (json['chapterId'] as String?) ?? '',
        sceneId: (json['sceneId'] as String?) ?? '',
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 0,
        verbatim: (json['verbatim'] as String?) ?? '',
        capturedAt:
            DateTime.tryParse((json['capturedAt'] as String?) ?? '')?.toUtc() ??
                DateTime.utc(2000),
      );

  @override
  bool operator ==(Object other) =>
      other is QuoteCitation &&
      other.chapterId == chapterId &&
      other.sceneId == sceneId &&
      other.start == start &&
      other.end == end &&
      other.verbatim == verbatim;

  @override
  int get hashCode => Object.hash(chapterId, sceneId, start, end, verbatim);
}

/// What the manuscript says about a citation today.
enum QuoteStanding {
  /// The words are still exactly where they were left.
  intact,

  /// The words are still in that scene, at a different offset. Editing above
  /// a quote moves it; that is not the quote changing.
  moved,

  /// The scene is still there and those words are not. The author rewrote the
  /// sentence after making the card.
  changed,

  /// The scene itself is gone from the manuscript.
  missing,
}

extension QuoteStandingX on QuoteStanding {
  /// Whether a card carrying this quote may still call it canon.
  bool get isLive =>
      this == QuoteStanding.intact || this == QuoteStanding.moved;
}

/// A citation resolved against the manuscript as it stands now.
class ResolvedQuote {
  const ResolvedQuote({
    required this.citation,
    required this.standing,
    required this.text,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.sceneTitle,
  });

  /// The citation, re-anchored when the words had moved.
  final QuoteCitation citation;

  final QuoteStanding standing;

  /// The words to set on the card.
  ///
  /// The live prose where the quote still stands, and the captured words
  /// otherwise — shown so the author can see what they are about to lose,
  /// never exported. [isLive] is what decides whether it may ship.
  final String text;

  final String chapterTitle;

  /// The chapter's position in the book, counting from one. Zero when the
  /// chapter is no longer in the manuscript.
  final int chapterNumber;

  final String sceneTitle;

  bool get isLive => standing.isLive;

  /// The credit line under the quote — "Chapter 17".
  ///
  /// The number and not the title, because a chapter title is optional and
  /// half of all books do not use them. Empty when the chapter is gone, which
  /// is the only case where there is no honest attribution to print.
  String get attribution => chapterNumber > 0 ? 'Chapter $chapterNumber' : '';

  /// What to tell the author, or empty when there is nothing to say.
  String get notice => switch (standing) {
        QuoteStanding.intact => '',
        QuoteStanding.moved =>
          'The quote moved as you wrote around it. It still says the same '
              'words, and the kit has followed it.',
        QuoteStanding.changed =>
          'This sentence has been rewritten since you chose it. The kit will '
              'not print words your book no longer contains — pick the quote '
              'again, or choose another.',
        QuoteStanding.missing =>
          'The scene this quote came from is no longer in the manuscript. '
              'Choose another quote.',
      };
}

/// Resolves a citation against the live manuscript.
///
/// Deterministic and AI-free: it looks for the exact words it was given, at
/// the offset it was given first and anywhere in the scene second. It never
/// guesses at a sentence that "looks like" the old one — a near match is a
/// rewrite, and the author is the one who decides what to do about it.
class QuoteResolver {
  const QuoteResolver();

  /// Null when there is no quote to resolve, which is not a problem: a kit
  /// without a quote is a kit the author has not finished.
  ResolvedQuote? resolve(
    QuoteCitation? citation,
    ManuscriptProjectSummary manuscript,
  ) {
    if (citation == null || citation.isEmpty) return null;

    final chapters = [...manuscript.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));

    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      for (final scene in chapter.scenes) {
        if (scene.id != citation.sceneId) continue;
        return _against(citation, scene, chapter.title, index + 1);
      }
    }

    return ResolvedQuote(
      citation: citation,
      standing: QuoteStanding.missing,
      text: citation.verbatim,
      chapterTitle: '',
      chapterNumber: 0,
      sceneTitle: '',
    );
  }

  ResolvedQuote _against(
    QuoteCitation citation,
    ManuscriptScene scene,
    String chapterTitle,
    int chapterNumber,
  ) {
    final prose = scene.content;
    final words = citation.verbatim;

    // Still exactly where it was left.
    if (citation.start >= 0 &&
        citation.end <= prose.length &&
        citation.start < citation.end &&
        prose.substring(citation.start, citation.end) == words) {
      return ResolvedQuote(
        citation: citation,
        standing: QuoteStanding.intact,
        text: words,
        chapterTitle: chapterTitle,
        chapterNumber: chapterNumber,
        sceneTitle: scene.title,
      );
    }

    // Somewhere else in the same scene. The nearest occurrence to where it
    // used to be, so a sentence the author repeats does not re-anchor to a
    // different one of its own copies.
    final found = _nearest(prose, words, citation.start);
    if (found >= 0) {
      return ResolvedQuote(
        citation: citation.reanchored(found, found + words.length),
        standing: QuoteStanding.moved,
        text: words,
        chapterTitle: chapterTitle,
        chapterNumber: chapterNumber,
        sceneTitle: scene.title,
      );
    }

    return ResolvedQuote(
      citation: citation,
      standing: QuoteStanding.changed,
      text: words,
      chapterTitle: chapterTitle,
      chapterNumber: chapterNumber,
      sceneTitle: scene.title,
    );
  }

  /// The occurrence of [words] in [prose] whose start is closest to [near],
  /// or -1 when there is none.
  static int _nearest(String prose, String words, int near) {
    if (words.isEmpty) return -1;
    var best = -1;
    var bestDistance = -1;
    var at = prose.indexOf(words);
    while (at >= 0) {
      final distance = (at - near).abs();
      if (best < 0 || distance < bestDistance) {
        best = at;
        bestDistance = distance;
      }
      at = prose.indexOf(words, at + 1);
    }
    return best;
  }
}

/// Trims a selection down to something worth putting on a card.
///
/// The author drags across prose; what they mean is the sentence, not the
/// half-space either side of it. Leading and trailing whitespace is dropped
/// and the offsets moved to match, so the stored span is exactly the words
/// that will be set.
QuoteCitation? citationFor({
  required String chapterId,
  required ManuscriptScene scene,
  required int start,
  required int end,
  required DateTime capturedAt,
}) {
  final prose = scene.content;
  var from = start.clamp(0, prose.length);
  var to = end.clamp(0, prose.length);
  if (from > to) {
    final swap = from;
    from = to;
    to = swap;
  }
  while (from < to && _isSpace(prose.codeUnitAt(from))) {
    from++;
  }
  while (to > from && _isSpace(prose.codeUnitAt(to - 1))) {
    to--;
  }
  if (from >= to) return null;

  return QuoteCitation(
    chapterId: chapterId,
    sceneId: scene.id,
    start: from,
    end: to,
    verbatim: prose.substring(from, to),
    capturedAt: capturedAt,
  );
}

/// A span of prose, by offset.
class ProseSpan {
  const ProseSpan(this.start, this.end);
  final int start;
  final int end;

  int get length => end - start;
}

/// The sentences in a scene, as spans into its own prose.
///
/// Deterministic and rule-based, per the AI-free policy: a sentence ends at a
/// full stop, a question mark, an exclamation mark or an ellipsis, together
/// with any closing quotation mark that follows it, and then whitespace. That
/// is wrong for "Dr." and right for almost everything else in a novel — and
/// being wrong here costs the author one extra tap, not a wrong quote, because
/// what is stored is the span they actually chose.
///
/// Spans are returned trimmed of surrounding whitespace, so a chosen sentence
/// is exactly the words that will be set.
List<ProseSpan> sentencesIn(String prose) {
  const enders = {0x2E, 0x21, 0x3F}; // . ! ?
  const closers = {0x22, 0x27, 0x201D, 0x2019, 0x29, 0x2026}; // " ' ” ’ ) …

  final spans = <ProseSpan>[];
  var start = 0;

  for (var i = 0; i < prose.length; i++) {
    final unit = prose.codeUnitAt(i);
    if (!enders.contains(unit) && unit != 0x2026) continue;

    // Run past the rest of the punctuation cluster — "!?" and a closing
    // quote both belong to the sentence they end.
    var end = i + 1;
    while (end < prose.length &&
        (enders.contains(prose.codeUnitAt(end)) ||
            closers.contains(prose.codeUnitAt(end)))) {
      end++;
    }

    // A sentence ends only where whitespace, or the prose itself, follows.
    if (end < prose.length && !_isSpace(prose.codeUnitAt(end))) continue;

    _addSpan(spans, prose, start, end);
    start = end;
    i = end - 1;
  }

  _addSpan(spans, prose, start, prose.length);
  return spans;
}

void _addSpan(List<ProseSpan> spans, String prose, int from, int to) {
  var start = from;
  var end = to;
  while (start < end && _isSpace(prose.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _isSpace(prose.codeUnitAt(end - 1))) {
    end--;
  }
  if (end > start) spans.add(ProseSpan(start, end));
}

bool _isSpace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0A ||
    codeUnit == 0x0D;
