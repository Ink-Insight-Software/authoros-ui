import 'dart:io';
import 'dart:typed_data';

import 'package:authoros_ui/book/book_document.dart';
import 'package:authoros_ui/book/book_fonts.dart';
import 'package:authoros_ui/book/book_format.dart';
import 'package:authoros_ui/book/book_layout.dart';
import 'package:authoros_ui/book/book_markdown_exporter.dart';
import 'package:authoros_ui/book/book_pdf_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A document built by hand, as an application other than AOS-Write builds
/// one: no manuscript, no `BookDocumentBuilder`.
BookDocument _document() => const BookDocument(
      metadata: BookMetadata(title: 'The Reach', authorName: 'An Author'),
      frontMatter: [],
      backMatter: [],
      body: [
        BookChapterElement(BookChapterContent(
          id: 'identity',
          title: 'Civilisation identity',
          number: 1,
          scenes: [
            BookSceneContent(id: 'identity-1', title: '', paragraphs: [
              BookParagraph('Demonym: Reachfolk'),
              BookParagraph('Standing: a people in decline'),
            ]),
          ],
        )),
        BookChapterElement(BookChapterContent(
          id: 'languages',
          title: 'Languages',
          number: 2,
          scenes: [
            BookSceneContent(id: 'languages-1', title: '', paragraphs: [
              BookParagraph('Old Reach'),
            ]),
          ],
        )),
      ],
    );

/// Only the one face the fixture ships; the rest substitute to it.
BookFontAssets _assets() {
  final bytes = File('test/fonts/Merriweather-400.ttf').readAsBytesSync();
  return BookFontAssets({
    BookFontFace.merriweatherRegular: ByteData.sublistView(bytes),
  });
}

void main() {
  test('a hand-built document exports to Markdown', () {
    final markdown =
        const BookMarkdownExporter().export(document: _document());

    // The title is front matter's, and this document has none.
    expect(markdown, startsWith('## Chapter 1: Civilisation identity\n'));
    expect(markdown, contains('\nDemonym: Reachfolk\n'));
    expect(markdown, contains('\n## Chapter 2: Languages\n'));
    expect(
      markdown.indexOf('Civilisation identity'),
      lessThan(markdown.indexOf('Languages')),
    );
  });

  test('a hand-built document lays out and renders to the same PDF twice',
      () async {
    final assets = _assets();
    final book = BookLayoutEngine(PdfBookFontMetrics(assets))
        .layout(_document(), BookFormatPresets.paperback);
    expect(book.pages, isNotEmpty);

    final first = await const BookPdfRenderer().render(book, assets);
    final second = await const BookPdfRenderer().render(book, assets);

    expect(String.fromCharCodes(first.take(5)), '%PDF-');
    expect(first, second);
  });
}
