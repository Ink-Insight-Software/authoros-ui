/// Language Forge Phase 5 — the Sound Change and Family panels.
///
/// **Sound Change** is how a dialect drifts from its language or a descendant
/// from its ancestor: ordered rules applied to the source's words, previewed
/// with each word's history, and accepted one word at a time into the target
/// language through the host's own create path.
///
/// **Family** draws what the records' links already say: the language family
/// tree, what each language borrowed and lent, and — for any word — the words
/// it came from and the words that came from it.
library;

import 'package:authoros_core/language_forge/lexicon.dart';
import 'package:authoros_core/language_forge/lineage.dart';
import 'package:authoros_core/language_forge/sound_change.dart';
import 'package:flutter/material.dart';

import 'study_panels.dart';

// ---------------------------------------------------------------------------
// Sound Change
// ---------------------------------------------------------------------------

class SoundChangePanel extends StatefulWidget {
  const SoundChangePanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<SoundChangePanel> createState() => _SoundChangePanelState();
}

class _SoundChangePanelState extends State<SoundChangePanel> {
  String? _selectedId;

  List<SoundChangeSet> get _sets => [
        for (final set in widget.study.workspace.soundChanges)
          if (set.fromLanguageId == widget.study.languageId ||
              set.toLanguageId == widget.study.languageId)
            set,
      ];

  /// A likely target: a dialect of this language, else any other language.
  String? get _defaultTarget {
    final study = widget.study;
    final others = [
      for (final language in study.snapshot.languages)
        if (language.id != study.languageId) language,
    ];
    for (final language in others) {
      if (language.fields['parentLanguage'] == study.languageId) {
        return language.id;
      }
    }
    return others.firstOrNull?.id;
  }

  Future<void> _create() async {
    final study = widget.study;
    final target = _defaultTarget;
    if (target == null) return;
    final set = SoundChangeSet(
      id: 'sound-change-${DateTime.now().microsecondsSinceEpoch}',
      name: '${study.languageTitle} to '
          '${study.snapshot.languageById(target)?.title ?? 'its descendant'}',
      fromLanguageId: study.languageId,
      toLanguageId: target,
    );
    final saved = await study.commit(study.workspace.withSoundChanges(set));
    if (saved && mounted) setState(() => _selectedId = set.id);
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final sets = _sets;
    final selected = sets.where((set) => set.id == _selectedId).firstOrNull;
    final canCreate = study.canEdit && _defaultTarget != null;
    return StudyPanelFrame(
      title: 'Sound change',
      subtitle: 'How ${study.languageTitle}\'s words change on the way to a '
          'dialect or a descendant — written as rules, applied in order, and '
          'accepted a word at a time.',
      actions: [
        if (study.canEdit)
          FilledButton.icon(
            key: const Key('sound-change-new'),
            onPressed: canCreate ? _create : null,
            icon: const Icon(Icons.add),
            label: const Text('New sound change'),
          ),
      ],
      children: [
        if (_defaultTarget == null)
          StudyNotice(
            key: const Key('sound-change-needs-target'),
            icon: Icons.account_tree_outlined,
            text: 'Sound change needs a second language to change into. '
                'Create a Dialect of this language, or its descendant, in '
                '${study.recordHome}.',
          )
        else if (sets.isEmpty)
          const StudyNotice(
            key: Key('sound-change-empty'),
            icon: Icons.timeline,
            text: 'No sound changes yet. A set of rules like "a > e / _i" '
                'carries every word of one language into another.',
          ),
        for (final set in sets)
          Card(
            child: ListTile(
              key: Key('sound-change-set-${set.id}'),
              leading: const Icon(Icons.timeline),
              title: Text(set.name),
              subtitle: Text('${set.rules.length} '
                  '${set.rules.length == 1 ? 'rule' : 'rules'} · '
                  '${study.snapshot.languageById(set.fromLanguageId)?.title ?? '?'}'
                  ' → '
                  '${study.snapshot.languageById(set.toLanguageId)?.title ?? '?'}'),
              selected: set.id == _selectedId,
              onTap: () => setState(() => _selectedId = set.id),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          _SoundChangeEditor(
            key: ValueKey('change-editor-${selected.id}'),
            set: selected,
            study: study,
            onDeleted: () => setState(() => _selectedId = null),
          ),
        ],
      ],
    );
  }
}

class _SoundChangeEditor extends StatefulWidget {
  const _SoundChangeEditor({
    super.key,
    required this.set,
    required this.study,
    required this.onDeleted,
  });

  final SoundChangeSet set;
  final StudyContext study;
  final VoidCallback onDeleted;

  @override
  State<_SoundChangeEditor> createState() => _SoundChangeEditorState();
}

class _SoundChangeEditorState extends State<_SoundChangeEditor> {
  late final _name = TextEditingController(text: widget.set.name);
  late final _rules = TextEditingController(text: widget.set.rules.join('\n'));
  late final _notes = TextEditingController(text: widget.set.notes);
  late String _from = widget.set.fromLanguageId;
  late String _to = widget.set.toLanguageId;

  /// Source words accepted into the target during this visit.
  final Set<String> _accepted = {};

  @override
  void initState() {
    super.initState();
    _rules.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _rules.dispose();
    _notes.dispose();
    super.dispose();
  }

  SoundChangeSet get _current => widget.set.copyWith(
        name: _name.text.trim().isEmpty ? 'Sound change' : _name.text.trim(),
        fromLanguageId: _from,
        toLanguageId: _to,
        rules: [
          for (final line in _rules.text.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ],
        notes: _notes.text.trim(),
      );

  String _title(String id) =>
      widget.study.snapshot.languageById(id)?.title ?? 'Unknown language';

  Future<void> _accept(EvolvedWord word) async {
    final save = widget.study.saveEntry;
    if (save == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await save(LexiconEntryDraft(
        languageId: _to,
        term: word.form,
        gloss: word.source.gloss,
        wordClass: word.source.wordClass,
        etymology: word.etymology(_title(_from)),
        originRecordId: word.source.recordId,
      ));
      if (!mounted) return;
      setState(() => _accepted.add(word.source.recordId));
      messenger?.showSnackBar(SnackBar(
          content: Text('"${word.form}" is now a word of ${_title(_to)}.')));
    } catch (_) {
      messenger?.showSnackBar(SnackBar(
          content:
              Text('"${word.form}" could not be added. Nothing changed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final theme = Theme.of(context);
    final current = _current;
    final classes = study.workspace.phonologies[_from]?.classes ??
        const <String, List<String>>{};
    final parsed = current.parse(classes);
    final source = study.snapshot.lexiconFor(_from);
    final proposals = parsed.errors.isEmpty
        ? SoundChangeEngine.propose(source, parsed.changes)
        : const <EvolvedWord>[];
    final existing = study.snapshot.spellingsIn(_to);
    final languages = study.snapshot.languages;

    Widget picker(String key, String label, String value,
            ValueChanged<String> onChanged) =>
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            key: Key(key),
            isExpanded: true,
            initialValue: value,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final language in languages)
                DropdownMenuItem(
                    value: language.id, child: Text(language.title)),
            ],
            onChanged: study.canEdit
                ? (next) => setState(() => onChanged(next ?? value))
                : null,
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 420,
              child: TextField(
                key: const Key('sound-change-name'),
                controller: _name,
                enabled: study.canEdit,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              picker('sound-change-from', 'From', _from, (id) => _from = id),
              picker('sound-change-to', 'Into', _to, (id) => _to = id),
            ]),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sound-change-rules'),
              controller: _rules,
              enabled: study.canEdit,
              minLines: 3,
              maxLines: 10,
              style: studyMono,
              decoration: const InputDecoration(
                labelText: 'Rules, in order',
                helperText: 'One per line. "a > e / _i" · "k > ch / _[ie]" · '
                    '"t > d / V_V" · "h > ∅ / #_" — V, C and your own sound '
                    'classes come from the source language\'s sound rules.',
                helperMaxLines: 3,
                border: OutlineInputBorder(),
              ),
            ),
            for (final error in parsed.errors)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sound-change-notes'),
              controller: _notes,
              enabled: study.canEdit,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                helperText: 'When it happened, and why — contact, conquest, '
                    'isolation.',
                border: OutlineInputBorder(),
              ),
            ),
            if (study.canEdit) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  key: const Key('sound-change-save'),
                  onPressed: parsed.errors.isEmpty && _from != _to
                      ? () => study
                          .commit(study.workspace.withSoundChanges(current))
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save rules'),
                ),
                TextButton.icon(
                  key: const Key('sound-change-delete'),
                  onPressed: () async {
                    final saved = await study.commit(
                        study.workspace.withoutSoundChanges(widget.set.id));
                    if (saved) widget.onDeleted();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ]),
            ],
            if (_from == _to)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Choose two different languages.'),
              ),
            if (proposals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('${_title(_from)} → ${_title(_to)}',
                  style: theme.textTheme.titleMedium),
              Text(
                '${(SoundChangeEngine.unchangedShare(proposals) * 100).round()}% '
                'of ${_title(_from)}\'s words would still sound the same. '
                'A measure of sound only — how well speakers understand each '
                'other also turns on grammar and meaning.',
                key: const Key('sound-change-share'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final word in proposals)
                _ProposalRow(
                  word: word,
                  alreadyAWord: existing.contains(word.form.toLowerCase()),
                  accepted: _accepted.contains(word.source.recordId),
                  onAccept: study.canEdit && study.saveEntry != null
                      ? () => _accept(word)
                      : null,
                ),
            ] else if (source.isEmpty && parsed.errors.isEmpty)
              const StudyNotice(
                key: Key('sound-change-no-words'),
                icon: Icons.menu_book_outlined,
                text: 'The source language has no words yet to carry '
                    'across.',
              ),
          ],
        ),
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.word,
    required this.alreadyAWord,
    required this.accepted,
    required this.onAccept,
  });

  final EvolvedWord word;
  final bool alreadyAWord;
  final bool accepted;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: Key('sound-change-proposal-${word.source.recordId}'),
        title: Text('${word.source.term} → ${word.form}', style: studyMono),
        subtitle: Text(word.changed
            ? word.steps
                .map((step) => '${step.before} > ${step.after}  (${step.rule})')
                .join('\n')
            : 'Unchanged'),
        trailing: accepted
            ? const Icon(Icons.check, key: Key('sound-change-accepted'))
            : alreadyAWord
                ? const Tooltip(
                    message: 'Already a word of the target language',
                    child: Icon(Icons.done_all),
                  )
                : onAccept == null
                    ? null
                    : TextButton(
                        key: Key('sound-change-accept-${word.source.recordId}'),
                        onPressed: onAccept,
                        child: const Text('Accept'),
                      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Family
// ---------------------------------------------------------------------------

class FamilyPanel extends StatefulWidget {
  const FamilyPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<FamilyPanel> createState() => _FamilyPanelState();
}

class _FamilyPanelState extends State<FamilyPanel> {
  String? _wordId;

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final theme = Theme.of(context);
    final family = study.snapshot.languageFamily;
    final words = study.snapshot.wordHistory;
    final titles = {
      for (final language in study.snapshot.languages)
        language.id: language.title,
    };
    final byWordId = {
      for (final term in study.snapshot.lexicon) term.recordId: term,
    };
    final historied = [
      for (final term in study.lexicon)
        if (words.parentsOf(term.recordId).isNotEmpty ||
            words.childrenOf(term.recordId).isNotEmpty ||
            words.borrowedFrom(term.recordId).isNotEmpty)
          term,
    ];
    final selected =
        _wordId != null && byWordId.containsKey(_wordId) ? _wordId : null;

    String wordLabel(String id) {
      final term = byWordId[id];
      if (term == null) return id;
      final language = titles[term.languageId];
      return language == null ? term.term : '${term.term} ($language)';
    }

    return StudyPanelFrame(
      title: 'Family',
      subtitle: 'Where ${study.languageTitle} comes from, what came from it, '
          'and where its words have been — drawn from the records\' '
          '"Originated from" and "Influences" links.',
      children: [
        Text('The language family', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          key: const Key('family-tree'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, row) in family.forest().indexed)
                  _TreeRow(
                    rowKey: 'family-row-$index',
                    row: row,
                    label: titles[row.id] ?? row.id,
                    current: row.id == study.languageId,
                    isolate: family.isIsolate(row.id),
                    onTap: () => study.openRecord(row.id),
                  ),
              ],
            ),
          ),
        ),
        for (final language in study.snapshot.languages)
          if (family.borrowedFrom(language.id).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${language.title} borrowed from '
                '${family.borrowedFrom(language.id).map((id) => titles[id] ?? id).join(', ')}.',
                key: Key('family-borrowing-${language.id}'),
              ),
            ),
        const SizedBox(height: 20),
        Text('Word histories', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (historied.isEmpty)
          StudyNotice(
            key: const Key('family-no-histories'),
            icon: Icons.history,
            text: 'No word of this language has a recorded history yet. Link '
                'a word to the word it came from in ${study.recordHome} '
                '("Originated from"), or accept one from the Sound Change '
                'panel.',
          )
        else ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final term in historied)
              ChoiceChip(
                key: Key('family-word-${term.recordId}'),
                label: Text(term.term),
                selected: selected == term.recordId,
                onSelected: (_) => setState(() => _wordId = term.recordId),
              ),
          ]),
          if (selected != null) ...[
            const SizedBox(height: 12),
            Card(
              key: const Key('family-word-history'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (words.ancestryOf(selected).isNotEmpty)
                      Text(
                        [
                          wordLabel(selected),
                          for (final id in words.ancestryOf(selected))
                            wordLabel(id),
                        ].join('  ←  '),
                        key: const Key('family-ancestry'),
                      ),
                    if (words.borrowedFrom(selected).isNotEmpty)
                      Text('Borrowed from '
                          '${words.borrowedFrom(selected).map(wordLabel).join(', ')}.'),
                    if (words.childrenOf(selected).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Came from it:', style: theme.textTheme.titleSmall),
                      for (final (index, row)
                          in words.descendantsOf(selected).skip(1).indexed)
                        _TreeRow(
                          rowKey: 'family-word-row-$index',
                          row: row,
                          label: wordLabel(row.id),
                          current: false,
                          isolate: false,
                          onTap: () => study.openRecord(row.id),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.rowKey,
    required this.row,
    required this.label,
    required this.current,
    required this.isolate,
    required this.onTap,
  });

  /// Position-based: a language with two parents appears twice.
  final String rowKey;
  final LineageRow row;
  final String label;
  final bool current;
  final bool isolate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = [
      if (row.kind == LineageKind.dialect) 'dialect',
      if (isolate) 'isolate',
      if (row.loops) 'the links loop back here',
    ];
    return InkWell(
      key: Key(rowKey),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: 24.0 * row.depth, top: 3, bottom: 3),
        child: Row(
          children: [
            Icon(
              row.depth == 0
                  ? Icons.account_tree_outlined
                  : row.kind == LineageKind.dialect
                      ? Icons.record_voice_over_outlined
                      : Icons.subdirectory_arrow_right,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                note.isEmpty ? label : '$label — ${note.join(', ')}',
                style: current
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
