import 'dart:typed_data';

import 'package:authoros_ui/book/book_fonts.dart';
import 'package:authoros_ui/book/book_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every family has a name, and a regular face to set a page in', () {
    final names = <String>{};
    for (final family in BookFontFamilyId.values) {
      expect(family.label, isNotEmpty);
      expect(names.add(family.label), isTrue, reason: family.label);
      expect(
        BookFontAssets.assetPaths[
            BookFontFace(family, BookFontStyleId.regular)],
        isNotNull,
        reason: '${family.label} needs a regular face',
      );
    }
  });

  test('every face is a TrueType file under assets/fonts, named once', () {
    final paths = BookFontAssets.assetPaths.values.toList();
    expect(paths.toSet(), hasLength(paths.length));
    for (final path in paths) {
      expect(path, matches(RegExp(r'^assets/fonts/[A-Za-z]+-\d00(-Italic)?\.ttf$')));
    }
  });

  test('a format names the families its pages are set in, and they survive '
      'its JSON', () {
    final format = BookFormatPresets.paperback;
    final set = format.copyWith(
      typography: format.typography.copyWith(
        bodyFamily: BookFontFamilyId.gentiumPlus,
        displayFamily: BookFontFamilyId.lancelot,
      ),
    );
    expect(BookFontAssets.familiesFor(set),
        {BookFontFamilyId.gentiumPlus, BookFontFamilyId.lancelot});
    final back = BookTypography.fromJson(set.typography.toJson());
    expect(back.bodyFamily, BookFontFamilyId.gentiumPlus);
    expect(back.displayFamily, BookFontFamilyId.lancelot);
  });

  test('Young Serif is a serif family with one style, its regular', () {
    expect(BookFontFamilyId.youngSerif.label, 'Young Serif');
    expect(BookFontFamilyId.youngSerif.isSerif, isTrue);
    expect(
        BookFontAssets.assetPaths.keys
            .where((face) => face.family == BookFontFamilyId.youngSerif)
            .map((face) => face.style),
        [BookFontStyleId.regular]);
    expect(
        BookFontAssets.assetPaths[const BookFontFace(
            BookFontFamilyId.youngSerif, BookFontStyleId.regular)],
        'assets/fonts/YoungSerif-400.ttf');
  });

  test('the first two families are always read', () {
    expect(BookFontAssets.defaultFamilies,
        {BookFontFamilyId.merriweather, BookFontFamilyId.inter});
    expect(BookFontAssets.defaultFamilies,
        contains(BookFontAssets.fallbackFace.family));
  });

  test('a style a family lacks stays in the family', () {
    ByteData blank() => ByteData(4);
    final assets = BookFontAssets({
      BookFontFace.merriweatherRegular: blank(),
      BookFontFace.merriweatherBold: blank(),
      const BookFontFace(BookFontFamilyId.radley, BookFontStyleId.regular):
          blank(),
      const BookFontFace(BookFontFamilyId.radley, BookFontStyleId.italic):
          blank(),
    });
    BookFontFace radley(BookFontStyleId style) =>
        BookFontFace(BookFontFamilyId.radley, style);
    expect(assets.nearest(radley(BookFontStyleId.italic)),
        radley(BookFontStyleId.italic));
    // No bold was drawn for Radley: its regular stands in, not Merriweather.
    expect(assets.nearest(radley(BookFontStyleId.bold)),
        radley(BookFontStyleId.regular));
    expect(assets.nearest(radley(BookFontStyleId.boldItalic)),
        radley(BookFontStyleId.regular));
    // A family not in hand at all is the fallback's.
    expect(
        assets.nearest(const BookFontFace(
            BookFontFamilyId.lancelot, BookFontStyleId.regular)),
        BookFontAssets.fallbackFace);
  });
}
