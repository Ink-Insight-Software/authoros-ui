/// Language Forge Phase 3 — the Profile and Naming panels.
///
/// **Profile** is the language's overview: the Language Profile report laid
/// out section by section, each saying what it found and what would finish it,
/// and each pointing at the panel — or the record — where that is done.
///
/// **Naming** is the Naming Convention Builder: the conventions a language's
/// peoples name themselves by, edited here, saved in the working layer, and
/// forged into full names by the same sound rules as every other word.
library;

import 'package:authoros_core/language_forge/language_profile.dart';
import 'package:authoros_core/language_forge/lexicon.dart';
import 'package:authoros_core/language_forge/naming_conventions.dart';
import 'package:authoros_core/language_forge/word_forge.dart';
import 'package:authoros_core/procedural/generation_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'study_panels.dart';

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({super.key, required this.study});

  final StudyContext study;

  @override
  Widget build(BuildContext context) {
    final language = study.language;
    if (language == null) return const SizedBox.shrink();
    final report = languageProfile(
      language: language,
      snapshot: study.snapshot,
      workspace: study.workspace,
    );
    final theme = Theme.of(context);
    return StudyPanelFrame(
      title: '${study.languageTitle} — Language Profile',
      subtitle: 'Everything this language is, read from ${study.recordHome} '
          'and the Study. Each section says where it is finished.',
      actions: [
        OutlinedButton.icon(
          key: const Key('profile-open-record'),
          onPressed: () => study.openRecord(study.languageId),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open the record'),
        ),
      ],
      children: [
        Card(
          key: const Key('profile-summary'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.isComplete
                      ? 'Every core section is complete.'
                      : '${report.coreComplete} of ${report.coreTotal} core '
                          'sections complete',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: report.coreComplete / report.coreTotal,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final section in report.sections)
          _SectionCard(section: section, study: study),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.study});

  final ProfileSection section;
  final StudyContext study;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, colour, word) = switch (section.status) {
      ProfileStatus.complete => (
          Icons.check_circle,
          scheme.primary,
          'Complete'
        ),
      ProfileStatus.started => (Icons.timelapse, scheme.tertiary, 'Started'),
      ProfileStatus.empty => (
          Icons.radio_button_unchecked,
          scheme.outline,
          'Not started'
        ),
    };
    final slug = section.kind.panelSlug;
    return Card(
      key: Key('profile-section-${section.kind.name}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colour),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${section.kind.title}'
                    '${section.kind.isCore ? '' : ' (optional)'} — $word',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (section.found.isNotEmpty)
                    Text('Has: ${section.found.join(' · ')}'),
                  if (section.missing.isNotEmpty &&
                      section.status != ProfileStatus.complete)
                    Text('Needs: ${section.missing.join(' · ')}'),
                ],
              ),
            ),
            if (section.status != ProfileStatus.complete)
              TextButton(
                key: Key('profile-go-${section.kind.name}'),
                onPressed: slug != null && study.openPanel != null
                    ? () => study.openPanel!(slug)
                    : () => study.openRecord(study.languageId),
                child: Text(slug != null ? 'Go' : 'Open record'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Naming — the Naming Convention Builder
// ---------------------------------------------------------------------------

class NamingPanel extends StatefulWidget {
  const NamingPanel({super.key, required this.study});

  final StudyContext study;

  @override
  State<NamingPanel> createState() => _NamingPanelState();
}

class _NamingPanelState extends State<NamingPanel> {
  String? _editingId;
  final _seed = TextEditingController(text: 'names');
  List<ForgedName>? _forged;

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  List<NamingConvention> get _conventions =>
      widget.study.workspace.conventionsFor(widget.study.languageId);

  Future<void> _create() async {
    final study = widget.study;
    final convention = NamingConvention(
      id: 'convention-${DateTime.now().microsecondsSinceEpoch}',
      name: 'New convention',
      languageId: study.languageId,
      family: const WordShape(
          label: 'Family name', minSyllables: 2, maxSyllables: 3),
    );
    final saved =
        await study.commit(study.workspace.withConvention(convention));
    if (saved && mounted) setState(() => _editingId = convention.id);
  }

  /// Given names of this language's own speakers, for patronymics built from
  /// the author's cast rather than from strangers.
  List<String> get _castGivenNames => [
        for (final name in widget.study.snapshot.names)
          if (name.languageId == widget.study.languageId)
            for (final (:word, start: _) in wordsIn(name.name).take(1)) word,
      ];

  void _forge(NamingConvention convention) {
    final phonology = widget.study.phonology;
    if (phonology == null) return;
    final phrase = _seed.text.trim().isEmpty ? 'names' : _seed.text.trim();
    setState(() {
      _forged = NameForge.generate(
        convention,
        phonology,
        GenerationSeed.phrase(phrase),
        count: 8,
        parents: _castGivenNames,
        exclude: widget.study.snapshot.spellingsIn(widget.study.languageId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final study = widget.study;
    final conventions = _conventions;
    final editing = _editingId == null
        ? null
        : conventions.where((each) => each.id == _editingId).firstOrNull;

    return StudyPanelFrame(
      title: 'Naming conventions',
      subtitle: 'How the peoples who speak ${study.languageTitle} build a '
          'name — so a whole culture sounds related without everyone sounding '
          'the same.',
      actions: [
        if (study.canEdit)
          FilledButton.icon(
            key: const Key('naming-new'),
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('New convention'),
          ),
      ],
      children: [
        if (study.phonology == null)
          const StudyNotice(
            key: Key('naming-needs-sound'),
            icon: Icons.graphic_eq,
            text: 'Names are forged from the sound rules. Conventions can be '
                'written now; set the sounds on the Sound panel to forge them.',
          ),
        if (conventions.isEmpty)
          const StudyNotice(
            key: Key('naming-empty'),
            icon: Icons.badge_outlined,
            text: 'No conventions yet. A convention holds the shape of a '
                'given name and a family name, any patronymic, a noble '
                'particle, and the order they are said in.',
          ),
        for (final convention in conventions)
          Card(
            child: ListTile(
              key: Key('naming-convention-${convention.id}'),
              leading: const Icon(Icons.badge_outlined),
              title: Text(convention.name),
              subtitle: Text(_describe(convention)),
              selected: convention.id == _editingId,
              onTap: () => setState(() {
                _editingId = convention.id;
                _forged = null;
              }),
            ),
          ),
        if (editing != null) ...[
          const SizedBox(height: 12),
          _ConventionEditor(
            key: ValueKey('editor-${editing.id}'),
            convention: editing,
            canEdit: study.canEdit,
            onSave: (next) =>
                study.commit(study.workspace.withConvention(next)),
            onDelete: () async {
              final saved = await study
                  .commit(study.workspace.withoutConvention(editing.id));
              if (saved && mounted) setState(() => _editingId = null);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  key: const Key('naming-seed'),
                  controller: _seed,
                  decoration: const InputDecoration(
                    labelText: 'Seed phrase',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('naming-forge'),
                onPressed:
                    study.phonology == null ? null : () => _forge(editing),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Forge names'),
              ),
            ],
          ),
          if (_forged != null) ...[
            const SizedBox(height: 8),
            if (_forged!.isEmpty)
              const StudyNotice(
                key: Key('naming-none'),
                icon: Icons.info_outline,
                text: 'No name under this convention can be said in this '
                    'language. Check the suffixes against the sound rules.',
              ),
            for (final name in _forged!)
              Card(
                child: ListTile(
                  key: Key('naming-forged-${name.display}'),
                  title: Text(name.display),
                  trailing: IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: name.display)),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  static String _describe(NamingConvention convention) => [
        convention.order.label,
        if (convention.family == null) 'no family name',
        if (convention.parentName != null && !convention.parentName!.isEmpty)
          convention.parentName!.label.isEmpty
              ? 'parent\'s name'
              : convention.parentName!.label,
        if (convention.particle.isNotEmpty) 'particle "${convention.particle}"',
      ].join(' · ');
}

class _ConventionEditor extends StatefulWidget {
  const _ConventionEditor({
    super.key,
    required this.convention,
    required this.canEdit,
    required this.onSave,
    required this.onDelete,
  });

  final NamingConvention convention;
  final bool canEdit;
  final Future<bool> Function(NamingConvention next) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_ConventionEditor> createState() => _ConventionEditorState();
}

class _ConventionEditorState extends State<_ConventionEditor> {
  late final _name = TextEditingController(text: widget.convention.name);
  late final _givenMin = TextEditingController(
      text: '${widget.convention.given.minSyllables ?? 2}');
  late final _givenMax = TextEditingController(
      text: '${widget.convention.given.maxSyllables ?? 3}');
  late final _givenSuffixes =
      TextEditingController(text: widget.convention.given.suffixes.join(', '));
  late bool _hasFamily = widget.convention.family != null;
  late final _familyMin = TextEditingController(
      text: '${widget.convention.family?.minSyllables ?? 2}');
  late final _familyMax = TextEditingController(
      text: '${widget.convention.family?.maxSyllables ?? 3}');
  late final _familySuffixes = TextEditingController(
      text: widget.convention.family?.suffixes.join(', ') ?? '');
  late final _parentLabel =
      TextEditingController(text: widget.convention.parentName?.label ?? '');
  late final _parentPrefix =
      TextEditingController(text: widget.convention.parentName?.prefix ?? '');
  late final _parentSuffix =
      TextEditingController(text: widget.convention.parentName?.suffix ?? '');
  late final _particle =
      TextEditingController(text: widget.convention.particle);
  late final _notes = TextEditingController(text: widget.convention.notes);
  late NameOrder _order = widget.convention.order;

  List<TextEditingController> get _all => [
        _name,
        _givenMin,
        _givenMax,
        _givenSuffixes,
        _familyMin,
        _familyMax,
        _familySuffixes,
        _parentLabel,
        _parentPrefix,
        _parentSuffix,
        _particle,
        _notes,
      ];

  @override
  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
    super.dispose();
  }

  static List<String> _list(String text) => [
        for (final part in text.split(','))
          if (part.trim().isNotEmpty) part.trim().toLowerCase(),
      ];

  static int? _int(String text) => int.tryParse(text.trim());

  NamingConvention get _built {
    final parent = ParentNameRule(
      label: _parentLabel.text.trim(),
      prefix: _parentPrefix.text.trim(),
      suffix: _parentSuffix.text.trim().toLowerCase(),
    );
    return widget.convention.copyWith(
      name: _name.text.trim().isEmpty ? 'Convention' : _name.text.trim(),
      given: WordShape(
        label: 'Given name',
        minSyllables: _int(_givenMin.text),
        maxSyllables: _int(_givenMax.text),
        suffixes: _list(_givenSuffixes.text),
        capitalise: true,
      ),
      family: _hasFamily
          ? WordShape(
              label: 'Family name',
              minSyllables: _int(_familyMin.text),
              maxSyllables: _int(_familyMax.text),
              suffixes: _list(_familySuffixes.text),
              capitalise: true,
            )
          : null,
      clearFamily: !_hasFamily,
      parentName: parent.isEmpty ? null : parent,
      clearParentName: parent.isEmpty,
      particle: _particle.text.trim(),
      order: _order,
      notes: _notes.text.trim(),
    );
  }

  Widget _field(TextEditingController controller, String label, String key,
          {double width = 200, String? hint}) =>
      SizedBox(
        width: width,
        child: TextField(
          key: Key(key),
          controller: controller,
          enabled: widget.canEdit,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_name, 'Convention name', 'naming-name',
                width: 360, hint: 'Coastal nobility'),
            const SizedBox(height: 12),
            Text('Given name', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _field(_givenMin, 'Fewest syllables', 'naming-given-min',
                  width: 140),
              _field(_givenMax, 'Most syllables', 'naming-given-max',
                  width: 140),
              _field(_givenSuffixes, 'Endings, one chosen',
                  'naming-given-suffixes',
                  width: 240, hint: 'eth, iel'),
            ]),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('naming-has-family'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Family names'),
              value: _hasFamily,
              onChanged: widget.canEdit
                  ? (value) => setState(() => _hasFamily = value)
                  : null,
            ),
            if (_hasFamily)
              Wrap(spacing: 12, runSpacing: 12, children: [
                _field(_familyMin, 'Fewest syllables', 'naming-family-min',
                    width: 140),
                _field(_familyMax, 'Most syllables', 'naming-family-max',
                    width: 140),
                _field(_familySuffixes, 'Endings, one chosen',
                    'naming-family-suffixes',
                    width: 240, hint: 'dor, wyn'),
                _field(_particle, 'Noble or place particle', 'naming-particle',
                    width: 200, hint: 'of, von'),
              ]),
            const SizedBox(height: 12),
            Text("A parent's name", style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _field(_parentLabel, 'Called', 'naming-parent-label',
                  width: 180, hint: 'Patronymic'),
              _field(_parentPrefix, 'Word before', 'naming-parent-prefix',
                  width: 140, hint: 'ben'),
              _field(_parentSuffix, 'Ending', 'naming-parent-suffix',
                  width: 140, hint: 'son'),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<NameOrder>(
              key: const Key('naming-order'),
              showSelectedIcon: false,
              segments: [
                for (final order in NameOrder.values)
                  ButtonSegment(value: order, label: Text(order.label)),
              ],
              selected: {_order},
              onSelectionChanged: widget.canEdit
                  ? (selection) => setState(() => _order = selection.single)
                  : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextField(
                key: const Key('naming-notes'),
                controller: _notes,
                enabled: widget.canEdit,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  helperText: 'Adult names, secret names, marriage, rank — '
                      'what the fields cannot say.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  key: const Key('naming-save'),
                  onPressed: () => widget.onSave(_built),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save convention'),
                ),
                TextButton.icon(
                  key: const Key('naming-delete'),
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
