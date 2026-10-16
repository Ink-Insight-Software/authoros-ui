/// The Word exporter's output, held to the bytes `authoros_ui` 0.6.0 gave.
///
/// 0.6.1 writes the document part straight to text instead of building it
/// as an XML tree first, which made a whole world's Word file about three
/// times faster. It is meant to change nothing in the file, so these are
/// the 0.6.0 exporter's own bytes, by SHA-256, for documents that reach
/// every branch: each kind of front and back matter, parts with and
/// without subtitles, chapters with and without titles, numbers and
/// scenes, emphasis, empty and space-edged paragraphs, and every character
/// XML escapes or writes as a number.
library;

import 'package:authoros_ui/book/book_document.dart';
import 'package:authoros_ui/book/book_docx_exporter.dart';
import 'package:authoros_ui/book/book_format.dart';
import 'package:authoros_ui/book/inline_markup.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text with everything the escaping treats specially, one thing to a
/// line, so no line is escaped only because of another character in it.
const _awkward = [
  'Salt & iron',
  '<gold>',
  'a > b',
  '"never"',
  "'more'",
  'a ]]> end',
  'a ] and a ]] alone',
  'a tab\there',
  'a\nbreak',
  'a \r return',
  'control \u0001',
  'control \u0008',
  'control \u000b',
  'control \u000c',
  'control \u000e',
  'control \u001f',
  'control \u007f',
  'control \u0084',
  'control \u0086',
  'control \u009f',
  'next line \u0085 alone',
  'é, ß, 漢字, 🙂, \u00a0 \u2028 \u3000',
];

BookDocument _document(BookInlineMarkup markup) => BookDocument(
      metadata: const BookMetadata(
        title: 'The Reach & <Beyond>',
        subtitle: 'A "world" bible',
        authorName: 'An Author-Smith',
      ),
      inlineMarkup: markup,
      frontMatter: const [
        BookMatterPage(
          id: 'title',
          kind: BookSectionKind.titlePage,
          title: '',
          paragraphs: ['The Reach & <Beyond>', 'A "world" bible', ..._awkward],
          layout: BookMatterLayout.titlePage,
        ),
        BookMatterPage(
          id: 'copyright',
          kind: BookSectionKind.copyright,
          title: '',
          paragraphs: ['© 2026 An Author', 'All rights _reserved_.'],
          layout: BookMatterLayout.copyrightBlock,
        ),
        BookMatterPage(
          id: 'contents',
          kind: BookSectionKind.contents,
          title: 'Contents',
          paragraphs: [],
          layout: BookMatterLayout.contents,
        ),
        BookMatterPage(
          id: 'dedication',
          kind: BookSectionKind.dedication,
          title: '',
          paragraphs: ['For _you_ & yours.', ''],
          layout: BookMatterLayout.centredBlock,
        ),
      ],
      body: [
        const BookPartElement(BookPartHeading(
          id: 'part-1',
          title: 'Peoples & <Places>',
          subtitle: '  Who lives here  ',
          number: 1,
        )),
        BookChapterElement(BookChapterContent(
          id: 'one',
          title: 'Civilisation identity',
          number: 1,
          scenes: [
            BookSceneContent(id: 'one-1', title: '', paragraphs: [
              BookParagraph('Demonym: Reachfolk'),
              BookParagraph('Standing: a people _in decline_ and _more'),
              BookParagraph('  space-edged  '),
              BookParagraph(''),
            ]),
            BookSceneContent(id: 'one-2', title: '', paragraphs: [
              for (final line in _awkward) BookParagraph(line),
            ]),
            BookSceneContent(id: 'one-3', title: '', paragraphs: [
              BookParagraph('Marked', marked: [
                ProseSpan('Marked '),
                ProseSpan('by the editor', marks: {ProseMark.italic}),
                ProseSpan(''),
              ]),
            ]),
          ],
        )),
        const BookChapterElement(BookChapterContent(
          id: 'two',
          title: '   ',
          number: 2,
          scenes: [],
        )),
        const BookPartElement(BookPartHeading(
          id: 'part-2',
          title: 'Powers',
          subtitle: '',
          number: 2,
        )),
        for (var n = 3; n < 40; n++)
          BookChapterElement(BookChapterContent(
            id: 'c$n',
            title: 'Record $n',
            number: n,
            scenes: [
              BookSceneContent(id: 'c$n-1', title: '', paragraphs: [
                for (var p = 0; p < 12; p++)
                  BookParagraph('Field $p: value $n.$p, with _emphasis_ '
                      'and an & in it.'),
              ]),
            ],
          )),
      ],
      backMatter: const [
        BookMatterPage(
          id: 'about',
          kind: BookSectionKind.aboutAuthor,
          title: 'About the author',
          paragraphs: ['Lives _somewhere_.', ..._awkward],
          layout: BookMatterLayout.flowingText,
        ),
      ],
    );

String _hash({
  required DocxFlavour flavour,
  required BookInlineMarkup markup,
  BookFormat? format,
}) =>
    sha256
        .convert(const BookDocxExporter().export(
          document: _document(markup),
          flavour: flavour,
          modified: DateTime.utc(2026, 10, 16, 9, 30, 5),
          format: format,
        ))
        .toString();

/// What `authoros_ui` 0.6.0's exporter gave for each case, before the
/// document part was written straight to text.
const _before = {
  'submission, underscore emphasis':
      'e036513deca4a0de656d64f4ef0ab261edc6bc96ff34bbfe5b704c904274abee',
  'submission, no emphasis':
      'c72915f27638c398075a3c9ee18b21449b4f119bdb432dd6b621cc997769c233',
  'typeset paperback, underscore emphasis':
      '7fabd9f561e7ab9fb03c915072aebe6c3a5ea8ec5f02b2d2acbb73bae10280a4',
  'typeset default format, no emphasis':
      'a812937a66d344fa23c3c3f58f1705bd9d09d71828849faab31cde8594376a2b',
};

void main() {
  final cases = {
    'submission, underscore emphasis': () => _hash(
          flavour: DocxFlavour.submission,
          markup: BookInlineMarkup.underscoreItalic,
        ),
    'submission, no emphasis': () => _hash(
          flavour: DocxFlavour.submission,
          markup: BookInlineMarkup.none,
        ),
    'typeset paperback, underscore emphasis': () => _hash(
          flavour: DocxFlavour.typeset,
          markup: BookInlineMarkup.underscoreItalic,
          format: BookFormatPresets.paperback,
        ),
    'typeset default format, no emphasis': () => _hash(
          flavour: DocxFlavour.typeset,
          markup: BookInlineMarkup.none,
        ),
  };

  for (final MapEntry(key: name, value: hash) in cases.entries) {
    test('$name: the same bytes 0.6.0 wrote', () {
      expect(hash(), _before[name]);
    });
  }
}
