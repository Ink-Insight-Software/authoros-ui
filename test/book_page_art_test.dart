import 'dart:io';
import 'dart:typed_data';

import 'package:authoros_ui/book/book_document.dart';
import 'package:authoros_ui/book/book_fonts.dart';
import 'package:authoros_ui/book/book_format.dart';
import 'package:authoros_ui/book/book_layout.dart';
import 'package:authoros_ui/book/book_pdf_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Page art: a corner piece on each chapter's opening page, mirrored into
/// two corners or four, and a tailpiece under a chapter's last line where
/// the page has room.

BookDocument _document({int paragraphs = 2}) => BookDocument(
      metadata: const BookMetadata(title: 'The Reach', authorName: 'An Author'),
      frontMatter: const [],
      backMatter: const [],
      body: [
        for (var c = 1; c <= 2; c++)
          BookChapterElement(BookChapterContent(
            id: 'chapter-$c',
            title: 'Chapter $c',
            number: c,
            scenes: [
              BookSceneContent(id: 'scene-$c', title: '', paragraphs: [
                for (var p = 0; p < paragraphs; p++)
                  const BookParagraph('The bells of the reach rang twice.'),
              ]),
            ],
          )),
      ],
    );

BookFontAssets _assets() {
  final bytes = File('test/fonts/Merriweather-400.ttf').readAsBytesSync();
  return BookFontAssets({
    BookFontFace.merriweatherRegular: ByteData.sublistView(bytes),
  });
}

Uint8List _png(int width, int height) => Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height, numChannels: 4)));

void main() {
  final corner = BookOrnamentArt(bytes: _png(40, 40), aspect: 1);
  final tail = BookOrnamentArt(bytes: _png(100, 20), aspect: 5);

  PaginatedBook layout({
    BookPageArt art = const BookPageArt(),
    CornerArtPlacement placement = CornerArtPlacement.topTwo,
    int paragraphs = 2,
  }) {
    final format = BookFormatPresets.paperback;
    return BookLayoutEngine(PdfBookFontMetrics(_assets()), pageArt: art).layout(
      _document(paragraphs: paragraphs),
      format.copyWith(chapter: format.chapter.copyWith(cornerArt: placement)),
    );
  }

  List<LayoutPageArt> artOn(LaidOutPage page) =>
      page.elements.whereType<LayoutPageArt>().toList();

  test('a book with no page art is laid out as it always was', () {
    final plain = layout();
    expect(plain.pages.expand(artOn), isEmpty);
    // And supplying art does not move a line of type.
    final dressed = layout(art: BookPageArt(corner: corner, tailpiece: tail));
    expect(dressed.pageCount, plain.pageCount);
    for (var i = 0; i < plain.pageCount; i++) {
      List<double> lines(LaidOutPage p) =>
          [for (final e in p.elements.whereType<LayoutTextLine>()) e.y];
      expect(lines(dressed.pages[i]), lines(plain.pages[i]), reason: 'page $i');
    }
  });

  test('corners sit on chapter opening pages only, the top two by default',
      () {
    final book = layout(art: BookPageArt(corner: corner), paragraphs: 60);
    final openers = book.pages
        .where((p) => p.role == BookPageRole.chapterOpener)
        .toList();
    expect(openers, hasLength(2));
    expect(book.pages.any((p) => p.role == BookPageRole.body), isTrue,
        reason: 'the fixture runs past its opening page');
    for (final page in book.pages) {
      final corners = artOn(page).where((a) => a.slot.isCorner).toList();
      if (page.role != BookPageRole.chapterOpener) {
        expect(corners, isEmpty, reason: 'page ${page.index}');
        continue;
      }
      expect(corners.map((a) => a.slot), [
        BookPageArtSlot.cornerTopLeft,
        BookPageArtSlot.cornerTopRight,
      ]);
      final left = corners[0], right = corners[1];
      // The same size, mirrored about the middle of the text block, and
      // reaching out of it into the margins.
      expect(left.widthPt, right.widthPt);
      expect(left.heightPt, left.widthPt / corner.aspect);
      expect(left.x, lessThan(0));
      expect(left.y, lessThan(0));
      expect(right.x + right.widthPt,
          closeTo(page.textBlockWidthPt - left.x, 0.001));
      // But never off the paper.
      expect(page.textBlockLeftPt + left.x, greaterThan(0));
      expect(page.textBlockTopPt + left.y, greaterThan(0));
      expect(page.textBlockLeftPt + right.x + right.widthPt,
          lessThan(page.trimWidthPt));
    }
  });

  test('the format can ask for all four corners', () {
    final book = layout(
      art: BookPageArt(corner: corner),
      placement: CornerArtPlacement.allFour,
    );
    final page =
        book.pages.firstWhere((p) => p.role == BookPageRole.chapterOpener);
    final corners = artOn(page);
    expect(corners.map((a) => a.slot), BookPageArtSlot.values.where((s) => s.isCorner));
    final bottom = corners
        .firstWhere((a) => a.slot == BookPageArtSlot.cornerBottomLeft);
    expect(bottom.y + bottom.heightPt, greaterThan(page.textBlockHeightPt));
    expect(page.textBlockTopPt + bottom.y + bottom.heightPt,
        lessThan(page.trimHeightPt));
    // Mirrored the way its corner needs.
    expect(BookPageArtSlot.cornerTopLeft.flipX, isFalse);
    expect(BookPageArtSlot.cornerTopRight.flipX, isTrue);
    expect(BookPageArtSlot.cornerTopRight.flipY, isFalse);
    expect(BookPageArtSlot.cornerBottomLeft.flipY, isTrue);
    expect(BookPageArtSlot.cornerBottomRight.flipX, isTrue);
    expect(BookPageArtSlot.cornerBottomRight.flipY, isTrue);
  });

  test('the tailpiece sits centred under each chapter\'s last line', () {
    final book = layout(art: BookPageArt(tailpiece: tail));
    final tails = [
      for (final page in book.pages)
        for (final a in artOn(page))
          if (a.slot == BookPageArtSlot.tailpiece) (page, a),
    ];
    expect(tails, hasLength(2), reason: 'one for each chapter');
    for (final (page, piece) in tails) {
      final lastLine = page.elements
          .whereType<LayoutTextLine>()
          .map((l) => l.y)
          .reduce((a, b) => a > b ? a : b);
      expect(piece.y, greaterThan(lastLine));
      expect(piece.x + piece.widthPt / 2,
          closeTo(page.textBlockWidthPt / 2, 0.001));
      expect(piece.heightPt, closeTo(piece.widthPt / tail.aspect, 0.001));
      expect(piece.y + piece.heightPt,
          lessThanOrEqualTo(page.textBlockHeightPt));
    }
  });

  test('a chapter that runs to the foot of its page goes without a tailpiece',
      () {
    // Find a length whose last page has no room, by walking lengths until a
    // chapter's tailpiece goes missing; the page count must never change.
    var sawOmitted = false;
    for (var paragraphs = 20; paragraphs < 60 && !sawOmitted; paragraphs++) {
      final plain = layout(paragraphs: paragraphs);
      final book =
          layout(art: BookPageArt(tailpiece: tail), paragraphs: paragraphs);
      expect(book.pageCount, plain.pageCount,
          reason: 'a tailpiece never makes a page of its own');
      final count = book.pages
          .expand(artOn)
          .where((a) => a.slot == BookPageArtSlot.tailpiece)
          .length;
      if (count < 2) sawOmitted = true;
    }
    expect(sawOmitted, isTrue);
  });

  test('the corner setting survives the format\'s JSON, and is absent from '
      'old formats', () {
    final format = BookFormatPresets.paperback;
    final four = format.chapter.copyWith(cornerArt: CornerArtPlacement.allFour);
    expect(ChapterStyle.fromJson(four.toJson()).cornerArt,
        CornerArtPlacement.allFour);
    final old = Map<String, dynamic>.from(format.chapter.toJson())
      ..remove('cornerArt');
    expect(ChapterStyle.fromJson(old).cornerArt, CornerArtPlacement.topTwo);
  });

  test('a dressed book renders to the same PDF twice', () async {
    final assets = _assets();
    final book = layout(
      art: BookPageArt(corner: corner, tailpiece: tail),
      placement: CornerArtPlacement.allFour,
    );
    final first = await const BookPdfRenderer().render(book, assets);
    final second = await const BookPdfRenderer().render(book, assets);
    expect(String.fromCharCodes(first.take(5)), '%PDF-');
    expect(first, second);
    // The art is on the page: a dressed book is a bigger file than a plain one.
    final plain = await const BookPdfRenderer().render(layout(), assets);
    expect(first.length, greaterThan(plain.length));
  });
}
