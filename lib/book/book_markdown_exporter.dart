/// Markdown, the format a manuscript survives in.
///
/// Like EPUB, DOCX and plain text this consumes a [BookDocument] and never a
/// `PaginatedBook`: Markdown has no pages, so inheriting a print layout's
/// breaks would be nonsense, and the fidelity test fails the build if this file
/// reaches for the layout engine.
///
/// ## Why a book needs this when it already has plain text
///
/// Plain text is the format nothing can refuse; Markdown is the format that
/// **keeps the structure while staying readable**. A `.txt` export loses which
/// line was a chapter heading and which was a paragraph, and an author who
/// pastes one into anything gets a wall. Markdown keeps the headings, the
/// emphasis and the scene breaks in characters a person can read, and every
/// static-site generator, note-taking app, wiki and publishing pipeline in
/// existence takes it as input.
///
/// It is also the one export **AuthorOS can read back**. `lib/core/import/`
/// reads Markdown, and `book_markdown_test.dart` runs a book out through this
/// and in through that — so the two halves cannot drift without the build
/// saying so.
///
/// ## What it deliberately does not do
///
/// **No table of contents.** Every tool that renders Markdown builds its own
/// from the headings, and a hand-written list of chapter names is a chapter's
/// worth of prose the moment the file is read back in.
///
/// **No underline and no highlight.** Markdown has neither. They are dropped
/// rather than approximated with raw HTML, which the importer would read as
/// literal text and which half the renderers in the world strip anyway. Bold,
/// italic, strikethrough and links all survive, which is more than the printed
/// book itself can set — `italicOnly` in `inline_markup.dart` says why.
library;

import 'book_document.dart';
import 'book_format.dart';
import 'book_text_exporter.dart';
import 'inline_markup.dart';

/// Renders a book as Markdown.
class BookMarkdownExporter {
  const BookMarkdownExporter();

  /// `\n` throughout, for the reason `BookTextExporter` gives: it is the only
  /// choice that keeps the export byte-identical across every platform
  /// AuthorOS runs on.
  static const _newline = '\n';

  /// The scene break, always, whatever the book is set with.
  ///
  /// A thematic break is what Markdown has for *the scene changes here*, and
  /// it is what the importer reads back. The book's own glyph — an asterism, a
  /// swelled rule, a blank line — is a typographic decision that belongs to
  /// the printed page, and a **blank line** in particular would be no break at
  /// all here: it is already what separates two paragraphs.
  static const _sceneBreak = '***';

  /// [style] is shared with the plain text exporter rather than duplicated.
  /// The question it answers — *the whole book, or the prose on its own* — is
  /// the same question in both formats, and two enums would be two answers to
  /// it.
  String export({
    required BookDocument document,
    TextExportStyle style = TextExportStyle.readable,
    BookFormat? format,
  }) {
    final readable = style == TextExportStyle.readable;
    final markup = document.inlineMarkup;

    // Chapters sit one level below whatever contains them, so a book with
    // parts sets its chapters a level deeper. This is what every Markdown
    // pipeline expects, and it is also what the importer reads: the shallowest
    // level used more than once is its chapter level.
    final hasParts = document.body.any((element) => element is BookPartElement);
    final chapterLevel = hasParts ? 3 : 2;

    final blocks = <String>[];

    if (readable) {
      for (final page in document.frontMatter) {
        blocks.addAll(_matter(page, document, markup));
      }
    }

    for (final element in document.body) {
      switch (element) {
        case BookPartElement(:final heading):
          if (!readable) break;
          blocks.add(_heading(2, heading.displayTitle, markup));
          final subtitle = heading.subtitle.trim();
          if (subtitle.isNotEmpty) blocks.add(_prose(subtitle, markup));
        case BookChapterElement(:final chapter):
          blocks.addAll(
            _chapter(chapter, readable, chapterLevel, markup, format),
          );
      }
    }

    if (readable) {
      for (final page in document.backMatter) {
        blocks.addAll(_matter(page, document, markup));
      }
    }

    final body = blocks.where((block) => block.isNotEmpty).join(
          '$_newline$_newline',
        );
    return body.isEmpty ? '' : '$body$_newline';
  }

  Iterable<String> _chapter(
    BookChapterContent chapter,
    bool readable,
    int level,
    BookInlineMarkup markup,
    BookFormat? format,
  ) sync* {
    if (readable) {
      yield _heading(level, _chapterHeading(chapter, format), markup);
    }

    for (var s = 0; s < chapter.scenes.length; s++) {
      if (s > 0 && readable) yield _sceneBreak;
      for (final paragraph in chapter.scenes[s].paragraphs) {
        final line = _paragraph(paragraph, markup);
        if (line.trim().isNotEmpty) yield line;
      }
    }
  }

  /// One matter page.
  ///
  /// The title page becomes the file's single level-one heading, which is what
  /// lets the importer read it as the manuscript's title rather than as a
  /// chapter — and what every Markdown renderer in existence treats as the
  /// document's title. Everything else is a level-two section beside the
  /// chapters, which is what it is.
  Iterable<String> _matter(
    BookMatterPage page,
    BookDocument document,
    BookInlineMarkup markup,
  ) sync* {
    // Three pages exist for the printed page and have nothing to say here.
    //
    // A **contents** page is filled in during pagination from page numbers
    // this format does not have, and every tool that renders Markdown builds
    // its own from the headings. A **half title** is the title again, alone,
    // because a printer expects it. A **plate** is a picture, and this export
    // writes no files beside itself for one to point at.
    if (page.layout == BookMatterLayout.contents) return;
    if (page.kind == BookSectionKind.contents) return;
    if (page.kind == BookSectionKind.halfTitle) return;
    if (page.kind == BookSectionKind.plate) return;

    if (page.kind == BookSectionKind.titlePage) {
      final title = document.metadata.title.trim();
      if (title.isNotEmpty) yield _heading(1, title, markup);
      for (final paragraph in page.paragraphs) {
        final line = paragraph.trim();
        // The title page is generated from the metadata, so its first line is
        // the title — which the heading above has just said. Printing it twice
        // would be the file introducing itself and then doing it again.
        if (line.isEmpty || line == title) continue;
        yield _prose(line, markup);
      }
      return;
    }

    // A generated page — the copyright — carries no title of its own, so the
    // section's name is used. A section an author wrote and named keeps their
    // name for it.
    final title =
        page.title.trim().isEmpty ? page.kind.label : page.title.trim();
    yield _heading(2, title, markup);

    for (final paragraph in page.paragraphs) {
      final line = _prose(paragraph.trim(), markup);
      if (line.isNotEmpty) yield line;
    }
  }

  /// `## Chapter One: The Crossing`, escaped so its own words cannot reopen
  /// the syntax that introduces it.
  String _heading(int level, String text, BookInlineMarkup markup) =>
      // No line-start escaping: the hashes are already there, so the author's
      // words are not at the start of the line and a `-` among them is a
      // hyphen like any other.
      '${'#' * level} ${_spans(parseProse(text, markup))}';

  String _paragraph(BookParagraph paragraph, BookInlineMarkup markup) =>
      escapeMarkdownLineStart(_spans(paragraph.resolve(markup)));

  /// A bare string as a Markdown paragraph, with the author's convention
  /// resolved.
  ///
  /// Matter pages hold plain strings rather than [BookParagraph], so they go
  /// through the same span path to get the same escaping and the same reading
  /// of an underscore.
  String _prose(String text, BookInlineMarkup markup) =>
      escapeMarkdownLineStart(_spans(parseProse(text, markup)));

  /// The spans of one line, joined, with no line-start escaping.
  ///
  /// The line-start rule belongs to a **line**, not to a run inside one: a
  /// paragraph whose second span happens to begin with a hyphen is not a list
  /// item, and escaping it there would put a backslash in the middle of a
  /// sentence. So the runs are escaped for the characters that mean something
  /// anywhere, and whoever assembles the line decides about its first one.
  static String _spans(List<ProseSpan> spans) =>
      [for (final span in spans) _span(span)].join();

  /// One run of text, with its marks as Markdown.
  ///
  /// Order matters: the link wraps the emphasis, because `[**a**](x)` renders
  /// and `**[a](x)**` renders too but reads worse in the source. Bold outside
  /// italic is the conventional nesting and the one the importer's own
  /// delimiter table looks for first.
  static String _span(ProseSpan span) {
    final text = escapeMarkdownProse(span.text);
    if (text.isEmpty) return '';

    var marked = text;
    if (span.marks.contains(ProseMark.strikethrough)) marked = '~~$marked~~';
    if (span.marks.contains(ProseMark.italic)) marked = '*$marked*';
    if (span.marks.contains(ProseMark.bold)) marked = '**$marked**';

    if (span.isLink) {
      // The target is not escaped as prose — it is a URL, and a backslash in
      // one is a character of the address rather than an escape. Only the
      // parenthesis that would end the link early is dealt with, by using the
      // angle-bracket form Markdown provides for exactly this.
      final href = span.href!;
      final target = href.contains(RegExp(r'[\s()]')) ? '<$href>' : href;
      return '[$marked]($target)';
    }
    return marked;
  }

  /// `Chapter One: The Crossing`, or as much of it as the book has.
  ///
  /// The same shape the plain text exporter produces, deliberately: two
  /// exports of one book that named its chapters differently would be two
  /// answers to what a chapter is called.
  String _chapterHeading(BookChapterContent chapter, BookFormat? format) {
    final chapterStyle = format?.chapter ?? const ChapterStyle();
    final number = chapterNumberLabel(
      chapter.number,
      style: chapterStyle.numberStyle,
      prefix: chapterStyle.numberPrefix,
    );
    final title = chapter.title.trim();
    if (number.isEmpty) {
      return title.isEmpty ? 'Chapter ${chapter.number}' : title;
    }
    return title.isEmpty ? number : '$number: $title';
  }
}

/// An author's own characters, so Markdown cannot reinterpret them.
///
/// **Prose-aware, and that is the difference from the escaping in
/// `continuity_report.dart`.** That one escapes every special character
/// wherever it falls, which is right for a short fragment dropped into a table
/// cell. This is a whole book, meant to be read as text as well as rendered,
/// and escaping every `#` and `-` mid-sentence would litter an author's prose
/// with backslashes to prevent something that cannot happen there.
///
/// So the rule follows CommonMark and is split in two. This half is the
/// characters that mean something **anywhere**, and it is applied to each run
/// of text on its own.
String escapeMarkdownProse(String text) {
  if (text.isEmpty) return text;
  return text
      // First, always: a backslash the author typed must survive as one, and
      // escaping it after the others would double their backslashes.
      .replaceAll(r'\', r'\\')
      .replaceAll('*', r'\*')
      .replaceAll('_', r'\_')
      .replaceAll('`', r'\`')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll('<', r'\<');
}

/// The other half: the characters that mean something only at the start of a
/// line.
///
/// A hash is a heading, a hyphen or a plus is a list item, an angle bracket is
/// a quote, and `1.` is a numbered list — but only there. Mid-sentence every
/// one of them is an ordinary character, and this is applied once to a
/// finished line rather than to the runs inside it.
String escapeMarkdownLineStart(String line) => line.replaceFirstMapped(
      RegExp(r'^(\s*)([#>+-]|\d+[.)])'),
      (match) => '${match[1]}\\${match[2]}',
    );
