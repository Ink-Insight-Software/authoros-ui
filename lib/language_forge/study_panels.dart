/// Language Forge Phase 2 — the Study's panels: Sound, Word Forge,
/// Dictionary, Translation and Script.
///
/// Each panel is a surface over an engine that already exists and is already
/// tested on its own; nothing here decides what a word is, what a phrase means
/// or what a glyph maps to. A panel reads the [StudyContext] the Study hands
/// it, and changes the working layer only through [StudyContext.commit], which
/// is the one path to the store and the one place a refusal is explained.
///
/// **Shared since authoros_ui 0.7.0** (October 16, 2026). These panels were
/// AuthorOS Write's (`lib/expansions/language_forge/`) and moved here
/// unchanged but for their imports and [StudyContext.recordHome], so AOS
/// Worldsmith's Linguist's Study shows the same panels over the same core
/// models rather than a second copy of them. A host hands them a
/// [StudyContext]; where the working layer is kept, and how a refusal to save
/// it is explained, stay the host's.
library;

import 'package:authoros_core/connected_domain.dart';
import 'package:authoros_core/language_forge/guided_build.dart';
import 'package:authoros_core/language_forge/language_forge_workspace.dart';
import 'package:authoros_core/language_forge/lexicon.dart';
import 'package:authoros_core/language_forge/linguists_study_read_model.dart';
import 'package:authoros_core/language_forge/phonology.dart';
import 'package:authoros_core/language_forge/phonology_text.dart';
import 'package:authoros_core/language_forge/script_mapping.dart';
import 'package:authoros_core/language_forge/translation_workbench.dart';
import 'package:authoros_core/language_forge/word_forge.dart';
import 'package:authoros_core/procedural/generation_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What every panel is given.
class StudyContext {
  const StudyContext({
    required this.snapshot,
    required this.workspace,
    required this.languageId,
    required this.canEdit,
    required this.commit,
    required this.openRecord,
    this.openPanel,
    this.saveEntry,
    this.recordHome = 'the Codex',
  });

  final LinguistsStudySnapshot snapshot;
  final LanguageForgeWorkspace workspace;

  /// The `language` or `dialect` record the author has selected.
  final String languageId;

  /// Whether the room is open. Reading never depends on it.
  final bool canEdit;

  /// Saves a new working layer. False when it was refused; the Study has
  /// already told the author why.
  final Future<bool> Function(LanguageForgeWorkspace next) commit;

  final ValueChanged<String> openRecord;

  /// Moves the Study to another panel, by its slug. Null where the panel is
  /// shown on its own.
  final ValueChanged<String>? openPanel;

  /// Makes a Lexicon Entry through the host's own create path (AuthorOS
  /// Write's Codex, Worldsmith's record service). Null where the host has
  /// none.
  final Future<void> Function(LexiconEntryDraft draft)? saveEntry;

  /// Where the host's author makes a language record, as a panel names it in
  /// a sentence: *Create a Writing System record in the Codex*. AuthorOS
  /// Write's is the default; AOS Worldsmith names its room.
  final String recordHome;

  AuthorRecord? get language => snapshot.languageById(languageId);

  String get languageTitle => language?.title ?? 'this language';

  Phonology? get phonology => workspace.phonologies[languageId];

  List<LexiconTerm> get lexicon => snapshot.lexiconFor(languageId);
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// A panel's title, subtitle, actions and scrolling body — the frame every
/// panel in the Study shares.
class StudyPanelFrame extends StatelessWidget {
  const StudyPanelFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// A one-paragraph card: an empty state, a caution, a pointer elsewhere.
class StudyNotice extends StatelessWidget {
  const StudyNotice({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

const studyMono =
    TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Courier']);

// ---------------------------------------------------------------------------
// Sound — the Phonology Studio
// ---------------------------------------------------------------------------

class SoundPanel extends StatefulWidget {
  const SoundPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<SoundPanel> createState() => _SoundPanelState();
}

class _SoundPanelState extends State<SoundPanel> {
  late final _consonants = TextEditingController();
  late final _vowels = TextEditingController();
  late final _classes = TextEditingController();
  late final _templates = TextEditingController();
  late final _forbidden = TextEditingController();
  late final _clusters = TextEditingController();
  late final _minimum = TextEditingController();
  late final _maximum = TextEditingController();
  late final _tester = TextEditingController();
  StressRule _stress = StressRule.penultimate;
  bool _dirty = false;
  bool _saving = false;

  List<TextEditingController> get _fields => [
        _consonants,
        _vowels,
        _classes,
        _templates,
        _forbidden,
        _clusters,
        _minimum,
        _maximum,
      ];

  @override
  void initState() {
    super.initState();
    _fill(widget.study.phonology == null
        ? const PhonologyText(minSyllables: 1, maxSyllables: 4)
        : PhonologyText.from(widget.study.phonology!));
    for (final controller in _fields) {
      controller.addListener(_changed);
    }
    // Testing a word is reading the rules, not changing them.
    _tester.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [..._fields, _tester]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(PhonologyText text) {
    _consonants.text = text.consonants;
    _vowels.text = text.vowels;
    _classes.text = text.classes;
    _templates.text = text.templates;
    _forbidden.text = text.forbidden;
    _clusters.text = text.clusters;
    _minimum.text = '${text.minSyllables}';
    _maximum.text = '${text.maxSyllables}';
    _stress = text.stress;
  }

  void _changed() => setState(() => _dirty = true);

  PhonologyReading get _reading => PhonologyText(
        consonants: _consonants.text,
        vowels: _vowels.text,
        classes: _classes.text,
        templates: _templates.text,
        forbidden: _forbidden.text,
        clusters: _clusters.text,
        stress: _stress,
        minSyllables: int.tryParse(_minimum.text.trim()) ?? 0,
        maxSyllables: int.tryParse(_maximum.text.trim()) ?? 0,
      ).read(previous: widget.study.phonology);

  /// Chosen Advanced or Blank: the chooser steps aside for the fields.
  bool _chose = false;

  void _quickBuild() {
    setState(() {
      _fill(PhonologyText.from(starterPhonology()));
      _dirty = true;
    });
  }

  Future<void> _guidedBuild() async {
    final answers = await showGuidedBuild(context);
    if (answers == null || !mounted) return;
    setState(() {
      _fill(guidedPhonology(answers));
      _dirty = true;
    });
  }

  Future<void> _save(PhonologyReading reading) async {
    setState(() => _saving = true);
    final saved = await widget.study.commit(widget.study.workspace
        .withPhonology(widget.study.languageId, reading.phonology));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final reading = _reading;
    final isNew = study.phonology == null;
    return StudyPanelFrame(
      title: 'How ${study.languageTitle} sounds',
      subtitle: 'Its sounds, the shapes its syllables take, and what is never '
          'heard. Every generated word and every name check follows these '
          'rules.',
      actions: [
        FilledButton.icon(
          key: const Key('sound-save'),
          onPressed: study.canEdit && reading.canSave && _dirty && !_saving
              ? () => _save(reading)
              : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(_dirty ? 'Save rules' : 'Saved'),
        ),
      ],
      children: [
        if (isNew && !_dirty && !_chose)
          _BuildLevels(
            key: const Key('sound-blank'),
            onQuick: _quickBuild,
            onGuided: _guidedBuild,
            onAdvanced: () => setState(() => _chose = true),
            onBlank: () => setState(() {
              _fill(const PhonologyText(minSyllables: 1, maxSyllables: 4));
              _chose = true;
            }),
          ),
        _field(
            _consonants,
            'Consonants',
            'k:3 t th:2 r l — ":3" makes a '
                'sound three times as common',
            key: 'sound-consonants'),
        _field(_vowels, 'Vowels', 'a:4 e i o', key: 'sound-vowels'),
        _field(_templates, 'Syllable shapes',
            '(C)V(N), CLV — brackets make a part optional',
            key: 'sound-templates'),
        _field(
            _classes,
            'Sound classes',
            'One per line, e.g. "N = n m". C and V are every consonant and '
                'vowel unless you redefine them.',
            key: 'sound-classes',
            lines: 3),
        _field(_forbidden, 'Never heard',
            'ii aa ^ng h\$ — ^ is a word start, \$ a word end',
            key: 'sound-forbidden'),
        _field(_clusters, 'Permitted clusters (optional)',
            'tr kl — leave empty to allow any cluster the shapes make',
            key: 'sound-clusters'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<StressRule>(
                  key: const Key('sound-stress'),
                  isExpanded: true,
                  initialValue: _stress,
                  decoration: const InputDecoration(
                    labelText: 'Stress falls on',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: StressRule.initial,
                        child: Text('First syllable')),
                    DropdownMenuItem(
                        value: StressRule.penultimate,
                        child: Text('Second-to-last')),
                    DropdownMenuItem(
                        value: StressRule.antepenultimate,
                        child: Text('Third-to-last')),
                    DropdownMenuItem(
                        value: StressRule.finalSyllable,
                        child: Text('Last syllable')),
                    DropdownMenuItem(
                        value: StressRule.unmarked,
                        child: Text('No fixed stress')),
                  ],
                  onChanged: (value) => setState(() {
                    _stress = value ?? _stress;
                    _dirty = true;
                  }),
                ),
              ),
              SizedBox(
                width: 120,
                child: _numberField(_minimum, 'Fewest syllables', 'sound-min'),
              ),
              SizedBox(
                width: 120,
                child: _numberField(_maximum, 'Most syllables', 'sound-max'),
              ),
            ],
          ),
        ),
        if (reading.errors.isNotEmpty)
          Card(
            key: const Key('sound-errors'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final error in reading.errors)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $error'),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('Test a word', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('sound-tester'),
          controller: _tester,
          decoration: const InputDecoration(
            hintText: 'Type a word or a name to hear whether it belongs',
            border: OutlineInputBorder(),
          ),
        ),
        if (_tester.text.trim().isNotEmpty)
          _Verdict(verdict: reading.phonology.validate(_tester.text)),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, String hint,
          {required String key, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key(key),
          controller: controller,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 3,
          decoration: InputDecoration(
            labelText: label,
            helperText: hint,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _numberField(
          TextEditingController controller, String label, String key) =>
      TextField(
        key: Key(key),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}

/// The Constructed Language Builder's four levels, offered once: when a
/// language has no sound rules yet. Each is a way into the same fields.
class _BuildLevels extends StatelessWidget {
  const _BuildLevels({
    super.key,
    required this.onQuick,
    required this.onGuided,
    required this.onAdvanced,
    required this.onBlank,
  });

  final VoidCallback onQuick;
  final VoidCallback onGuided;
  final VoidCallback onAdvanced;
  final VoidCallback onBlank;

  @override
  Widget build(BuildContext context) {
    Widget level(String key, IconData icon, String title, String text,
            VoidCallback onTap) =>
        SizedBox(
          width: 250,
          child: Card(
            child: InkWell(
              key: Key(key),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon),
                    const SizedBox(height: 8),
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(text),
                  ],
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No sound rules yet. How would you like to begin?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            level('sound-quick-build', Icons.bolt_outlined, 'Quick Build',
                'A small, ordinary set of sounds to reshape.', onQuick),
            level('sound-guided-build', Icons.alt_route, 'Guided Build',
                'Five plain questions, answered into rules.', onGuided),
            level(
                'sound-advanced-build',
                Icons.tune,
                'Advanced Build',
                'Write every rule yourself, with the tester beside you.',
                onAdvanced),
            level('sound-blank-study', Icons.crop_square, 'Blank Study',
                'Start from nothing at all.', onBlank),
          ]),
        ],
      ),
    );
  }
}

/// Asks the Guided Build's five questions. Null when the author cancels.
Future<GuidedAnswers?> showGuidedBuild(BuildContext context) =>
    showDialog<GuidedAnswers>(
      context: context,
      builder: (context) => const _GuidedBuildDialog(),
    );

class _GuidedBuildDialog extends StatefulWidget {
  const _GuidedBuildDialog();

  @override
  State<_GuidedBuildDialog> createState() => _GuidedBuildDialogState();
}

class _GuidedBuildDialogState extends State<_GuidedBuildDialog> {
  SoundTexture _texture = SoundTexture.balanced;
  SyllableComplexity _complexity = SyllableComplexity.moderate;
  WordLength _length = WordLength.medium;
  StressRule _stress = StressRule.penultimate;
  final _avoid = TextEditingController();

  @override
  void dispose() {
    _avoid.dispose();
    super.dispose();
  }

  Widget _question<T>(String key, String question, List<T> values,
      String Function(T) label, T selected, ValueChanged<T> onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final value in values)
              ChoiceChip(
                key: Key('$key-$value'),
                label: Text(label(value)),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('guided-build'),
      title: const Text('Guided Build'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _question(
                  'guided-texture',
                  '1. How does it feel to say?',
                  SoundTexture.values,
                  (value) => value.label,
                  _texture,
                  (value) => setState(() => _texture = value)),
              _question(
                  'guided-complexity',
                  '2. How are its syllables built?',
                  SyllableComplexity.values,
                  (value) => value.label,
                  _complexity,
                  (value) => setState(() => _complexity = value)),
              _question(
                  'guided-length',
                  '3. How long are its words?',
                  WordLength.values,
                  (value) => value.label,
                  _length,
                  (value) => setState(() => _length = value)),
              _question(
                  'guided-stress',
                  '4. Where does the weight fall?',
                  const [
                    StressRule.initial,
                    StressRule.penultimate,
                    StressRule.finalSyllable,
                  ],
                  (value) => switch (value) {
                        StressRule.initial => 'On the first syllable',
                        StressRule.finalSyllable => 'On the last',
                        _ => 'Second-to-last',
                      },
                  _stress,
                  (value) => setState(() => _stress = value)),
              Text('5. Any sounds it never uses?',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              TextField(
                key: const Key('guided-avoid'),
                controller: _avoid,
                decoration: const InputDecoration(
                  hintText: 'z kh — leave empty for none',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('guided-build-done'),
          onPressed: () => Navigator.of(context).pop(GuidedAnswers(
            texture: _texture,
            complexity: _complexity,
            length: _length,
            stress: _stress,
            avoid: _avoid.text,
          )),
          child: const Text('Build my rules'),
        ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.verdict});

  final PhonotacticVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('sound-verdict'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            verdict.conforms ? Icons.check_circle_outline : Icons.block,
            color: verdict.conforms ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: verdict.conforms
                ? Text('Belongs. Said ${verdict.pronunciationGuide}.')
                : Text(verdict.problems.join(' ')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word Forge
// ---------------------------------------------------------------------------

class WordForgePanel extends StatefulWidget {
  const WordForgePanel({super.key, required this.study, this.onSaveWord});

  final StudyContext study;
  final Future<void> Function(String languageId, String spelling)? onSaveWord;

  @override
  State<WordForgePanel> createState() => _WordForgePanelState();
}

class _WordForgePanelState extends State<WordForgePanel> {
  static const _shapes = [
    WordShape(),
    WordShape.givenName,
    WordShape.placeName,
  ];

  late final _seed = TextEditingController(text: widget.study.languageTitle);
  WordShape _shape = _shapes.first;
  WordForgeResult? _result;
  final Set<String> _saved = {};

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  void _generate() {
    final phonology = widget.study.phonology;
    if (phonology == null) return;
    final phrase = _seed.text.trim().isEmpty ? 'words' : _seed.text.trim();
    setState(() {
      _result = WordForge.generate(
        phonology,
        GenerationSeed.phrase(phrase),
        count: 12,
        shape: _shape,
        exclude: {
          ...widget.study.snapshot.spellingsIn(widget.study.languageId),
          for (final word in widget.study.workspace.reserved)
            word.spelling.toLowerCase(),
        },
      );
    });
  }

  Future<void> _reserve(GeneratedWord word) async {
    await widget.study.commit(widget.study.workspace.reserving(ReservedWord(
      spelling: word.spelling,
      languageId: widget.study.languageId,
      note: _shape.label,
      seedPath: word.seedPath,
    )));
  }

  Future<void> _saveToLexicon(String spelling) async {
    final save = widget.onSaveWord;
    if (save == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await save(widget.study.languageId, spelling);
      if (!mounted) return;
      setState(() => _saved.add(spelling.toLowerCase()));
      messenger?.showSnackBar(
          SnackBar(content: Text('"$spelling" is now in the dictionary.')));
    } catch (_) {
      messenger?.showSnackBar(SnackBar(
          content: Text('"$spelling" could not be added. Nothing changed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final reserved = [
      for (final word in study.workspace.reserved)
        if (word.languageId == study.languageId) word,
    ];
    if (study.phonology == null) {
      return StudyPanelFrame(
        title: 'Word Forge',
        subtitle: 'Words and names that could only belong to '
            '${study.languageTitle}.',
        children: const [
          StudyNotice(
            key: Key('forge-needs-sound'),
            icon: Icons.graphic_eq,
            text: 'The forge works from the sound rules. Give this language '
                'its sounds on the Sound panel first — Quick Build takes a '
                'moment.',
          ),
        ],
      );
    }
    return StudyPanelFrame(
      title: 'Word Forge',
      subtitle: 'Every word here follows the sound rules of '
          '${study.languageTitle}. The same seed always forges the same list.',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                key: const Key('forge-seed'),
                controller: _seed,
                decoration: const InputDecoration(
                  labelText: 'Seed phrase',
                  helperText: 'e.g. "river names" — change it for a new list',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _generate(),
              ),
            ),
            SegmentedButton<WordShape>(
              key: const Key('forge-shape'),
              showSelectedIcon: false,
              segments: [
                for (final shape in _shapes)
                  ButtonSegment(value: shape, label: Text(shape.label)),
              ],
              selected: {_shape},
              onSelectionChanged: (selection) =>
                  setState(() => _shape = selection.single),
            ),
            FilledButton.icon(
              key: const Key('forge-generate'),
              onPressed: _generate,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('Forge'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_result != null) ...[
          if (_result!.shortfall > 0)
            StudyNotice(
              key: const Key('forge-shortfall'),
              icon: Icons.info_outline,
              text: 'The rules allow only ${_result!.words.length} new '
                  'words of this shape. Widen the syllable shapes or add '
                  'sounds for more.',
            ),
          for (final word in _result!.words)
            Card(
              child: ListTile(
                key: Key('forge-word-${word.spelling}'),
                title: Text(word.spelling),
                subtitle: Text(word.pronunciationGuide),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: word.spelling)),
                    ),
                    if (study.canEdit)
                      IconButton(
                        key: Key('forge-reserve-${word.spelling}'),
                        tooltip: 'Reserve',
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: () => _reserve(word),
                      ),
                    if (widget.onSaveWord != null && study.canEdit)
                      IconButton(
                        key: Key('forge-save-${word.spelling}'),
                        tooltip: 'Add to dictionary',
                        icon: Icon(_saved.contains(word.spelling.toLowerCase())
                            ? Icons.check
                            : Icons.library_add_outlined),
                        onPressed: _saved.contains(word.spelling.toLowerCase())
                            ? null
                            : () => _saveToLexicon(word.spelling),
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (reserved.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Reserved', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in reserved)
                InputChip(
                  key: Key('forge-reserved-${word.spelling}'),
                  label: Text(word.note.isEmpty
                      ? word.spelling
                      : '${word.spelling} · ${word.note}'),
                  onDeleted: study.canEdit
                      ? () =>
                          study.commit(study.workspace.releasing(word.spelling))
                      : null,
                  onPressed: widget.onSaveWord != null && study.canEdit
                      ? () => _saveToLexicon(word.spelling)
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dictionary — the Living Dictionary
// ---------------------------------------------------------------------------

class DictionaryPanel extends StatefulWidget {
  const DictionaryPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<DictionaryPanel> createState() => _DictionaryPanelState();
}

class _DictionaryPanelState extends State<DictionaryPanel> {
  final _query = TextEditingController();
  String? _wordClass;

  /// A themed collection: one of the entries' Codex tags.
  String? _theme;

  /// The phrasebook: phrases only, gathered under their themes.
  bool _phrasebook = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _entry(LexiconTerm term, StudyContext study) => Card(
        child: ListTile(
          key: Key('dictionary-entry-${term.recordId}'),
          title: Text(term.term),
          subtitle: Text([
            if (term.gloss.isNotEmpty) term.gloss,
            if (term.wordClass.isNotEmpty) term.wordClass,
            if (term.forms.isNotEmpty) 'forms: ${term.forms.join(', ')}',
            if (term.themes.isNotEmpty) term.themes.join(', '),
          ].join(' · ')),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => study.openRecord(term.recordId),
        ),
      );

  /// Matches the word, any recorded form, or any sense of its meaning — the
  /// last is the reverse lookup: search *sun* and find *aran*.
  static bool _matches(LexiconTerm term, String query) {
    if (query.isEmpty) return true;
    if (term.spellings.any((spelling) => spelling.contains(query))) return true;
    return term.gloss.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final query = _query.text.trim().toLowerCase();
    final classes = {
      for (final term in study.lexicon)
        if (term.wordClass.isNotEmpty) term.wordClass,
    }.toList()
      ..sort();
    final themes = {
      for (final term in study.lexicon) ...term.themes,
    }.toList()
      ..sort();
    final hasPhrases = study.lexicon.any((term) => term.isPhrase);
    final entries = [
      for (final term in study.lexicon)
        if (_matches(term, query) &&
            (_wordClass == null || term.wordClass == _wordClass) &&
            (_theme == null || term.themes.contains(_theme)) &&
            (!_phrasebook || term.isPhrase))
          term,
    ]..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));

    // The phrasebook reads the same entries, gathered under their themes; an
    // untagged phrase is still in the book, under its own heading.
    final sections = <String, List<LexiconTerm>>{};
    if (_phrasebook) {
      for (final term in entries) {
        final heads =
            term.themes.isEmpty ? const ['Other phrases'] : term.themes;
        for (final head in heads) {
          if (_theme != null && head != _theme) continue;
          (sections[head] ??= []).add(term);
        }
      }
    }

    return StudyPanelFrame(
      title: 'Dictionary',
      subtitle: '${study.lexicon.length} '
          '${study.lexicon.length == 1 ? 'word' : 'words'} in '
          '${study.languageTitle}. Search by the word or by its meaning.',
      children: [
        TextField(
          key: const Key('dictionary-search'),
          controller: _query,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'aran, or sun',
            border: OutlineInputBorder(),
          ),
        ),
        if (themes.isNotEmpty || hasPhrases) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasPhrases)
                FilterChip(
                  key: const Key('dictionary-phrasebook'),
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Phrasebook'),
                  selected: _phrasebook,
                  onSelected: (value) => setState(() => _phrasebook = value),
                ),
              for (final theme in themes)
                ChoiceChip(
                  key: Key('dictionary-theme-$theme'),
                  avatar: const Icon(Icons.sell_outlined, size: 16),
                  label: Text(theme),
                  selected: _theme == theme,
                  onSelected: (selected) =>
                      setState(() => _theme = selected ? theme : null),
                ),
            ],
          ),
        ],
        if (classes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _wordClass == null,
                onSelected: (_) => setState(() => _wordClass = null),
              ),
              for (final wordClass in classes)
                ChoiceChip(
                  key: Key('dictionary-class-$wordClass'),
                  label: Text(wordClass),
                  selected: _wordClass == wordClass,
                  onSelected: (_) => setState(() => _wordClass = wordClass),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (study.lexicon.isEmpty)
          StudyNotice(
            key: const Key('dictionary-empty'),
            icon: Icons.menu_book_outlined,
            text: 'No words yet. Add Lexicon Entry records for this language '
                'in ${study.recordHome}, or forge some and add them from the '
                'Word Forge.',
          )
        else if (entries.isEmpty)
          const StudyNotice(
            key: Key('dictionary-no-match'),
            icon: Icons.search_off,
            text: 'No word or meaning matches that search.',
          )
        else if (_phrasebook)
          for (final section in sections.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(section.key,
                  key: Key('phrasebook-section-${section.key}'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final term in section.value) _entry(term, study),
          ]
        else
          for (final term in entries) _entry(term, study),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Translation — the Translation Workbench
// ---------------------------------------------------------------------------

enum _Direction { fromLanguage, toLanguage }

class TranslationPanel extends StatefulWidget {
  const TranslationPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<TranslationPanel> createState() => _TranslationPanelState();
}

class _TranslationPanelState extends State<TranslationPanel> {
  final _phrase = TextEditingController();
  _Direction _direction = _Direction.fromLanguage;

  @override
  void initState() {
    super.initState();
    _phrase.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final workbench = TranslationWorkbench(
      study.lexicon,
      languageId: study.languageId,
      grammar: study.workspace.grammarBookFor(study.languageId),
    );
    final phrase = _phrase.text;
    final breakdown = phrase.trim().isEmpty
        ? null
        : _direction == _Direction.fromLanguage
            ? workbench.gloss(phrase)
            : workbench.lookUp(phrase);

    return StudyPanelFrame(
      title: 'Translation Workbench',
      subtitle: 'Word by word, against the words ${study.languageTitle} '
          'actually has. Nothing is guessed: a missing word keeps the phrase '
          'a draft.',
      children: [
        SegmentedButton<_Direction>(
          key: const Key('translation-direction'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _Direction.fromLanguage,
              label: Text('${study.languageTitle} → meaning'),
            ),
            ButtonSegment(
              value: _Direction.toLanguage,
              label: Text('Meaning → ${study.languageTitle}'),
            ),
          ],
          selected: {_direction},
          onSelectionChanged: (selection) =>
              setState(() => _direction = selection.single),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('translation-phrase'),
          controller: _phrase,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Phrase',
            border: OutlineInputBorder(),
          ),
        ),
        if (breakdown != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Chip(
                key: const Key('translation-status'),
                avatar: Icon(breakdown.isDraft
                    ? Icons.edit_outlined
                    : Icons.check_circle_outline),
                label: Text(breakdown.isDraft ? 'Draft' : 'Complete'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Builder(builder: (context) {
                  final lines = TranslationWorkbench.interlinear(breakdown);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lines.words,
                          key: const Key('translation-words'),
                          style: studyMono),
                      Text(lines.glosses,
                          key: const Key('translation-glosses'),
                          style: studyMono.copyWith(
                              color: Theme.of(context).colorScheme.primary)),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (breakdown.undefined.isNotEmpty)
            StudyNotice(
              key: const Key('translation-undefined'),
              icon: Icons.help_outline,
              text: 'Not yet in the dictionary: '
                  '${breakdown.undefined.toSet().join(', ')}.',
            ),
          for (var i = 0; i < breakdown.orderNotes.length; i++)
            StudyNotice(
              key: Key('translation-order-note-$i'),
              icon: Icons.swap_horiz,
              text: breakdown.orderNotes[i].message,
            ),
          if (breakdown.ambiguous.isNotEmpty)
            StudyNotice(
              key: const Key('translation-ambiguous'),
              icon: Icons.call_split,
              text: 'More than one meaning recorded for: '
                  '${breakdown.ambiguous.toSet().join(', ')}.',
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Script — the Alphabet and Script Designer's transliteration table
// ---------------------------------------------------------------------------

/// Reads glyph lines: `th = ᚦ`, or `a = U+E000` for a Private Use glyph a
/// custom font draws. A line after `#` is a letter name: `a = U+E000 # anna`.
({List<GlyphMapping> glyphs, List<String> errors}) parseGlyphLines(
    String source) {
  final glyphs = <GlyphMapping>[];
  final errors = <String>[];
  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final hash = line.indexOf('#');
    final body = (hash < 0 ? line : line.substring(0, hash)).trim();
    final name = hash < 0 ? '' : line.substring(hash + 1).trim();
    final equals = body.indexOf('=');
    if (equals <= 0) {
      errors.add('"$line" should read like "th = ᚦ".');
      continue;
    }
    final romanised = body.substring(0, equals).trim().toLowerCase();
    final right = body.substring(equals + 1).trim();
    final glyph = _decodeGlyph(right);
    if (romanised.isEmpty || glyph == null || glyph.isEmpty) {
      errors.add('"$line" has no glyph after "=".');
      continue;
    }
    glyphs.add(GlyphMapping(romanised: romanised, glyph: glyph, name: name));
  }
  return (glyphs: glyphs, errors: errors);
}

/// The glyph lines for [mapping], with Private Use code points written as
/// `U+` so they survive a font that cannot draw them.
String formatGlyphLines(ScriptMapping mapping) => [
      for (final glyph in mapping.glyphs)
        '${glyph.romanised} = ${_encodeGlyph(glyph.glyph)}'
            '${glyph.name.isEmpty ? '' : ' # ${glyph.name}'}',
    ].join('\n');

String? _decodeGlyph(String text) {
  final buffer = StringBuffer();
  for (final part in text.split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    final code = RegExp(r'^U\+([0-9A-Fa-f]{4,6})$').firstMatch(part);
    if (code != null) {
      final value = int.parse(code.group(1)!, radix: 16);
      if (value > 0x10FFFF) return null;
      buffer.writeCharCode(value);
    } else {
      buffer.write(part);
    }
  }
  return buffer.toString();
}

String _encodeGlyph(String glyph) => [
      for (final rune in glyph.runes)
        (rune >= 0xE000 && rune <= 0xF8FF) || rune >= 0xF0000
            ? 'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}'
            : String.fromCharCode(rune),
    ].join(' ');

class ScriptPanel extends StatefulWidget {
  const ScriptPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<ScriptPanel> createState() => _ScriptPanelState();
}

class _ScriptPanelState extends State<ScriptPanel> {
  final _lines = TextEditingController();
  final _preview = TextEditingController();
  String? _scriptId;
  ScriptDirection _direction = ScriptDirection.leftToRight;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final scripts = widget.study.snapshot.writingSystems;
    if (scripts.isNotEmpty) _select(scripts.first.id);
    _lines.addListener(() => setState(() => _dirty = true));
    _preview.addListener(() => setState(() {}));
    _dirty = false;
  }

  @override
  void dispose() {
    _lines.dispose();
    _preview.dispose();
    super.dispose();
  }

  void _select(String id) {
    final existing = widget.study.workspace.scripts[id];
    _scriptId = id;
    _lines.text = existing == null ? '' : formatGlyphLines(existing);
    _direction = existing?.direction ?? ScriptDirection.leftToRight;
    _dirty = false;
  }

  Future<void> _save(List<GlyphMapping> glyphs) async {
    final id = _scriptId!;
    final saved = await widget.study.commit(widget.study.workspace.withScript(
      id,
      glyphs.isEmpty
          ? null
          : ScriptMapping(
              writingSystemRecordId: id,
              glyphs: glyphs,
              direction: _direction,
            ),
    ));
    if (saved && mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final scripts = study.snapshot.writingSystems;
    if (scripts.isEmpty) {
      return StudyPanelFrame(
        title: 'Script',
        subtitle: 'Write in romanisation and read it back in your own letters.',
        children: [
          StudyNotice(
            key: const Key('script-empty'),
            icon: Icons.edit_note,
            text: 'Create a Writing System record in ${study.recordHome}, and '
                'its letters can be mapped here.',
          ),
        ],
      );
    }
    final parsed = parseGlyphLines(_lines.text);
    final mapping = ScriptMapping(
      writingSystemRecordId: _scriptId!,
      glyphs: parsed.glyphs,
      direction: _direction,
    );
    final preview = mapping.toScript(_preview.text);

    return StudyPanelFrame(
      title: 'Script',
      subtitle: 'One line per letter. The preview reads romanisation and '
          'writes your script — anything the table does not cover is named, '
          'not hidden.',
      actions: [
        FilledButton.icon(
          key: const Key('script-save'),
          onPressed: study.canEdit && _dirty && parsed.errors.isEmpty
              ? () => _save(parsed.glyphs)
              : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(_dirty ? 'Save letters' : 'Saved'),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final script in scripts)
              ChoiceChip(
                key: Key('script-choice-${script.id}'),
                label: Text(script.title),
                selected: _scriptId == script.id,
                onSelected: (_) => setState(() => _select(script.id)),
              ),
            IconButton(
              tooltip: 'Open the Writing System record',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => study.openRecord(_scriptId!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<ScriptDirection>(
          key: const Key('script-direction'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: ScriptDirection.leftToRight,
                label: Text('Left to right')),
            ButtonSegment(
                value: ScriptDirection.rightToLeft,
                label: Text('Right to left')),
            ButtonSegment(
                value: ScriptDirection.topToBottom,
                label: Text('Top to bottom')),
          ],
          selected: {_direction},
          onSelectionChanged: (selection) => setState(() {
            _direction = selection.single;
            _dirty = true;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('script-lines'),
          controller: _lines,
          minLines: 4,
          maxLines: 12,
          style: studyMono,
          decoration: const InputDecoration(
            labelText: 'Letters',
            helperText: 'th = ᚦ   or   a = U+E000 # anna',
            border: OutlineInputBorder(),
          ),
        ),
        for (final error in parsed.errors)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (mapping.ambiguousGlyphs.isNotEmpty)
          StudyNotice(
            key: const Key('script-ambiguous'),
            icon: Icons.call_split,
            text: 'These letters share a glyph, so reading them back cannot '
                'say which was meant: ${mapping.ambiguousGlyphs.join(' ')}',
          ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('script-preview-input'),
          controller: _preview,
          decoration: const InputDecoration(
            labelText: 'Preview — type in romanisation',
            border: OutlineInputBorder(),
          ),
        ),
        if (_preview.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Directionality(
            textDirection: _direction == ScriptDirection.rightToLeft
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Text(
              preview.output,
              key: const Key('script-preview'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (!preview.isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Not in the table yet: ${preview.unmapped.join(' ')}',
                key: const Key('script-unmapped'),
              ),
            ),
        ],
      ],
    );
  }
}
