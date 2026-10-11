import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:authoros_ui/book/book_document.dart';
import 'package:authoros_ui/book/book_docx_exporter.dart';
import 'package:authoros_ui/book/book_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// A document built by hand, as an application without a manuscript builds
/// one: a title page, a part, two chapters (one of two scenes), emphasis, and
/// prose with the characters XML reserves.
///
/// AOS-Write's own suite (`book_docx_test.dart` there) covers the exporter
/// against a manuscript built by `BookDocumentBuilder`; this covers what a
/// host that builds the document itself relies on.
BookDocument _document() => const BookDocument(
      metadata: BookMetadata(title: 'The Reach', authorName: 'An Author'),
      inlineMarkup: BookInlineMarkup.underscoreItalic,
      frontMatter: [
        BookMatterPage(
          id: 'title',
          kind: BookSectionKind.titlePage,
          title: '',
          paragraphs: ['The Reach', 'A world bible', 'An Author'],
          layout: BookMatterLayout.titlePage,
        ),
      ],
      backMatter: [],
      body: [
        BookPartElement(BookPartHeading(
          id: 'part-1',
          title: 'Peoples',
          subtitle: 'Who lives here',
          number: 1,
        )),
        BookChapterElement(BookChapterContent(
          id: 'identity',
          title: 'Civilisation identity',
          number: 1,
          scenes: [
            BookSceneContent(id: 'identity-1', title: '', paragraphs: [
              BookParagraph('Demonym: Reachfolk'),
              BookParagraph('Standing: a people _in decline_'),
            ]),
            BookSceneContent(id: 'identity-2', title: '', paragraphs: [
              BookParagraph('Salt & iron, "never" <gold>.'),
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

Uint8List _export({DocxFlavour flavour = DocxFlavour.typeset}) =>
    const BookDocxExporter().export(
      document: _document(),
      flavour: flavour,
      modified: DateTime.utc(2026, 10, 11),
      format: BookFormatPresets.paperback,
    );

String _part(Archive archive, String name) {
  final file = archive.find(name);
  expect(file, isNotNull, reason: '$name is missing from the package');
  return utf8.decode(file!.readBytes()!);
}

/// Every `w:p` in reading order, as (style id, text).
List<({String style, String text})> _paragraphs(XmlDocument document) => [
      for (final p in document.findAllElements('w:p'))
        (
          style: p
                  .findAllElements('w:pStyle')
                  .firstOrNull
                  ?.getAttribute('w:val') ??
              '',
          text: p.findAllElements('w:t').map((t) => t.innerText).join(),
        ),
    ];

void main() {
  for (final flavour in DocxFlavour.values) {
    group('${flavour.name}:', () {
      test('the zip holds the parts Word needs, each well-formed XML', () {
        final archive = ZipDecoder().decodeBytes(_export(flavour: flavour));

        for (final name in const [
          '[Content_Types].xml',
          '_rels/.rels',
          'word/_rels/document.xml.rels',
          'word/document.xml',
          'word/styles.xml',
        ]) {
          expect(archive.find(name), isNotNull, reason: name);
        }
        for (final file in archive.files) {
          expect(() => XmlDocument.parse(_part(archive, file.name)),
              returnsNormally,
              reason: '${file.name} is not well-formed');
        }
      });

      test('the same document exports the same bytes twice', () {
        expect(_export(flavour: flavour), _export(flavour: flavour));
      });
    });
  }

  test('the text reads back in book order, emphasis and all', () {
    final archive = ZipDecoder().decodeBytes(_export());
    final document = XmlDocument.parse(_part(archive, 'word/document.xml'));
    final paragraphs = _paragraphs(document);
    final text = [for (final p in paragraphs) p.text];

    // The title page, then the part, then the chapters in order.
    expect(text.take(3), ['The Reach', 'A world bible', 'An Author']);
    expect(paragraphs.first.style, 'BookTitle');
    expect(
        text,
        containsAllInOrder(<String>[
          'Peoples',
          'Who lives here',
          'Civilisation identity',
          'Demonym: Reachfolk',
          'Standing: a people in decline',
          'Salt & iron, "never" <gold>.',
          'Languages',
          'Old Reach',
        ]));

    // Chapter titles are Heading 1, so Word's navigation pane lists them.
    expect(
      [
        for (final p in paragraphs)
          if (p.style == 'Heading1') p.text
      ],
      ['Civilisation identity', 'Languages'],
    );
    expect(
        paragraphs.where((p) => p.style == 'PartTitle').single.text, 'Peoples');

    // Two scenes, one break between them.
    expect(paragraphs.where((p) => p.style == 'SceneBreak'), hasLength(1));

    // The underscores are the author's convention, read as italic rather than
    // printed: the italic run is exactly the marked words.
    final italic = document
        .findAllElements('w:r')
        .where((r) => r.findAllElements('w:i').isNotEmpty)
        .map((r) => r.findAllElements('w:t').map((t) => t.innerText).join())
        .toList();
    expect(italic, ['in decline']);
  });

  test('the title and author are the document properties', () {
    final core = XmlDocument.parse(
        _part(ZipDecoder().decodeBytes(_export()), 'docProps/core.xml'));
    expect(core.findAllElements('dc:title').single.innerText, 'The Reach');
    expect(core.findAllElements('dc:creator').single.innerText, 'An Author');
  });
}
