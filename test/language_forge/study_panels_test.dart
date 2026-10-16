/// The Linguist's Study's panels, mounted on their own over a snapshot and a
/// working layer kept in memory: the host contract AuthorOS Write and AOS
/// Worldsmith both meet. The panels came from AuthorOS Write in 0.7.0, where
/// its own suites still drive them inside its Study.
library;

import 'package:authoros_core/connected_domain.dart';
import 'package:authoros_core/language_forge/grammar.dart';
import 'package:authoros_core/language_forge/language_forge_workspace.dart';
import 'package:authoros_core/language_forge/lexicon.dart';
import 'package:authoros_core/language_forge/linguists_study_read_model.dart';
import 'package:authoros_core/language_forge/sound_change.dart';
import 'package:authoros_ui/language_forge/evolution_panels.dart';
import 'package:authoros_ui/language_forge/grammar_panel.dart';
import 'package:authoros_ui/language_forge/study_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _project = 'project-1';
final _at = DateTime.utc(2026, 10, 16);

AuthorRecord _record(
  String id,
  String typeId,
  String title, [
  Map<String, Object?> fields = const {},
]) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: _project,
      projectId: _project,
      title: title,
      fields: fields,
      createdAt: _at,
      updatedAt: _at,
    );

RecordLink _link(String id, String from, String to, String typeId) =>
    RecordLink(
      id: id,
      sourceId: from,
      targetId: to,
      typeId: typeId,
      scopeId: _project,
      createdAt: _at,
      updatedAt: _at,
    );

final _elvish = _record('lang-elvish', 'language', 'Elvish');
final _coastal = _record('dia-coastal', 'dialect', 'Coastal', {
  'parentLanguage': 'lang-elvish',
});
final _aran = _record('lex-aran', 'lexicon-entry', 'aran', {
  'term': 'aran',
  'gloss': 'sun',
  'language': 'lang-elvish',
  'wordClass': 'Noun',
});
final _tele = _record('lex-tele', 'lexicon-entry', 'tele', {
  'term': 'tele',
  'gloss': 'to walk',
  'language': 'lang-elvish',
  'wordClass': 'Verb',
});

Future<LinguistsStudySnapshot> _snapshot(
  List<AuthorRecord> records, [
  List<RecordLink> links = const [],
]) =>
    LinguistsStudyReadModel(
      projectId: _project,
      recordsByProject: (_) async => records,
      linksByScope: (_) async => links,
    ).load();

void main() {
  late LanguageForgeWorkspace saved;
  late List<String> opened;
  late List<LexiconEntryDraft> drafts;

  setUp(() {
    saved = LanguageForgeWorkspace.empty;
    opened = [];
    drafts = [];
  });

  /// Mounts [panel] for [languageId], with a host that keeps what is
  /// committed and hands it back to the panel, as both applications do.
  Future<void> mount(
    WidgetTester tester,
    LinguistsStudySnapshot snapshot,
    Widget Function(StudyContext study) panel, {
    String languageId = 'lang-elvish',
    String recordHome = 'the Codex',
  }) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => panel(
              StudyContext(
                snapshot: snapshot,
                workspace: saved,
                languageId: languageId,
                canEdit: true,
                commit: (next) async {
                  setState(() => saved = next);
                  return true;
                },
                openRecord: opened.add,
                saveEntry: (draft) async => drafts.add(draft),
                recordHome: recordHome,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('translation is complete only when every word is defined',
      (tester) async {
    final snapshot = await _snapshot([_elvish, _aran, _tele]);
    await mount(tester, snapshot, (study) => TranslationPanel(study: study));

    await tester.enterText(
        find.byKey(const Key('translation-phrase')), 'aran tele');
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    expect(find.byKey(const Key('translation-undefined')), findsNothing);

    await tester.enterText(
        find.byKey(const Key('translation-phrase')), 'aran vorn');
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    expect(find.textContaining('vorn'), findsWidgets);
    expect(find.byKey(const Key('translation-undefined')), findsOneWidget);
  });

  testWidgets('script letters transliterate, name a gap, and are saved',
      (tester) async {
    final script = _record('ws-runes', 'writing-system', 'Runes');
    final snapshot = await _snapshot([_elvish, script]);
    await mount(tester, snapshot, (study) => ScriptPanel(study: study));

    await tester.enterText(
        find.byKey(const Key('script-lines')), 'th = ᚦ\na = U+E000 # anna');
    await tester.enterText(
        find.byKey(const Key('script-preview-input')), 'thax');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('script-preview'))).data,
        'ᚦ\u{E000}x');
    expect(find.byKey(const Key('script-unmapped')), findsOneWidget);

    await tester.tap(find.byKey(const Key('script-save')));
    await tester.pumpAndSettle();
    final mapping = saved.scripts['ws-runes']!;
    expect(mapping.glyphs.map((glyph) => glyph.romanised), ['th', 'a']);
    expect(mapping.glyphs.last.name, 'anna');
  });

  testWidgets('a host names where its records are made', (tester) async {
    final snapshot = await _snapshot([_elvish]);
    await mount(
      tester,
      snapshot,
      (study) => ScriptPanel(study: study),
      recordHome: "the Linguist's Study",
    );
    expect(
        find.textContaining("Writing System record in the Linguist's Study"),
        findsOneWidget);
    expect(find.textContaining('Codex'), findsNothing);
  });

  testWidgets('a grammar rule takes a formula, previewed and saved',
      (tester) async {
    final rule = _record('rule-plural', 'grammar-rule', 'Plurals', {
      'language': 'lang-elvish',
      'statement': 'Nouns take -i.',
    });
    final snapshot = await _snapshot([_elvish, _aran, _tele, rule]);
    await mount(tester, snapshot, (study) => GrammarPanel(study: study));

    await tester.tap(find.byKey(const Key('grammar-rule-rule-plural')));
    await tester.pumpAndSettle();
    expect(find.text('Nouns take -i.'), findsOneWidget);
    await tester.tap(find.text('Inflection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('grammar-label')), 'Plural');
    await tester.enterText(find.byKey(const Key('grammar-abbreviation')), 'pl');
    await tester.enterText(find.byKey(const Key('grammar-branches')), '* => +i');
    await tester.pumpAndSettle();
    expect(find.text('aran → arani'), findsOneWidget);

    await tester.tap(find.byKey(const Key('grammar-save')));
    await tester.pumpAndSettle();
    final formula = saved.grammar['rule-plural']! as InflectionFormula;
    expect(formula.derive('aran'), 'arani');

    await tester.tap(find.byKey(const Key('grammar-open-record')));
    expect(opened, ['rule-plural']);
  });

  testWidgets('sound change carries words into a dialect and accepts one',
      (tester) async {
    final snapshot = await _snapshot([_elvish, _coastal, _aran, _tele]);
    await mount(tester, snapshot, (study) => SoundChangePanel(study: study));

    await tester.tap(find.byKey(const Key('sound-change-new')));
    await tester.pumpAndSettle();
    expect(saved.soundChanges.single.toLanguageId, 'dia-coastal');

    await tester.enterText(
        find.byKey(const Key('sound-change-rules')), 'a > e / _r\nt > d');
    await tester.pumpAndSettle();
    expect(find.text('aran → eran'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound-change-save')));
    await tester.pumpAndSettle();
    expect(saved.soundChanges.single.rules, ['a > e / _r', 't > d']);

    await tester.tap(find.byKey(const Key('sound-change-accept-lex-aran')));
    await tester.pumpAndSettle();
    expect(drafts.single.term, 'eran');
    expect(drafts.single.languageId, 'dia-coastal');
    expect(drafts.single.originRecordId, 'lex-aran');
  });

  testWidgets('a set saved before is read back', (tester) async {
    saved = LanguageForgeWorkspace.empty.withSoundChanges(const SoundChangeSet(
      id: 's',
      name: 'Coastal shift',
      fromLanguageId: 'lang-elvish',
      toLanguageId: 'dia-coastal',
      rules: ['a > e'],
    ));
    final snapshot = await _snapshot([_elvish, _coastal, _aran]);
    await mount(tester, snapshot, (study) => SoundChangePanel(study: study));
    expect(find.byKey(const Key('sound-change-set-s')), findsOneWidget);
  });

  testWidgets('the family tree is drawn from the links', (tester) async {
    final eran = _record('lex-eran', 'lexicon-entry', 'eran', {
      'term': 'eran',
      'gloss': 'sun',
      'language': 'dia-coastal',
    });
    final snapshot = await _snapshot(
      [_elvish, _coastal, _aran, eran],
      [_link('origin', 'lex-eran', 'lex-aran', 'originatedFrom')],
    );
    await mount(tester, snapshot, (study) => FamilyPanel(study: study));
    expect(find.byKey(const Key('family-tree')), findsOneWidget);
    expect(find.text('Coastal — dialect'), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-word-lex-aran')));
    await tester.pumpAndSettle();
    expect(find.text('eran (Coastal)'), findsOneWidget);
  });

  testWidgets('the dictionary finds a word by its meaning', (tester) async {
    final snapshot = await _snapshot([_elvish, _aran, _tele]);
    await mount(tester, snapshot, (study) => DictionaryPanel(study: study));
    await tester.enterText(find.byKey(const Key('dictionary-search')), 'sun');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dictionary-entry-lex-aran')), findsOneWidget);
    expect(find.byKey(const Key('dictionary-entry-lex-tele')), findsNothing);
    await tester.tap(find.byKey(const Key('dictionary-entry-lex-aran')));
    expect(opened, ['lex-aran']);
  });
}
