/// Book Studio Phase 1 — the book model and its derived reading order.
///
/// This library is plain Dart apart from its manuscript import. It must not
/// import Flutter and it must not import `package:pdf`.
///
/// Two shapes live here and the difference between them matters:
///
///  * [BookProject] is what the author owns and what is persisted. It holds
///    metadata, the front and back matter they chose, their parts, and their
///    format.
///  * [BookDocument] is derived, read-only, and never persisted. It is the
///    manuscript and the [BookProject] flattened into one reading order.
///
/// Keeping the derived shape separate from the paginated one is what later lets
/// EPUB and DOCX consume the book's structure without inheriting a print
/// layout's fixed pagination.
///
/// Moved here from AOS-Write's `lib/book/` on October 8, 2026, with the
/// exporters that read it, so AOS Worldsmith exports through them rather than
/// a second pair. An application without a manuscript builds a
/// [BookDocument] by hand.
library;

import 'package:authoros_core/manuscript_model.dart';
import 'package:authoros_core/prose_document.dart';

import '../scene_break_markers.dart' as markers;
import 'book_format.dart';
import 'epub_settings.dart';
import 'inline_markup.dart';
import 'marketing_kit.dart';

/// A front- or back-matter section.
///
/// These are presentation, not story: a copyright page has no characters and no
/// connections, so none of this belongs in the record graph.
enum BookSectionKind {
  // Front matter, in conventional order.
  halfTitle,
  titlePage,
  copyright,
  dedication,
  epigraph,
  contents,
  /// A full-page image, in the reading order.
  ///
  /// The one section kind whose content is not text. As a frontispiece it
  /// falls opposite the title page; at the back it is where a map or a family
  /// tree goes. The artwork lives in `bookAssetRows` under this section's own
  /// role, so a book may carry several and each keeps its own picture.
  plate,
  // Back matter.
  acknowledgements,
  aboutAuthor,
  otherBooks,
  newsletter,
  custom,
}

extension BookSectionKindX on BookSectionKind {
  String get label => switch (this) {
        BookSectionKind.halfTitle => 'Half Title',
        BookSectionKind.titlePage => 'Title Page',
        BookSectionKind.copyright => 'Copyright',
        BookSectionKind.dedication => 'Dedication',
        BookSectionKind.epigraph => 'Epigraph',
        BookSectionKind.contents => 'Contents',
        // Named for what an author sees rather than what a printer calls it.
        BookSectionKind.plate => 'Full-page image',
        BookSectionKind.acknowledgements => 'Acknowledgements',
        BookSectionKind.aboutAuthor => 'About the Author',
        BookSectionKind.otherBooks => 'Also by the Author',
        BookSectionKind.newsletter => 'Newsletter',
        BookSectionKind.custom => 'Custom Section',
      };

  /// True when the body text is computed rather than authored.
  ///
  /// Generated sections are never editable, which is how the contents page
  /// stays correct instead of going stale.
  bool get isGenerated => switch (this) {
        BookSectionKind.halfTitle => true,
        BookSectionKind.titlePage => true,
        BookSectionKind.copyright => true,
        BookSectionKind.contents => true,
        _ => false,
      };

  /// True when the section is made of words at all.
  ///
  /// Distinct from [isGenerated], which asks *who wrote them*. A plate has no
  /// body to generate and none to author, so every rule that treats missing
  /// text as a fault — the empty-section issue, the proof warning, the Write
  /// button — has to ask this rather than assume prose.
  bool get hasBody => this != BookSectionKind.plate;

  bool get isFrontMatter => switch (this) {
        BookSectionKind.halfTitle ||
        BookSectionKind.titlePage ||
        BookSectionKind.copyright ||
        BookSectionKind.dedication ||
        BookSectionKind.epigraph ||
        BookSectionKind.contents =>
          true,
        _ => false,
      };

  /// How this section is set on the page.
  BookMatterLayout get layout => switch (this) {
        BookSectionKind.halfTitle => BookMatterLayout.centredBlock,
        BookSectionKind.titlePage => BookMatterLayout.titlePage,
        BookSectionKind.copyright => BookMatterLayout.copyrightBlock,
        BookSectionKind.dedication => BookMatterLayout.centredBlock,
        BookSectionKind.epigraph => BookMatterLayout.centredBlock,
        BookSectionKind.contents => BookMatterLayout.contents,
        BookSectionKind.plate => BookMatterLayout.plate,
        _ => BookMatterLayout.flowingText,
      };
}

/// How a matter page is composed.
enum BookMatterLayout {
  /// Large centred title, subtitle, author, publisher.
  titlePage,

  /// A short centred block, vertically offset from the top.
  centredBlock,

  /// Small type set flush left, the way a copyright page is set.
  copyrightBlock,

  /// A heading followed by ordinary paragraphs.
  flowingText,

  /// Generated after the body is paginated, because it needs page numbers.
  contents,

  /// One image, fitted to the text block, on a page of its own.
  plate,
}

/// One front- or back-matter section as the author configured it.
class BookSection {
  const BookSection({
    required this.id,
    required this.kind,
    this.title = '',
    this.body = '',
    this.order = 0,
    this.included = true,
  });

  final String id;
  final BookSectionKind kind;

  /// The displayed heading. Empty suppresses it.
  final String title;

  /// Author-written text. Ignored when [BookSectionKindX.isGenerated].
  final String body;

  final int order;

  /// Toggled off without losing the text.
  final bool included;

  bool get isGenerated => kind.isGenerated;

  BookSection copyWith({
    String? title,
    String? body,
    int? order,
    bool? included,
  }) =>
      BookSection(
        id: id,
        kind: kind,
        title: title ?? this.title,
        body: body ?? this.body,
        order: order ?? this.order,
        included: included ?? this.included,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'body': body,
        'order': order,
        'included': included,
      };

  factory BookSection.fromJson(Map<String, dynamic> json) => BookSection(
        id: (json['id'] as String?) ?? 'section',
        kind: _enumByName(
            BookSectionKind.values, json['kind'], BookSectionKind.custom),
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        included: (json['included'] as bool?) ?? true,
      );
}

/// A part division over the existing chapters.
///
/// A part is ordering metadata, not a node: [startsAtChapterId] names an
/// existing [ManuscriptChapter], so chapters are never re-parented and every
/// manuscript operation keeps working untouched. When the story graph later
/// gains containment edges, this id becomes an edge with no change here.
class BookPart {
  const BookPart({
    required this.id,
    required this.startsAtChapterId,
    this.title = '',
    this.subtitle = '',
    this.order = 0,
  });

  final String id;
  final String startsAtChapterId;
  final String title;
  final String subtitle;
  final int order;

  BookPart copyWith({
    String? startsAtChapterId,
    String? title,
    String? subtitle,
    int? order,
  }) =>
      BookPart(
        id: id,
        startsAtChapterId: startsAtChapterId ?? this.startsAtChapterId,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        order: order ?? this.order,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'startsAtChapterId': startsAtChapterId,
        'title': title,
        'subtitle': subtitle,
        'order': order,
      };

  factory BookPart.fromJson(Map<String, dynamic> json) => BookPart(
        id: (json['id'] as String?) ?? 'part',
        startsAtChapterId: (json['startsAtChapterId'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        subtitle: (json['subtitle'] as String?) ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

/// Everything Book Studio persists for one project.
///
/// Title and author are stored as *overrides*, never as copies. If they were
/// copied, renaming the project would silently keep printing the old title on
/// the title page and in every running head, and the author would not find out
/// until a proof copy arrived.
class BookProject {
  const BookProject({
    required this.projectId,
    this.titleOverride = '',
    this.authorOverride = '',
    this.subtitle = '',
    this.seriesName = '',
    this.seriesNumber = '',
    this.isbn = '',
    this.publisher = '',
    this.copyrightYear = '',
    this.copyrightHolder = '',
    this.edition = '',
    this.rightsStatement = '',
    this.publicationDate = '',
    this.frontMatter = const [],
    this.backMatter = const [],
    this.parts = const [],
    this.format = BookFormatPresets.paperback,
    this.epub = EpubSettings.defaults,
    this.marketingKit = const MarketingKit(),
    this.exportHistory = const [],
    this.version = 1,
    this.migration = const {},
  });

  final String projectId;
  final String titleOverride;
  final String authorOverride;
  final String subtitle;
  final String seriesName;
  final String seriesNumber;
  final String isbn;
  final String publisher;
  final String copyrightYear;
  final String copyrightHolder;
  final String edition;
  final String rightsStatement;

  /// The day the book is published, as ISO `yyyy-MM-dd`. Empty until the
  /// author sets one.
  ///
  /// A string beside every other identity field rather than a `DateTime`,
  /// which keeps `copyWith` uniform — clearing it is setting it to empty —
  /// and makes an older stored book decodable without a migration. Read it
  /// through [publicationDay], which refuses anything that is not a date
  /// rather than carrying a malformed value onto a cover.
  final String publicationDate;

  final List<BookSection> frontMatter;
  final List<BookSection> backMatter;
  final List<BookPart> parts;
  final BookFormat format;

  /// How the book is set as a reflowable ebook.
  ///
  /// Separate from [format] rather than derived from it: half of a print
  /// format — trim, margins, binding allowance, running heads, folios — has no
  /// meaning once a reader reflows the text.
  final EpubSettings epub;

  /// The release-day marketing kit.
  ///
  /// Here rather than in its own store for the reason at the top of
  /// `book_store.dart`: it is presentation and not story, and it is a handful
  /// of ids and a citation — not the cards themselves, which are resolved from
  /// the book every time they are drawn.
  final MarketingKit marketingKit;

  /// What has been exported from this book, newest first.
  ///
  /// Small enough to sit in the settings blob with everything else — the
  /// snapshot *bytes* live in the database, and this only names them. Capped
  /// when written, so a book exported every day for a year does not grow an
  /// unbounded list inside a `localStorage` value.
  final List<ExportRecord> exportHistory;

  /// How many exports are remembered.
  ///
  /// More than the store keeps snapshots for, on purpose: an author is helped by
  /// seeing that they exported an EPUB last Tuesday even once the manuscript
  /// behind it has been evicted, and a row whose snapshot is gone still says
  /// something true.
  static const historyLimit = 25;

  /// The publication date as a date, or null when unset or unreadable.
  ///
  /// Date only: a release day has no time of day, and a cover that printed
  /// one would be saying something the author never entered.
  DateTime? get publicationDay {
    final trimmed = publicationDate.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  final int version;
  final Map<String, String> migration;

  static const currentVersion = 1;

  /// The sections a new book starts with.
  static List<BookSection> defaultFrontMatter() => const [
        // Ordered before the title page on purpose: a frontispiece is the
        // picture a reader meets opposite it.
        BookSection(
          id: 'front-frontispiece',
          kind: BookSectionKind.plate,
          order: -1,
          included: false,
        ),
        BookSection(
            id: 'front-title', kind: BookSectionKind.titlePage, order: 0),
        BookSection(
            id: 'front-copyright', kind: BookSectionKind.copyright, order: 1),
        BookSection(
          id: 'front-dedication',
          kind: BookSectionKind.dedication,
          order: 2,
          included: false,
        ),
        BookSection(
          id: 'front-contents',
          kind: BookSectionKind.contents,
          title: 'Contents',
          order: 3,
        ),
      ];

  static List<BookSection> defaultBackMatter() => const [
        BookSection(
          id: 'back-acknowledgements',
          kind: BookSectionKind.acknowledgements,
          title: 'Acknowledgements',
          order: 0,
          included: false,
        ),
        BookSection(
          id: 'back-about-author',
          kind: BookSectionKind.aboutAuthor,
          title: 'About the Author',
          order: 1,
          included: false,
        ),
        // Where a map or a family tree goes.
        BookSection(
          id: 'back-plate',
          kind: BookSectionKind.plate,
          order: 2,
          included: false,
        ),
      ];

  /// This book with any default section it predates added, switched off.
  ///
  /// A stored book carries exactly the sections it was saved with, so a slot
  /// introduced later — the plate is the first — would never appear for a book
  /// written before it. Adding it here rather than in `fromJson` keeps parsing
  /// a pure read of what was stored.
  ///
  /// Strictly additive, and Lock 6's shape: nothing stored is removed,
  /// reordered or switched on. A section the author already has is left
  /// exactly as they left it, including one they deliberately turned off.
  BookProject withDefaultSections() {
    List<BookSection> merged(
      List<BookSection> stored,
      List<BookSection> defaults,
    ) {
      final have = stored.map((section) => section.id).toSet();
      final missing = defaults.where((section) => !have.contains(section.id));
      if (missing.isEmpty) return stored;
      return [
        ...stored,
        for (final section in missing) section.copyWith(included: false),
      ]..sort((a, b) => a.order.compareTo(b.order));
    }

    return copyWith(
      frontMatter: merged(frontMatter, defaultFrontMatter()),
      backMatter: merged(backMatter, defaultBackMatter()),
    );
  }

  factory BookProject.initial(String projectId) => BookProject(
        projectId: projectId,
        frontMatter: defaultFrontMatter(),
        backMatter: defaultBackMatter(),
      );

  BookProject copyWith({
    String? titleOverride,
    String? authorOverride,
    String? subtitle,
    String? seriesName,
    String? seriesNumber,
    String? isbn,
    String? publisher,
    String? copyrightYear,
    String? copyrightHolder,
    String? edition,
    String? rightsStatement,
    String? publicationDate,
    List<BookSection>? frontMatter,
    List<BookSection>? backMatter,
    List<BookPart>? parts,
    BookFormat? format,
    EpubSettings? epub,
    MarketingKit? marketingKit,
    int? version,
    List<ExportRecord>? exportHistory,
    Map<String, String>? migration,
  }) =>
      BookProject(
        projectId: projectId,
        titleOverride: titleOverride ?? this.titleOverride,
        authorOverride: authorOverride ?? this.authorOverride,
        subtitle: subtitle ?? this.subtitle,
        seriesName: seriesName ?? this.seriesName,
        seriesNumber: seriesNumber ?? this.seriesNumber,
        isbn: isbn ?? this.isbn,
        publisher: publisher ?? this.publisher,
        copyrightYear: copyrightYear ?? this.copyrightYear,
        copyrightHolder: copyrightHolder ?? this.copyrightHolder,
        edition: edition ?? this.edition,
        rightsStatement: rightsStatement ?? this.rightsStatement,
        publicationDate: publicationDate ?? this.publicationDate,
        frontMatter: frontMatter ?? this.frontMatter,
        backMatter: backMatter ?? this.backMatter,
        parts: parts ?? this.parts,
        format: format ?? this.format,
        epub: epub ?? this.epub,
        marketingKit: marketingKit ?? this.marketingKit,
        version: version ?? this.version,
        exportHistory: exportHistory ?? this.exportHistory,
        migration: migration ?? this.migration,
      );

  /// Re-homes these settings onto a different project, keeping everything else.
  BookProject withProjectId(String id) => BookProject(
        projectId: id,
        titleOverride: titleOverride,
        authorOverride: authorOverride,
        subtitle: subtitle,
        seriesName: seriesName,
        seriesNumber: seriesNumber,
        isbn: isbn,
        publisher: publisher,
        copyrightYear: copyrightYear,
        copyrightHolder: copyrightHolder,
        edition: edition,
        rightsStatement: rightsStatement,
        publicationDate: publicationDate,
        frontMatter: frontMatter,
        backMatter: backMatter,
        parts: parts,
        format: format,
        epub: epub,
        marketingKit: marketingKit,
        version: version,
        migration: migration,
      );

  Map<String, Object?> toJson() => {
        'projectId': projectId,
        'titleOverride': titleOverride,
        'authorOverride': authorOverride,
        'subtitle': subtitle,
        'seriesName': seriesName,
        'seriesNumber': seriesNumber,
        'isbn': isbn,
        'publisher': publisher,
        'copyrightYear': copyrightYear,
        'copyrightHolder': copyrightHolder,
        'edition': edition,
        'rightsStatement': rightsStatement,
        'publicationDate': publicationDate,
        'frontMatter': frontMatter.map((s) => s.toJson()).toList(),
        'backMatter': backMatter.map((s) => s.toJson()).toList(),
        'parts': parts.map((p) => p.toJson()).toList(),
        'format': format.toJson(),
        'epub': epub.toJson(),
        'marketingKit': marketingKit.toJson(),
        'version': version,
        'exportHistory': [
          for (final record in exportHistory) record.toJson(),
        ],
        'migration': migration,
      };

  factory BookProject.fromJson(Map<String, dynamic> json) => BookProject(
        projectId: (json['projectId'] as String?) ?? '',
        titleOverride: (json['titleOverride'] as String?) ?? '',
        authorOverride: (json['authorOverride'] as String?) ?? '',
        subtitle: (json['subtitle'] as String?) ?? '',
        seriesName: (json['seriesName'] as String?) ?? '',
        seriesNumber: (json['seriesNumber'] as String?) ?? '',
        isbn: (json['isbn'] as String?) ?? '',
        publisher: (json['publisher'] as String?) ?? '',
        copyrightYear: (json['copyrightYear'] as String?) ?? '',
        copyrightHolder: (json['copyrightHolder'] as String?) ?? '',
        edition: (json['edition'] as String?) ?? '',
        rightsStatement: (json['rightsStatement'] as String?) ?? '',
        publicationDate: (json['publicationDate'] as String?) ?? '',
        frontMatter: _sections(json['frontMatter']),
        backMatter: _sections(json['backMatter']),
        parts: ((json['parts'] as List?) ?? const [])
            .whereType<Map>()
            .map((raw) => BookPart.fromJson(raw.cast<String, dynamic>()))
            .toList(growable: false),
        format: BookFormat.fromJson(
            (json['format'] as Map?)?.cast<String, dynamic>() ?? const {}),
        epub: EpubSettings.fromJson(
            (json['epub'] as Map?)?.cast<String, dynamic>() ?? const {}),
        marketingKit: MarketingKit.fromJson(
            (json['marketingKit'] as Map?)?.cast<String, dynamic>() ??
                const {}),
        exportHistory: [
          for (final item in (json['exportHistory'] as List? ?? const []))
            ExportRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        version: (json['version'] as num?)?.toInt() ?? currentVersion,
        migration: ((json['migration'] as Map?) ?? const {})
            .map((key, value) => MapEntry('$key', '$value')),
      );

  static List<BookSection> _sections(Object? raw) =>
      ((raw as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => BookSection.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false);
}

/// A date an author reads, not a timestamp — "14 October 2026".
///
/// Lives here because the publication date is a book field: the Structure
/// stage, the copyright page and the marketing kit all print the same day the
/// same way, and a date that reads differently in two places reads as two
/// dates.
String formatBookDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// The ISO `yyyy-MM-dd` form [BookProject.publicationDate] is stored in.
String isoBookDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// The series a book belongs to, as the project roster knows it.
///
/// The roster owns series identity — that is Q-S1, settled in
/// `docs/series-identity-delta.md` — so this is a reading of canon and never a
/// second place a series can be named. Null where the book stands alone, which
/// is most books and not a gap.
class SeriesStanding {
  const SeriesStanding({required this.name, this.position});

  final String name;

  /// The book's place in the series, zero-based as the roster stores it: book
  /// one is position 0.
  final int? position;

  /// The number a cover prints — "One", "Two".
  ///
  /// In words, because that is what the chapter openers already use and a
  /// series line reading "Book 2" beside "Chapter Two" is two conventions in
  /// one book.
  String get bookNumberWord =>
      position == null ? '' : numberWord(position! + 1);
}

/// Book identity, already resolved against the manuscript and author profile.
class BookMetadata {
  const BookMetadata({
    required this.title,
    required this.authorName,
    this.subtitle = '',
    this.seriesName = '',
    this.seriesNumber = '',
    this.isbn = '',
    this.publisher = '',
    this.copyrightYear = '',
    this.copyrightHolder = '',
    this.edition = '',
    this.rightsStatement = '',
  });

  final String title;
  final String authorName;
  final String subtitle;
  final String seriesName;
  final String seriesNumber;
  final String isbn;
  final String publisher;
  final String copyrightYear;
  final String copyrightHolder;
  final String edition;
  final String rightsStatement;
}

/// One export that happened.
///
/// Small enough to live in the book's own settings blob beside everything else,
/// which is the point: this is the list the studio shows, and it should load
/// with the rest of the book rather than needing a database round trip.
class ExportRecord {
  const ExportRecord({
    required this.exportedAt,
    required this.format,
    required this.snapshotHash,
    this.variant = '',
    this.manuscriptVersion = 0,
    this.pageCount = 0,
    this.wordCount = 0,
    this.coverHash = '',
  });

  final DateTime exportedAt;

  /// `BookExportFormat.name`, stored as a string so an added format cannot make
  /// an old history entry undecodable.
  final String format;

  /// The DOCX flavour or text style, where the format has one.
  final String variant;

  final String snapshotHash;
  final int manuscriptVersion;

  /// Zero for a reflowable format, which has no pages.
  final int pageCount;
  final int wordCount;

  /// The cover in use at the time, by content.
  ///
  /// The cover is the one thing an export depends on that the snapshot does
  /// not hold: it is hundreds of kilobytes of binary, and freezing a copy into
  /// every snapshot would cost more than it is worth. Its hash is sixteen
  /// characters, and it is enough to notice that the cover has changed and say
  /// so, rather than quietly producing a different file than the one this row
  /// claims to reproduce.
  ///
  /// Empty means there was no cover.
  final String coverHash;

  Map<String, Object?> toJson() => {
        'exportedAt': exportedAt.toIso8601String(),
        'format': format,
        'variant': variant,
        'snapshotHash': snapshotHash,
        'manuscriptVersion': manuscriptVersion,
        'pageCount': pageCount,
        'wordCount': wordCount,
        'coverHash': coverHash,
      };

  factory ExportRecord.fromJson(Map<String, dynamic> json) => ExportRecord(
        exportedAt:
            DateTime.tryParse((json['exportedAt'] as String?) ?? '')?.toUtc() ??
                DateTime.utc(2000),
        format: (json['format'] as String?) ?? '',
        variant: (json['variant'] as String?) ?? '',
        snapshotHash: (json['snapshotHash'] as String?) ?? '',
        manuscriptVersion: (json['manuscriptVersion'] as num?)?.toInt() ?? 0,
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
        coverHash: (json['coverHash'] as String?) ?? '',
      );
}

/// A front- or back-matter page, with its text already resolved.
class BookMatterPage {
  const BookMatterPage({
    required this.id,
    required this.kind,
    required this.title,
    required this.paragraphs,
    required this.layout,
    this.startsOnRecto = true,
  });

  final String id;
  final BookSectionKind kind;
  final String title;

  /// Resolved body text. Empty for [BookMatterLayout.contents], which is filled
  /// in after the body has been paginated.
  final List<String> paragraphs;

  final BookMatterLayout layout;
  final bool startsOnRecto;
}

/// One paragraph of a scene, as the author wrote it.
///
/// Carries two things that must not be conflated.
///
/// [text] is the source: the characters the author typed, markers and all. It
/// is what a proof finding's offsets point into, what an auto-fix rewrites and
/// what the word count counts, so it stays a plain string.
///
/// [marked] is the same paragraph as the editor recorded it — real
/// [ProseMark]s, applied with Manuscript Studio's toolbar and stored in the
/// scene's [ProseDocument]. It is null for a paragraph the author never marked,
/// which is every paragraph of every manuscript written before that toolbar
/// existed. That is why [resolve] falls back to reading the typed convention:
/// the two coexist, paragraph by paragraph, and neither has to be migrated into
/// the other.
class BookParagraph {
  const BookParagraph(this.text, {this.marked});

  final String text;
  final List<ProseSpan>? marked;

  bool get isEmpty => text.isEmpty;

  /// The spans to set, preferring what the editor actually recorded.
  ///
  /// Where the author used the toolbar, an underscore is a literal underscore:
  /// they said what they meant in the editor, and re-reading their prose for a
  /// second opinion is how a file name becomes an italic by accident. Where
  /// they did not, the convention applies exactly as it did before.
  List<ProseSpan> resolve(BookInlineMarkup markup) =>
      marked ?? parseProse(text, markup);

  @override
  String toString() => marked == null ? text : '$text (marked)';
}

/// One scene's prose, already split into paragraphs.
class BookSceneContent {
  const BookSceneContent({
    required this.id,
    required this.title,
    required this.paragraphs,
  });

  final String id;
  final String title;
  final List<BookParagraph> paragraphs;

  bool get isEmpty => paragraphs.isEmpty;

  int get wordCount => paragraphs.fold<int>(
        0,
        (sum, paragraph) =>
            sum +
            paragraph.text
                .trim()
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length,
      );
}

/// One chapter of the body.
class BookChapterContent {
  const BookChapterContent({
    required this.id,
    required this.title,
    required this.number,
    required this.scenes,
  });

  final String id;
  final String title;

  /// 1-based position among the body's chapters, for `Chapter N`.
  final int number;

  final List<BookSceneContent> scenes;

  int get wordCount =>
      scenes.fold<int>(0, (sum, scene) => sum + scene.wordCount);

  bool get isEmpty => scenes.every((scene) => scene.isEmpty);
}

/// A part heading in the body.
class BookPartHeading {
  const BookPartHeading({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.number,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 1-based position among the book's parts.
  final int number;

  /// The heading shown when the author left the title blank.
  String get displayTitle =>
      title.trim().isEmpty ? 'Part ${_romanUpper(number)}' : title.trim();
}

/// One element of the body's reading order.
sealed class BookBodyElement {
  const BookBodyElement();
}

class BookPartElement extends BookBodyElement {
  const BookPartElement(this.heading);
  final BookPartHeading heading;
}

class BookChapterElement extends BookBodyElement {
  const BookChapterElement(this.chapter);
  final BookChapterContent chapter;
}

/// Something the builder could not resolve.
///
/// Reported rather than silently repaired, and never a crash.
class BookDocumentIssue {
  const BookDocumentIssue(this.code, this.message, {this.subjectId});

  final String code;
  final String message;
  final String? subjectId;

  @override
  String toString() => '[$code] $message';
}

/// The manuscript and the book settings, flattened into one reading order.
///
/// Derived and never persisted.
class BookDocument {
  const BookDocument({
    required this.metadata,
    required this.frontMatter,
    required this.body,
    required this.backMatter,
    this.issues = const [],
    this.inlineMarkup = BookInlineMarkup.none,
  });

  final BookMetadata metadata;
  final List<BookMatterPage> frontMatter;
  final List<BookBodyElement> body;
  final List<BookMatterPage> backMatter;
  final List<BookDocumentIssue> issues;

  /// The emphasis convention the author's prose is written in.
  ///
  /// Carried on the document so that every exporter reads the same answer from
  /// the same place. It comes from the book's typography, and copying it here
  /// rather than passing it to four `export` methods is what stops the EPUB and
  /// the Word file disagreeing about whether an underscore means anything —
  /// the drift `chapterNumberLabel` exists to prevent, in a different guise.
  ///
  /// The paragraphs themselves stay as the author wrote them, markers and all:
  /// they are what a proof finding's offsets point into and what an auto-fix
  /// rewrites. `parseProse` resolves them at the moment of use.
  final BookInlineMarkup inlineMarkup;

  Iterable<BookChapterContent> get chapters =>
      body.whereType<BookChapterElement>().map((element) => element.chapter);

  int get chapterCount => chapters.length;

  int get wordCount =>
      chapters.fold<int>(0, (sum, chapter) => sum + chapter.wordCount);
}

/// Builds a [BookDocument] from a manuscript and the author's book settings.
class BookDocumentBuilder {
  const BookDocumentBuilder();

  /// Scene-break markers an author may already have typed into their prose.
  ///
  /// A paragraph that is nothing but one of these is a break, not a line of
  /// text, so it must not be set as prose.
  ///
  /// The recognition itself is `core/scene_break_markers.dart`, because it is a
  /// fact about what the author typed rather than about a book — ADR-0009. This
  /// stays as the name every existing caller already uses.
  static bool isSceneBreakMarker(String paragraph) =>
      markers.isSceneBreakMarker(paragraph);

  ///
  /// [authorshipNote], when given, becomes the last back-matter page: the
  /// book's authorship fingerprint and figures, printed so a copy can be tied
  /// to its authorship statement (PLAN.md §3.39). Every format lays out back
  /// matter, so every format carries it.
  BookDocument build({
    required ManuscriptProjectSummary manuscript,
    required BookProject book,
    String profileAuthorName = '',
    SeriesStanding? series,
    List<String>? authorshipNote,
  }) {
    final issues = <BookDocumentIssue>[];
    final metadata = resolveMetadata(
      manuscript: manuscript,
      book: book,
      profileAuthorName: profileAuthorName,
      series: series,
    );

    final orderedChapters = [...manuscript.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));

    final body = _buildBody(orderedChapters, book, issues);
    final front = _buildMatter(book.frontMatter, metadata, issues);
    final back = [
      ..._buildMatter(book.backMatter, metadata, issues),
      if (authorshipNote != null && authorshipNote.isNotEmpty)
        BookMatterPage(
          id: 'authorship-fingerprint',
          kind: BookSectionKind.custom,
          title: 'Authorship',
          paragraphs: authorshipNote,
          layout: BookMatterLayout.flowingText,
        ),
    ];

    if (orderedChapters.isEmpty) {
      issues.add(const BookDocumentIssue(
        'emptyManuscript',
        'The manuscript has no chapters, so the book has no body.',
      ));
    }

    return BookDocument(
      metadata: metadata,
      frontMatter: front,
      body: body,
      backMatter: back,
      issues: issues,
      inlineMarkup: book.format.typography.inlineMarkup,
    );
  }

  /// Resolves title, author and the series line from their overrides, falling
  /// back to the live manuscript title, the author profile and the roster.
  ///
  /// Every one of the four is the same shape: what the author typed on this
  /// book wins, and where they typed nothing the application answers from
  /// canon rather than leaving a blank. The series name and number were the
  /// last two that could not — they were free text, so a series renamed in
  /// Projects Studio left every cover in it saying the old name.
  BookMetadata resolveMetadata({
    required ManuscriptProjectSummary manuscript,
    required BookProject book,
    String profileAuthorName = '',
    SeriesStanding? series,
  }) {
    final title = book.titleOverride.trim().isNotEmpty
        ? book.titleOverride.trim()
        : manuscript.manuscriptTitle.trim();
    final author = book.authorOverride.trim().isNotEmpty
        ? book.authorOverride.trim()
        : profileAuthorName.trim();
    final seriesName = book.seriesName.trim().isNotEmpty
        ? book.seriesName.trim()
        : (series?.name.trim() ?? '');
    // The typed number is kept as an override for what a position cannot say:
    // a novella numbered 2.5, a prequel numbered 0, an omnibus with none.
    final seriesNumber = book.seriesNumber.trim().isNotEmpty
        ? book.seriesNumber.trim()
        : (series?.bookNumberWord ?? '');
    return BookMetadata(
      title: title.isEmpty ? 'Untitled' : title,
      authorName: author,
      subtitle: book.subtitle.trim(),
      seriesName: seriesName,
      seriesNumber: seriesNumber,
      isbn: book.isbn.trim(),
      publisher: book.publisher.trim(),
      copyrightYear: book.copyrightYear.trim(),
      copyrightHolder: book.copyrightHolder.trim().isNotEmpty
          ? book.copyrightHolder.trim()
          : author.trim(),
      edition: book.edition.trim(),
      rightsStatement: book.rightsStatement.trim(),
    );
  }

  List<BookBodyElement> _buildBody(
    List<ManuscriptChapter> chapters,
    BookProject book,
    List<BookDocumentIssue> issues,
  ) {
    final chapterIds = chapters.map((chapter) => chapter.id).toSet();
    final orderedParts = [...book.parts]
      ..sort((a, b) => a.order.compareTo(b.order));

    final partsByAnchor = <String, BookPart>{};
    var partNumber = 0;
    final numbering = <String, int>{};
    for (final part in orderedParts) {
      if (!chapterIds.contains(part.startsAtChapterId)) {
        issues.add(BookDocumentIssue(
          'danglingPart',
          'Part "${part.title.isEmpty ? part.id : part.title}" starts at a '
              'chapter that no longer exists, so it is not shown.',
          subjectId: part.id,
        ));
        continue;
      }
      if (partsByAnchor.containsKey(part.startsAtChapterId)) {
        issues.add(BookDocumentIssue(
          'duplicatePartAnchor',
          'More than one part starts at the same chapter; only the first is '
              'shown.',
          subjectId: part.id,
        ));
        continue;
      }
      partNumber += 1;
      numbering[part.id] = partNumber;
      partsByAnchor[part.startsAtChapterId] = part;
    }

    final body = <BookBodyElement>[];
    var chapterNumber = 0;
    for (final chapter in chapters) {
      final part = partsByAnchor[chapter.id];
      if (part != null) {
        body.add(BookPartElement(BookPartHeading(
          id: part.id,
          title: part.title,
          subtitle: part.subtitle,
          number: numbering[part.id] ?? 1,
        )));
      }
      chapterNumber += 1;
      body.add(BookChapterElement(BookChapterContent(
        id: chapter.id,
        title: chapter.title,
        number: chapterNumber,
        scenes: _scenes(chapter),
      )));
    }
    return body;
  }

  List<BookSceneContent> _scenes(ManuscriptChapter chapter) {
    final ordered = [...chapter.scenes]
      ..sort((a, b) => a.order.compareTo(b.order));
    return ordered
        .map((scene) => BookSceneContent(
              id: scene.id,
              title: scene.title,
              paragraphs: _sceneParagraphs(scene),
            ))
        .toList(growable: false);
  }

  /// The scene's paragraphs, carrying the editor's marks where it recorded any.
  ///
  /// Walks the scene's text and its stored blocks in lockstep. That alignment
  /// is exact by construction: [ProseDocument.fromPlainText] is one block per
  /// line and [ProseDocument.plainText] joins them with newlines, so block `i`
  /// is line `i` for as long as the two still describe the same prose.
  static List<BookParagraph> _sceneParagraphs(ManuscriptScene scene) {
    final blocks = _markedBlocks(scene);
    final lines = scene.content.split('\n');
    final paragraphs = <BookParagraph>[];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      if (isSceneBreakMarker(trimmed)) continue;

      // [_sceneBreakMarker] recognises a break an author *typed*; this
      // recognises one the document *knows about*, which is the stronger
      // signal and the only one available for a scene marker. A marker's
      // description is the author planning the scene — "Lucia climbs the
      // tower, alone" — and a reader must never find it in the book.
      //
      // Skipped rather than turned into a break, because the break between
      // scenes is the exporters' to place: they already emit the one the
      // book's format asks for, and a second from here would double it.
      final block = blocks == null || i >= blocks.length ? null : blocks[i];
      if (block != null && block.kind.isStructural) continue;

      final spans = block == null ? null : _trimSpans(block.spans);

      // Only a paragraph the author actually marked overrides the convention.
      // An unmarked one in a scene that happens to hold marks elsewhere still
      // honours the underscores it was typed with, so switching to the toolbar
      // mid-manuscript does not silently un-italicise everything above it.
      paragraphs.add(BookParagraph(
        trimmed,
        marked: spans != null && spans.any((span) => span.marks.isNotEmpty)
            ? spans
            : null,
      ));
    }
    return paragraphs;
  }

  /// The scene's stored blocks, when they still describe its text.
  ///
  /// A document whose plain text has drifted from the scene's content is stale
  /// — something wrote the string without the document — and reading marks out
  /// of it would put them on the wrong words. `ManuscriptStore` refuses to save
  /// such a pair for the same reason; this refuses to read one.
  static List<ProseBlock>? _markedBlocks(ManuscriptScene scene) {
    final document = scene.document;
    if (document == null) return null;
    if (document.plainText != scene.content) return null;
    return document.blocks;
  }

  /// [spans] with leading and trailing whitespace removed.
  ///
  /// The line they came from is trimmed before it becomes a paragraph, and a
  /// span list that still carried the indentation would set the marks one
  /// character out from the text beside it.
  static List<ProseSpan> _trimSpans(List<ProseSpan> spans) {
    final trimmed = [...spans];
    while (trimmed.isNotEmpty) {
      final text = trimmed.first.text.trimLeft();
      if (text.isEmpty) {
        trimmed.removeAt(0);
        continue;
      }
      trimmed[0] = trimmed.first.copyWith(text: text);
      break;
    }
    while (trimmed.isNotEmpty) {
      final text = trimmed.last.text.trimRight();
      if (text.isEmpty) {
        trimmed.removeLast();
        continue;
      }
      trimmed[trimmed.length - 1] = trimmed.last.copyWith(text: text);
      break;
    }
    return trimmed;
  }

  /// Splits plain scene prose into paragraphs.
  ///
  /// Scene text is a bare string edited in a plain field, so a paragraph is a
  /// non-empty line. Blank lines collapse, and a line that is only a scene-break
  /// marker is dropped here — the engine draws breaks from the format instead.
  static List<String> splitParagraphs(String content) {
    final paragraphs = <String>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (isSceneBreakMarker(trimmed)) continue;
      paragraphs.add(trimmed);
    }
    return paragraphs;
  }

  List<BookMatterPage> _buildMatter(
    List<BookSection> sections,
    BookMetadata metadata,
    List<BookDocumentIssue> issues,
  ) {
    final ordered = [...sections]..sort((a, b) => a.order.compareTo(b.order));
    final pages = <BookMatterPage>[];
    for (final section in ordered) {
      if (!section.included) continue;
      final paragraphs = !section.kind.hasBody
          ? const <String>[]
          : section.isGenerated
              ? _generate(section, metadata, issues)
              : splitParagraphs(section.body);
      // A plate is legitimately empty of words — it is a picture. Only a
      // section that was *meant* to carry text and does not is a fault.
      if (section.kind.hasBody && !section.isGenerated && paragraphs.isEmpty) {
        issues.add(BookDocumentIssue(
          'emptySection',
          '${section.kind.label} is switched on but has no text, so it would '
              'print as a blank page.',
          subjectId: section.id,
        ));
        continue;
      }
      pages.add(BookMatterPage(
        id: section.id,
        kind: section.kind,
        title: section.title.trim(),
        paragraphs: paragraphs,
        layout: section.kind.layout,
        // A plate opens on a verso so the section after it faces it — the
        // frontispiece convention, and the reason this flag exists.
        startsOnRecto: section.kind != BookSectionKind.plate,
      ));
    }
    return pages;
  }

  /// Renders a generated section from the book's metadata.
  List<String> _generate(
    BookSection section,
    BookMetadata metadata,
    List<BookDocumentIssue> issues,
  ) {
    switch (section.kind) {
      case BookSectionKind.halfTitle:
        return [metadata.title];
      case BookSectionKind.titlePage:
        return [
          metadata.title,
          if (metadata.subtitle.isNotEmpty) metadata.subtitle,
          if (metadata.seriesName.isNotEmpty)
            metadata.seriesNumber.isEmpty
                ? metadata.seriesName
                : '${metadata.seriesName}, Book ${metadata.seriesNumber}',
          if (metadata.authorName.isNotEmpty) metadata.authorName,
          if (metadata.publisher.isNotEmpty) metadata.publisher,
        ];
      case BookSectionKind.copyright:
        if (metadata.copyrightYear.isEmpty ||
            metadata.copyrightHolder.isEmpty) {
          issues.add(BookDocumentIssue(
            'incompleteCopyright',
            'The copyright page is switched on but the year or the rights '
                'holder is missing.',
            subjectId: section.id,
          ));
        }
        final holder = metadata.copyrightHolder.isEmpty
            ? metadata.authorName
            : metadata.copyrightHolder;
        return [
          metadata.title,
          if (metadata.edition.isNotEmpty) metadata.edition,
          if (metadata.copyrightYear.isNotEmpty || holder.isNotEmpty)
            'Copyright © ${metadata.copyrightYear}'
                    '${holder.isEmpty ? '' : ' $holder'}'
                .trim(),
          if (metadata.rightsStatement.isNotEmpty)
            metadata.rightsStatement
          else
            'All rights reserved. No part of this book may be reproduced in '
                'any form without written permission from the publisher, '
                'except brief quotations in a review.',
          'This is a work of fiction. Names, characters, places and incidents '
              'are the product of the author’s imagination or are used '
              'fictitiously.',
          if (metadata.isbn.isNotEmpty) 'ISBN ${metadata.isbn}',
          if (metadata.publisher.isNotEmpty) metadata.publisher,
        ];
      case BookSectionKind.contents:
        // Filled in by the layout engine once the body has page numbers.
        return const [];
      default:
        return splitParagraphs(section.body);
    }
  }
}

/// Upper-case Roman numerals, used for default part headings.
String _romanUpper(int value) {
  if (value <= 0) return '$value';
  const numerals = <int, String>{
    1000: 'M',
    900: 'CM',
    500: 'D',
    400: 'CD',
    100: 'C',
    90: 'XC',
    50: 'L',
    40: 'XL',
    10: 'X',
    9: 'IX',
    5: 'V',
    4: 'IV',
    1: 'I',
  };
  final buffer = StringBuffer();
  var remaining = value;
  for (final entry in numerals.entries) {
    while (remaining >= entry.key) {
      buffer.write(entry.value);
      remaining -= entry.key;
    }
  }
  return buffer.toString();
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

/// How many emphasised spans a whole book contains.
///
/// Counted from the real prose through the same [BookParagraph.resolve] every
/// exporter uses, so the number an author is shown before switching the
/// convention on is the number they will get — including the marks they applied
/// with the toolbar, which are emphasis whether the convention is on or not.
///
/// Lives here rather than in `inline_markup.dart` because resolving a paragraph
/// now needs the document model, and the parser must not depend on it.
int countEmphasis(BookDocument document, BookInlineMarkup markup) {
  var total = 0;

  void countText(Iterable<String> paragraphs) {
    for (final paragraph in paragraphs) {
      total +=
          parseProse(paragraph, markup).where((span) => span.italic).length;
    }
  }

  for (final page in document.frontMatter) {
    countText(page.paragraphs);
  }
  for (final element in document.body) {
    if (element is! BookChapterElement) continue;
    for (final scene in element.chapter.scenes) {
      for (final paragraph in scene.paragraphs) {
        total += paragraph.resolve(markup).where((span) => span.italic).length;
      }
    }
  }
  for (final page in document.backMatter) {
    countText(page.paragraphs);
  }
  return total;
}
