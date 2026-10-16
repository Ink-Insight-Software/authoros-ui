/// Language Forge Phase 4 — the Grammar Workshop panel.
///
/// Lists the language's Grammar Rule records — the host's, as the author
/// wrote them — and, for any one, edits the formula the Study keeps beside it.
/// The rule's prose is shown and never edited here: its statement, examples
/// and exceptions are the record's, and *Open the record* is where they
/// change.
///
/// An inflection formula is written as short lines, the way a grammar sketch
/// writes them — `a => -a +ae`, `* => +i` — and previewed at once as the
/// paradigm of every word it applies to, so the author sees the rule working
/// on their own vocabulary before saving it.
library;

import 'package:authoros_core/connected_domain.dart';
import 'package:authoros_core/language_forge/grammar.dart';
import 'package:authoros_core/language_forge/lexicon.dart';
import 'package:flutter/material.dart';

import 'study_panels.dart';

enum _Kind { prose, inflection, wordOrder }

class GrammarPanel extends StatefulWidget {
  const GrammarPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<GrammarPanel> createState() => _GrammarPanelState();
}

class _GrammarPanelState extends State<GrammarPanel> {
  String? _ruleId;

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final rules = study.snapshot.grammarFor(study.languageId);
    final selected = rules.where((rule) => rule.id == _ruleId).firstOrNull;
    return StudyPanelFrame(
      title: 'Grammar Workshop',
      subtitle: 'The rules of ${study.languageTitle}, as '
          '${study.recordHome} holds them '
          '— and, beside any of them, a formula the Study can apply: to '
          'inflect words, read them back in translation, and check the '
          'manuscript.',
      children: [
        if (rules.isEmpty)
          StudyNotice(
            key: const Key('grammar-empty'),
            icon: Icons.rule,
            text: 'No grammar rules yet. Add Grammar Rule entries for this '
                'language in ${study.recordHome}; each can be given a formula '
                'here.',
          ),
        for (final rule in rules)
          Card(
            child: ListTile(
              key: Key('grammar-rule-${rule.id}'),
              leading: const Icon(Icons.rule),
              title: Text(rule.title),
              subtitle: Text(_summary(rule, study)),
              selected: rule.id == _ruleId,
              onTap: () => setState(() => _ruleId = rule.id),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          _FormulaEditor(
            key: ValueKey('formula-${selected.id}'),
            rule: selected,
            study: study,
          ),
        ],
      ],
    );
  }

  static String _summary(AuthorRecord rule, StudyContext study) {
    final formula = study.workspace.grammar[rule.id];
    final domain = rule.fields['domain'];
    return [
      if (domain is String && domain.isNotEmpty) domain,
      switch (formula) {
        InflectionFormula(:final label, :final abbreviation) =>
          'Formula: $label ($abbreviation)',
        WordOrderFormula(:final verb) => 'Formula: word order, ${verb.formal}',
        null => 'Prose only',
      },
    ].join(' · ');
  }
}

class _FormulaEditor extends StatefulWidget {
  const _FormulaEditor({super.key, required this.rule, required this.study});

  final AuthorRecord rule;
  final StudyContext study;

  @override
  State<_FormulaEditor> createState() => _FormulaEditorState();
}

class _FormulaEditorState extends State<_FormulaEditor> {
  late final GrammarFormula? _saved =
      widget.study.workspace.grammar[widget.rule.id];

  late final InflectionFormula? _savedInflection = switch (_saved) {
    final InflectionFormula formula => formula,
    _ => null,
  };
  late final WordOrderFormula? _savedOrder = switch (_saved) {
    final WordOrderFormula formula => formula,
    _ => null,
  };

  late _Kind _kind = switch (_saved) {
    InflectionFormula() => _Kind.inflection,
    WordOrderFormula() => _Kind.wordOrder,
    null => _Kind.prose,
  };

  late GrammarCategory _category = _saved?.category ?? GrammarCategory.plural;
  late final _label =
      TextEditingController(text: _savedInflection?.label ?? '');
  late final _abbreviation =
      TextEditingController(text: _savedInflection?.abbreviation ?? '');
  late final _wordClass =
      TextEditingController(text: _savedInflection?.wordClass ?? 'Noun');
  late final _branches = TextEditingController(
      text:
          _savedInflection?.branches.map((branch) => branch.text).join('\n') ??
              '');
  late final _irregular = TextEditingController(
      text: _savedInflection?.irregular.entries
              .map((entry) => '${entry.key} = ${entry.value}')
              .join('\n') ??
          '');
  late VerbPosition _verb = _savedOrder?.verb ?? VerbPosition.free;
  late AdjectivePosition _adjective =
      _savedOrder?.adjective ?? AdjectivePosition.free;

  List<TextEditingController> get _fields =>
      [_label, _abbreviation, _wordClass, _branches, _irregular];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  String get _languageId => widget.study.languageId;

  ({GrammarFormula? formula, List<String> errors}) get _built {
    switch (_kind) {
      case _Kind.prose:
        return (formula: null, errors: const []);
      case _Kind.wordOrder:
        return (
          formula: WordOrderFormula(
              languageId: _languageId, verb: _verb, adjective: _adjective),
          errors: const [],
        );
      case _Kind.inflection:
        final branches = parseBranches(_branches.text);
        final irregular = parseIrregulars(_irregular.text);
        final errors = [
          if (_label.text.trim().isEmpty) 'Name the form, e.g. "Plural".',
          if (_abbreviation.text.trim().isEmpty)
            'Give it a gloss tag, e.g. "PL".',
          if (branches.branches.isEmpty &&
              irregular.irregular.isEmpty &&
              branches.errors.isEmpty)
            'Write at least one line, e.g. "* => +i".',
          ...branches.errors,
          ...irregular.errors,
        ];
        return (
          formula: InflectionFormula(
            languageId: _languageId,
            category: _category,
            label: _label.text.trim(),
            abbreviation: _abbreviation.text.trim().toUpperCase(),
            wordClass: _wordClass.text.trim(),
            branches: branches.branches,
            irregular: irregular.irregular,
          ),
          errors: errors,
        );
    }
  }

  Future<void> _save(GrammarFormula? formula) => widget.study
      .commit(widget.study.workspace.withGrammar(widget.rule.id, formula));

  Widget _field(TextEditingController controller, String label, String key,
          {double? width, int lines = 1, String? helper}) =>
      SizedBox(
        width: width,
        child: TextField(
          key: Key(key),
          controller: controller,
          enabled: widget.study.canEdit,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 4,
          style: lines == 1 ? null : studyMono,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statement = widget.rule.fields['statement'];
    final built = _built;
    final formula = built.formula;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.rule.title,
                      style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  key: const Key('grammar-open-record'),
                  onPressed: () => widget.study.openRecord(widget.rule.id),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open the record'),
                ),
              ],
            ),
            if (statement is String && statement.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(statement.trim(),
                    key: const Key('grammar-statement'),
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 8),
            SegmentedButton<_Kind>(
              key: const Key('grammar-kind'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Kind.prose, label: Text('Prose only')),
                ButtonSegment(
                    value: _Kind.inflection, label: Text('Inflection')),
                ButtonSegment(
                    value: _Kind.wordOrder, label: Text('Word order')),
              ],
              selected: {_kind},
              onSelectionChanged: widget.study.canEdit
                  ? (selection) => setState(() => _kind = selection.single)
                  : null,
            ),
            const SizedBox(height: 12),
            if (_kind == _Kind.inflection) ..._inflection(formula),
            if (_kind == _Kind.wordOrder) ..._wordOrderFields(),
            if (_kind == _Kind.prose)
              const Text('This rule stays in prose. Nothing is applied, and '
                  'nothing is checked.'),
            for (final error in built.errors)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (widget.study.canEdit) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('grammar-save'),
                onPressed: built.errors.isEmpty ? () => _save(formula) : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save formula'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _inflection(GrammarFormula? formula) {
    final theme = Theme.of(context);
    final preview = <(LexiconTerm, String?)>[
      if (formula is InflectionFormula)
        for (final term in widget.study.lexicon)
          if (formula.appliesTo(term)) (term, formula.derive(term.term)),
    ].take(12).toList();
    return [
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<GrammarCategory>(
            key: const Key('grammar-category'),
            isExpanded: true,
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'What it governs',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final category in GrammarCategory.values)
                if (category != GrammarCategory.wordOrder)
                  DropdownMenuItem(
                    value: category,
                    child: Text('${category.plain} (${category.formal})'),
                  ),
            ],
            onChanged: widget.study.canEdit
                ? (value) => setState(() => _category = value ?? _category)
                : null,
          ),
        ),
        _field(_label, 'Form', 'grammar-label', width: 160),
        _field(_abbreviation, 'Gloss tag', 'grammar-abbreviation', width: 120),
        _field(_wordClass, 'Word class', 'grammar-word-class',
            width: 160, helper: 'Empty for every class'),
      ]),
      const SizedBox(height: 12),
      _field(_branches, 'How the form is made', 'grammar-branches',
          lines: 3,
          helper: 'One line per ending. "* => +i" adds -i to any word; '
              '"a => -a +ae" turns a final -a into -ae; "* => ka+" adds a '
              'prefix. The longest matching ending wins.'),
      const SizedBox(height: 12),
      _field(_irregular, 'Irregular forms', 'grammar-irregular',
          lines: 2, helper: 'One per line: "mena = menar".'),
      if (preview.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('On your words', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final (term, form) in preview)
          Text(
            form == null
                ? '${term.term} — no line fits'
                : '${term.term} → $form',
            key: Key('grammar-preview-${term.recordId}'),
            style: studyMono,
          ),
      ],
    ];
  }

  List<Widget> _wordOrderFields() => [
        Text('Where the verb goes',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<VerbPosition>(
          key: const Key('grammar-verb'),
          showSelectedIcon: false,
          segments: [
            for (final position in VerbPosition.values)
              ButtonSegment(value: position, label: Text(position.plain)),
          ],
          selected: {_verb},
          onSelectionChanged: widget.study.canEdit
              ? (selection) => setState(() => _verb = selection.single)
              : null,
        ),
        const SizedBox(height: 12),
        Text('Where an adjective goes',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<AdjectivePosition>(
          key: const Key('grammar-adjective'),
          showSelectedIcon: false,
          segments: [
            for (final position in AdjectivePosition.values)
              ButtonSegment(value: position, label: Text(position.plain)),
          ],
          selected: {_adjective},
          onSelectionChanged: widget.study.canEdit
              ? (selection) => setState(() => _adjective = selection.single)
              : null,
        ),
        const SizedBox(height: 8),
        const Text('The Translation Workbench checks phrases against this, '
            'using each word\'s class. It notes; it never reorders.'),
      ];
}
