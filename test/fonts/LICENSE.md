# Bundled typefaces

_Only `Merriweather-400.ttf` is copied here, as the fixture `book_export_test.dart` lays a book out and renders it with. Applications ship the faces themselves; see the README._

Five families, all under the SIL Open Font License 1.1: Merriweather and Inter
in four weights each, Playfair Display in two, Cormorant Garamond in four,
Open Sans in three.

| File | Family | Weight | Style |
|---|---|---|---|
| `Merriweather-400.ttf` | Merriweather | 400 | upright |
| `Merriweather-700.ttf` | Merriweather | 700 | upright |
| `Merriweather-400-Italic.ttf` | Merriweather | 400 | italic |
| `Merriweather-700-Italic.ttf` | Merriweather | 700 | italic |
| `Inter-400.ttf` | Inter | 400 | upright |
| `Inter-700.ttf` | Inter | 700 | upright |
| `Inter-400-Italic.ttf` | Inter | 400 | italic |
| `Inter-700-Italic.ttf` | Inter | 700 | italic |
| `PlayfairDisplay-400.ttf` | Playfair Display | 400 | upright |
| `PlayfairDisplay-700.ttf` | Playfair Display | 700 | upright |
| `CormorantGaramond-400.ttf` | Cormorant Garamond | 400 | upright |
| `CormorantGaramond-500.ttf` | Cormorant Garamond | 500 | upright |
| `CormorantGaramond-600.ttf` | Cormorant Garamond | 600 | upright |
| `CormorantGaramond-500-Italic.ttf` | Cormorant Garamond | 500 | italic |
| `OpenSans-400.ttf` | Open Sans | 400 | upright |
| `OpenSans-600.ttf` | Open Sans | 600 | upright |
| `OpenSans-700.ttf` | Open Sans | 700 | upright |

**Merriweather** is by Sorkin Type (Eben Sorkin), **Inter** is by Rasmus
Andersson, and **Playfair Display** is by Claus Eggers Sørensen. All three are
published under the SIL Open Font License, Version 1.1, which permits bundling
and redistribution inside an application.

**Cormorant Garamond** is by Christian Thalmann (Catharsis Fonts), also under
the OFL 1.1. Its four files were added on September 25, 2026 as Brass's display
face, to match the owner's Dashboard mockup. They are the static TrueType
files Google Fonts serves (`fonts.googleapis.com/css2?family=Cormorant+Garamond`),
saved unmodified.

**Open Sans** is by Steve Matteson (The Open Sans Project Authors), under the
OFL 1.1. Its three files were added on September 26, 2026 as the Azure theme's
face, for the professional Dashboard. They are the unmodified static TrueType
files `OpenSans-Regular`, `-SemiBold` and `-Bold` from
`github.com/googlefonts/opensans`, renamed by weight.

## Provenance

Every file here is an **unmodified** static release from Google Fonts,
redistributed by the `@expo-google-fonts/merriweather`,
`@expo-google-fonts/inter` and `@expo-google-fonts/playfair-display` packages.
Nothing was subsetted, re-encoded, renamed or otherwise altered.

That matters legally as well as technically. Merriweather is licensed **with the
Reserved Font Name "Merriweather"** and Playfair Display **with "Playfair
Display"**, and the OFL defines a Modified Version as
any derivative made *"by adding to, deleting, or substituting … any of the
components of the Original Version, by changing formats or by porting the Font
Software to a new environment"* — which a subset or a WOFF2-to-TrueType
conversion plainly is, and which clause 3 then forbids from carrying the
reserved name. Shipping the originals keeps that question from arising at all.

It also happens to give the better result: each italic carries the full glyph
set rather than a Latin subset, so an accented or Central European character
inside an emphasised phrase renders instead of falling back.

The weight class, units per em, ascent and descent of each italic match its
upright exactly, which is what lets an emphasised run sit on the same baseline
with the same leading as the prose around it.

## Size

Playfair Display adds roughly 390 KB for the pair. Unlike the italics below it
is declared as a `fonts:` family rather than loaded on demand, because a theme's
typography has to be resolved for the first frame that theme paints; only the
Amethyst theme asks for it.

The four italics add roughly 2.8 MB, of which the two Merriweather faces are
most — they carry more glyphs than the uprights they accompany, which is the
price of shipping them unmodified.

Nothing is paid for it until Book Studio opens. `BookFontAssets.load()` is the
only thing that touches these files, it caches for the session, and nothing on
the path to first paint calls it.

## SIL Open Font License 1.1

    Copyright (c) Sorkin Type Co (Merriweather)
    Copyright (c) The Inter Project Authors (Inter)
    Copyright 2017 The Playfair Display Project Authors (Playfair Display)
    Copyright 2015 The Cormorant Project Authors (Cormorant Garamond)

    This Font Software is licensed under the SIL Open Font License, Version 1.1.

    PREAMBLE

    The goals of the Open Font License (OFL) are to stimulate worldwide
    development of collaborative font projects, to support the font creation
    efforts of academic and linguistic communities, and to provide a free and
    open framework in which fonts may be shared and improved in partnership with
    others.

    The OFL allows the licensed fonts to be used, studied, modified and
    redistributed freely as long as they are not sold by themselves. The fonts,
    including any derivative works, can be bundled, embedded, redistributed
    and/or sold with any software provided that any reserved names are not used
    by derivative works. The fonts and derivatives, however, cannot be released
    under any other type of license. The requirement for fonts to remain under
    this license does not apply to any document created using the fonts or their
    derivatives.

    PERMISSION & CONDITIONS

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of the Font Software, to use, study, copy, merge, embed, modify,
    redistribute, and sell modified and unmodified copies of the Font Software,
    subject to the following conditions:

    1) Neither the Font Software nor any of its individual components, in
    Original or Modified Versions, may be sold by itself.

    2) Original or Modified Versions of the Font Software may be bundled,
    redistributed and/or sold with any software, provided that each copy
    contains the above copyright notice and this license. These can be included
    either as stand-alone text files, human-readable headers or in the
    appropriate machine-readable metadata fields within text or binary files as
    long as those fields can be easily viewed by the user.

    3) No Modified Version of the Font Software may use the Reserved Font
    Name(s) unless explicit written permission is granted by the corresponding
    Copyright Holder. This restriction only applies to the primary font name as
    presented to the users.

    4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
    Software shall not be used to promote, endorse or advertise any Modified
    Version, except to acknowledge the contribution(s) of the Copyright
    Holder(s) and the Author(s) or with their explicit written permission.

    5) The Font Software, modified or unmodified, in part or in whole, must be
    distributed entirely under this license, and must not be distributed under
    any other license. The requirement for fonts to remain under this license
    does not apply to any document created using the Font Software.

    TERMINATION

    This license becomes null and void if any of the above conditions are not
    met.

    DISCLAIMER

    THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT,
    TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE
    FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL,
    INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT
    SOFTWARE.
