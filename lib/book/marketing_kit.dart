/// The marketing kit: twelve artboards over one set of bound values.
///
/// The kit holds almost nothing. It names a quote by citation, a character by
/// record id, and which of the twelve sizes the author wants — and everything
/// a card actually prints is resolved from the book, the manuscript and the
/// profile at the moment the kit is opened. Change the title once and all
/// twelve follow, because none of them stored it.
///
/// What the kit does own is the part no other system can answer: which sizes
/// this release wants, what each one's alt text says, and where the cover
/// artwork may legally be used.
library;

import 'marketing_quote.dart';

/// What an artboard is for, which is what its artwork's licence has to allow.
enum MarketingUse {
  /// Posted, mailed or shown on a screen.
  digital,

  /// Printed on paper — a bookmark, a postcard.
  print,

  /// Printed on a thing that is sold or given away.
  merchandise,
}

extension MarketingUseX on MarketingUse {
  String get label => switch (this) {
        MarketingUse.digital => 'Digital',
        MarketingUse.print => 'Print',
        MarketingUse.merchandise => 'Merchandise',
      };
}

/// What an exported artboard is written as.
enum MarketingFormat { png, pdf }

extension MarketingFormatX on MarketingFormat {
  String get extension => switch (this) {
        MarketingFormat.png => 'png',
        MarketingFormat.pdf => 'pdf',
      };

  String get mediaType => switch (this) {
        MarketingFormat.png => 'image/png',
        MarketingFormat.pdf => 'application/pdf',
      };
}

/// How an artboard is composed.
///
/// Five compositions across twelve sizes: the same card reflowed rather than
/// twelve separate designs, which is what makes "change it once here and all
/// twelve follow" true of the layout as well as the values.
enum MarketingLayout {
  /// Cover, title, author, and the release line.
  announcement,

  /// The quote, its chapter, and the book it is from.
  quote,

  /// A character's name and where they stand.
  character,

  /// Wide and short: a title and one line, nothing else fits.
  banner,

  /// Tall and narrow, set like a spine.
  spine,
}

/// One artboard: how big, in what, for what.
class MarketingSize {
  const MarketingSize({
    required this.id,
    required this.label,
    required this.layout,
    required this.use,
    required this.format,
    required this.widthPx,
    required this.heightPx,
    required this.dpi,
    this.widthInches = 0,
    this.heightInches = 0,
    this.bleedInches = 0,
  });

  /// A print piece, given in the units a printer works in.
  factory MarketingSize.printed({
    required String id,
    required String label,
    required MarketingLayout layout,
    required MarketingUse use,
    required double widthInches,
    required double heightInches,
    int dpi = 300,
    double bleedInches = 0.125,
  }) =>
      MarketingSize(
        id: id,
        label: label,
        layout: layout,
        use: use,
        format: MarketingFormat.pdf,
        widthPx: (widthInches + bleedInches * 2) * dpi,
        heightPx: (heightInches + bleedInches * 2) * dpi,
        dpi: dpi,
        widthInches: widthInches,
        heightInches: heightInches,
        bleedInches: bleedInches,
      );

  final String id;
  final String label;
  final MarketingLayout layout;
  final MarketingUse use;
  final MarketingFormat format;

  /// The exported pixel size, bleed included.
  final double widthPx;
  final double heightPx;

  final int dpi;

  /// The trim size, for a print piece. Zero for a screen size, which has no
  /// physical dimensions — 1080 pixels is 15 inches or 3.6, depending on
  /// nothing the file itself records.
  final double widthInches;
  final double heightInches;

  /// Extra artwork beyond the trim, so a cut a hair off centre does not leave
  /// a white edge. Zero for anything that is never cut.
  final double bleedInches;

  bool get isPrint => format == MarketingFormat.pdf;

  String get fileName => '$id.${format.extension}';

  /// How the size reads to an author: pixels for a screen, inches for a page.
  String get dimensions => isPrint
      ? '${_trim(widthInches)} × ${_trim(heightInches)} in'
      : '${widthPx.round()} × ${heightPx.round()}';

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';
}

/// The twelve artboards a release-day kit is made of.
///
/// A table and not a set of classes: adding a size is a row, which is what
/// keeps twelve of them honest. Order is the order they are shown and
/// exported in.
class MarketingSizes {
  const MarketingSizes._();

  static const instagramPost = MarketingSize(
    id: 'instagram-post',
    label: 'Instagram post',
    layout: MarketingLayout.announcement,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1080,
    heightPx: 1080,
    dpi: 72,
  );

  static const story = MarketingSize(
    id: 'story',
    label: 'Story',
    layout: MarketingLayout.announcement,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1080,
    heightPx: 1920,
    dpi: 72,
  );

  static const quoteCard = MarketingSize(
    id: 'quote-card',
    label: 'Quote card',
    layout: MarketingLayout.quote,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1080,
    heightPx: 1080,
    dpi: 72,
  );

  static const characterCard = MarketingSize(
    id: 'character-card',
    label: 'Character card',
    layout: MarketingLayout.character,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1080,
    heightPx: 1350,
    dpi: 72,
  );

  static const social = MarketingSize(
    id: 'x-bluesky',
    label: 'X / Bluesky',
    layout: MarketingLayout.announcement,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1600,
    heightPx: 900,
    dpi: 72,
  );

  static const facebook = MarketingSize(
    id: 'facebook',
    label: 'Facebook',
    layout: MarketingLayout.announcement,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1200,
    heightPx: 630,
    dpi: 72,
  );

  static const newsletter = MarketingSize(
    id: 'newsletter',
    label: 'Newsletter',
    layout: MarketingLayout.banner,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1200,
    heightPx: 400,
    dpi: 72,
  );

  static const pinterest = MarketingSize(
    id: 'pinterest',
    label: 'Pinterest',
    layout: MarketingLayout.announcement,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1000,
    heightPx: 1500,
    dpi: 72,
  );

  static const preOrderBanner = MarketingSize(
    id: 'pre-order-banner',
    label: 'Pre-order banner',
    layout: MarketingLayout.banner,
    use: MarketingUse.digital,
    format: MarketingFormat.png,
    widthPx: 1500,
    heightPx: 500,
    dpi: 72,
  );

  static final bookmark = MarketingSize.printed(
    id: 'bookmark',
    label: 'Bookmark',
    layout: MarketingLayout.spine,
    use: MarketingUse.print,
    widthInches: 2,
    heightInches: 6,
  );

  static final postcard = MarketingSize.printed(
    id: 'postcard',
    label: 'Postcard',
    layout: MarketingLayout.announcement,
    use: MarketingUse.print,
    widthInches: 4,
    heightInches: 6,
  );

  static final tote = MarketingSize.printed(
    id: 'tote',
    label: 'Tote artwork',
    layout: MarketingLayout.quote,
    use: MarketingUse.merchandise,
    widthInches: 12,
    heightInches: 14,
    bleedInches: 0,
  );

  static final all = <MarketingSize>[
    instagramPost,
    story,
    quoteCard,
    characterCard,
    social,
    facebook,
    newsletter,
    pinterest,
    preOrderBanner,
    bookmark,
    postcard,
    tote,
  ];

  static MarketingSize? byId(String id) {
    for (final size in all) {
      if (size.id == id) return size;
    }
    return null;
  }
}

/// Where the cover artwork may be used, as the author recorded it.
///
/// Unrecorded is its own state, and not the same as "anything goes". An
/// author who drew their own cover should not have to answer a licence
/// question before making a card, so nothing is blocked until rights are
/// recorded — but the kit says the question is unanswered, and the credits
/// sheet records that it was, rather than implying a clearance nobody gave.
class ArtworkRights {
  const ArtworkRights({
    this.recorded = false,
    this.allowedUses = const {},
    this.credit = '',
    this.licence = '',
  });

  final bool recorded;

  /// The uses the licence permits. Only consulted when [recorded].
  final Set<MarketingUse> allowedUses;

  /// The line that goes on the credits sheet — "Cover art by …".
  final String credit;

  /// What the licence is, in the author's own words or as a link.
  final String licence;

  /// Whether an artboard for [use] may be exported.
  bool permits(MarketingUse use) => !recorded || allowedUses.contains(use);

  /// Why a use is refused, or empty when it is not.
  String refusalFor(MarketingUse use, {String artwork = 'The cover artwork'}) {
    if (permits(use)) return '';
    final allowed = MarketingUse.values
        .where(allowedUses.contains)
        .map((u) => u.label.toLowerCase())
        .toList();
    final permitted = allowed.isEmpty
        ? 'nothing'
        : allowed.length == 1
            ? allowed.single
            : '${allowed.take(allowed.length - 1).join(', ')} and '
                '${allowed.last}';
    return '$artwork is licensed for $permitted. '
        '${use.label} is not in its allowed uses, and this artboard targets '
        '${use.label.toLowerCase()}.';
  }

  ArtworkRights copyWith({
    bool? recorded,
    Set<MarketingUse>? allowedUses,
    String? credit,
    String? licence,
  }) =>
      ArtworkRights(
        recorded: recorded ?? this.recorded,
        allowedUses: allowedUses ?? this.allowedUses,
        credit: credit ?? this.credit,
        licence: licence ?? this.licence,
      );

  Map<String, Object?> toJson() => {
        'recorded': recorded,
        'allowedUses': allowedUses.map((use) => use.name).toList(),
        'credit': credit,
        'licence': licence,
      };

  factory ArtworkRights.fromJson(Map<String, dynamic> json) => ArtworkRights(
        recorded: (json['recorded'] as bool?) ?? false,
        allowedUses: {
          for (final raw in (json['allowedUses'] as List?) ?? const [])
            for (final use in MarketingUse.values)
              if (use.name == raw) use,
        },
        credit: (json['credit'] as String?) ?? '',
        licence: (json['licence'] as String?) ?? '',
      );
}

/// A character, as the card needs them.
///
/// A value and not a record, so the kit's domain never reaches the database.
/// The studio loads the record and hands the two lines over.
class MarketingCharacter {
  const MarketingCharacter({
    required this.recordId,
    required this.name,
    this.affiliation = '',
  });

  final String recordId;
  final String name;

  /// Where they stand — a house, an order, a rank. Empty is fine; the card
  /// simply sets the name alone.
  final String affiliation;
}

/// The author's kit for this book.
class MarketingKit {
  const MarketingKit({
    this.name = 'Release day kit',
    this.quote,
    this.characterRecordId = '',
    this.enabledSizeIds = const {},
    this.altText = const {},
    this.rights = const ArtworkRights(),
    this.updatedAt,
  });

  final String name;

  /// The quote, by citation. Null until the author picks one.
  final QuoteCitation? quote;

  /// Which character the character card is of. Empty leaves that card out.
  final String characterRecordId;

  /// The sizes this release wants. Empty means all twelve, so a kit that has
  /// never been configured is a complete kit rather than an empty one.
  final Set<String> enabledSizeIds;

  /// What each artboard says to a reader who cannot see it, by size id.
  final Map<String, String> altText;

  final ArtworkRights rights;

  final DateTime? updatedAt;

  /// The sizes in play, in table order.
  List<MarketingSize> get sizes => enabledSizeIds.isEmpty
      ? MarketingSizes.all
      : MarketingSizes.all
          .where((size) => enabledSizeIds.contains(size.id))
          .toList(growable: false);

  bool includes(MarketingSize size) =>
      enabledSizeIds.isEmpty || enabledSizeIds.contains(size.id);

  MarketingKit withSize(MarketingSize size, bool on) {
    final current = enabledSizeIds.isEmpty
        ? MarketingSizes.all.map((s) => s.id).toSet()
        : {...enabledSizeIds};
    if (on) {
      current.add(size.id);
    } else {
      current.remove(size.id);
    }
    return copyWith(enabledSizeIds: current);
  }

  MarketingKit copyWith({
    String? name,
    QuoteCitation? quote,
    bool clearQuote = false,
    String? characterRecordId,
    Set<String>? enabledSizeIds,
    Map<String, String>? altText,
    ArtworkRights? rights,
    DateTime? updatedAt,
  }) =>
      MarketingKit(
        name: name ?? this.name,
        quote: clearQuote ? null : (quote ?? this.quote),
        characterRecordId: characterRecordId ?? this.characterRecordId,
        enabledSizeIds: enabledSizeIds ?? this.enabledSizeIds,
        altText: altText ?? this.altText,
        rights: rights ?? this.rights,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        if (quote != null) 'quote': quote!.toJson(),
        'characterRecordId': characterRecordId,
        'enabledSizeIds': enabledSizeIds.toList(),
        'altText': altText,
        'rights': rights.toJson(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory MarketingKit.fromJson(Map<String, dynamic> json) => MarketingKit(
        name: (json['name'] as String?) ?? 'Release day kit',
        quote: json['quote'] == null
            ? null
            : QuoteCitation.fromJson(
                (json['quote'] as Map).cast<String, dynamic>()),
        characterRecordId: (json['characterRecordId'] as String?) ?? '',
        enabledSizeIds: {
          for (final raw in (json['enabledSizeIds'] as List?) ?? const [])
            '$raw',
        },
        altText: {
          for (final entry
              in ((json['altText'] as Map?) ?? const {}).entries)
            '${entry.key}': '${entry.value}',
        },
        rights: ArtworkRights.fromJson(
            (json['rights'] as Map?)?.cast<String, dynamic>() ?? const {}),
        updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
      );
}
