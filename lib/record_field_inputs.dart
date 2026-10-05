/// Inputs for a list of [RecordFieldDefinition]s, and the values they collect.
///
/// **The one renderer for record fields that AuthorOS Write and AOS Worldsmith
/// share.** It moved here from AOS-Write's `lib/ui/record_field_inputs.dart`
/// on October 5, 2026. That file had recorded itself as the third copy of
/// field rendering and asked whoever came to add a fourth to extract instead;
/// Worldsmith's record pages were the fourth, and this package is the
/// extraction. AOS-Write keeps a thin wrapper of the same name, which applies
/// its field ownership through [RecordFieldInputs.offer].
///
/// It takes field definitions and values and gives edited values back, so
/// anything holding a `Map<String, Object?>` keyed by field id can use it:
/// connection metadata, a record page, a board.
///
/// ## What it will not do
///
/// Short and long text, rich text, number, rating, date, boolean, single
/// choice, list, and — when the caller supplies candidates — record
/// references. The rest, images and tables above all, are **named as
/// unsupported in the UI** rather than silently dropped, because a
/// deterministic tool states what it cannot do (AuthorOS architecture lock,
/// Lock 8). A field this cannot edit keeps whatever value it already had.
///
/// It reads no database: a reference offers only what
/// [RecordFieldInputs.references] was given.
library;

import 'package:flutter/material.dart';

import 'package:authoros_core/record_types.dart';

import 'option_label.dart';

/// One record a reference field may point at: what to store, and what to show.
@immutable
class RecordReferenceOption {
  const RecordReferenceOption({required this.id, required this.title});

  /// The record id, which is what the field stores.
  final String id;

  /// What the author reads in the list. A record's title, and never its id:
  /// an id is how the graph resolves a link and has never been how a person
  /// recognises one.
  final String title;
}

/// Inputs for [fields], seeded from [values], reporting every edit.
class RecordFieldInputs extends StatefulWidget {
  const RecordFieldInputs({
    super.key,
    required this.fields,
    required this.values,
    required this.onChanged,
    this.keyPrefix = 'field',
    this.references = const {},
    this.definition,
    this.offer,
  });

  /// What may be written. A disabled field is not offered, matching
  /// `RecordValidator` and `ConnectionTypeRegistry`, both of which skip one.
  final List<RecordFieldDefinition> fields;

  /// What is written now, keyed by field id.
  final Map<String, Object?> values;

  /// The record type [fields] belong to, when there is one.
  ///
  /// With it, a choice field's options and their explanations resolve through
  /// the type's option sets ([RecordTypeDefinition.optionsFor]); without it,
  /// only the options a field lists inline are offered. A field whose options
  /// come from a set, and that is shown with no definition, has nothing to
  /// choose from and reports as unsupported.
  final RecordTypeDefinition? definition;

  /// Which of the configured fields this caller may offer, given what is
  /// stored, or null to offer them all.
  ///
  /// Called with the enabled, visible fields in order and with the stored
  /// values: the seeded ones **and** the ones edited this session, as one map.
  /// AOS-Write applies its field ownership here (its `resolveFields`, M1b):
  /// a field with a stored value is never withheld, so the values have to
  /// arrive with the fields. Ownership is AOS-Write's and stays there; this
  /// widget knows only that something may narrow the list.
  final List<RecordFieldDefinition> Function(
    List<RecordFieldDefinition> configured,
    Map<String, Object?> storedValues,
  )? offer;

  /// Called with the complete value map after every edit.
  ///
  /// A field left empty is **absent from the map**, not present and empty. An
  /// end date on a relationship that has not ended should not be stored as
  /// `''` — the validator treats empty as absent, and so should what reaches
  /// it.
  final ValueChanged<Map<String, Object?>> onChanged;

  /// Prefix for the widget key on each input, so a caller's tests can find
  /// them: `<prefix>-<fieldId>`.
  final String keyPrefix;

  /// What a record reference may point at, keyed by field id.
  ///
  /// Supplied by the caller rather than read here, which is the line this
  /// widget has kept since it was written: it takes definitions and values and
  /// gives values back, and it opens no database to do it. A reference field
  /// with no entry here reports as unsupported exactly as it did before, so a
  /// caller that cannot offer candidates is no worse off than one that never
  /// asked.
  final Map<String, List<RecordReferenceOption>> references;

  @override
  State<RecordFieldInputs> createState() => _RecordFieldInputsState();
}

class _RecordFieldInputsState extends State<RecordFieldInputs> {
  final _controllers = <String, TextEditingController>{};
  late Map<String, Object?> _values = {...widget.values};

  @override
  void didUpdateWidget(RecordFieldInputs oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The field list changes when the caller picks a different connection
    // type. Values for fields the new type does not declare are dropped here
    // rather than carried along, because the registry refuses an undeclared
    // key and the author never asked for it.
    if (!identical(oldWidget.fields, widget.fields)) {
      final declared = {for (final field in widget.fields) field.id};
      _values = {
        for (final entry in _values.entries)
          if (declared.contains(entry.key)) entry.key: entry.value,
      };
      for (final id in _controllers.keys.toList()) {
        if (declared.contains(id)) continue;
        _controllers.remove(id)!.dispose();
      }
      for (final entry in _controllers.entries) {
        entry.value.text = _values[entry.key]?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(RecordFieldDefinition field) =>
      _controllers.putIfAbsent(
        field.id,
        () => TextEditingController(text: _values[field.id]?.toString() ?? ''),
      );

  void _set(String id, Object? value) {
    setState(() {
      // Absent, not empty. See [RecordFieldInputs.onChanged].
      if (recordFieldIsEmpty(value)) {
        _values.remove(id);
      } else {
        _values[id] = value;
      }
    });
    widget.onChanged({..._values});
  }

  @override
  Widget build(BuildContext context) {
    // Three layers, in order, and the order is the design: the template says
    // what exists, the author's own configuration says what applies here, and
    // the caller's [RecordFieldInputs.offer] says what they may reach. It goes
    // last so a project configuration cannot enable its way past it.
    final configured = [
      for (final field in widget.fields)
        if (field.enabled && !field.hidden) field,
    ]..sort((left, right) => left.order.compareTo(right.order));

    // Seeded values **and** live ones, and the union rather than either alone.
    // A [RecordFieldInputs.offer] that keeps a field for its stored value
    // reads this, so the choice decides whether a field can disappear under
    // the author's cursor:
    //
    //   * `_values` alone: an author who clears a field kept only for what was
    //     written in it watches the field vanish mid-edit.
    //   * `widget.values` alone: a field typed into for the first time this
    //     session would not be kept if the reason it was offered went away.
    //
    // The union is monotone within a session: a field can become offered and
    // can never stop being.
    final offer = widget.offer;
    final offered = offer == null
        ? configured
        : offer(configured, {...widget.values, ..._values});
    if (offered.isEmpty) return const SizedBox.shrink();

    final unsupported = <String>[];
    final inputs = <Widget>[];
    for (final field in offered) {
      final input = _inputFor(field);
      if (input == null) {
        unsupported.add(field.label);
        continue;
      }
      inputs.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: input,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...inputs,
        if (unsupported.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              // Named rather than omitted: a field that silently vanishes reads
              // as a field that does not exist.
              unsupported.length == 1
                  ? '${unsupported.single} is not editable here yet. Its '
                      'current value is kept.'
                  : '${unsupported.join(', ')} are not editable here yet. '
                      'Their current values are kept.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  List<String> _optionsFor(RecordFieldDefinition field) =>
      widget.definition?.optionsFor(field) ?? field.options;

  String _describe(RecordFieldDefinition field, String option) =>
      widget.definition?.optionDescriptionsFor(field)[option] ??
      field.describeOption(option);

  Widget? _inputFor(RecordFieldDefinition field) {
    final inputKey = Key('${widget.keyPrefix}-${field.id}');
    final helper = field.description.isEmpty ? null : field.description;
    switch (field.type) {
      case RecordFieldType.boolean:
        return SwitchListTile(
          key: inputKey,
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: helper == null ? null : Text(helper),
          value: _values[field.id] == true,
          // A boolean has no empty — off is a value, and `false` is what the
          // author means by it. `recordFieldIsEmpty(false)` is false, so `_set`
          // stores it rather than dropping the key.
          onChanged: (value) => _set(field.id, value),
        );

      case RecordFieldType.singleChoice:
        final options = _optionsFor(field);
        if (options.isEmpty) return null;
        final current = _values[field.id];
        return DropdownButtonFormField<String>(
          key: inputKey,
          initialValue: options.contains(current) ? current as String : null,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: helper,
          ),
          // `selectedItemBuilder` keeps the closed field showing the option
          // alone. Without it the chosen row would carry its explanation into
          // a one-line box and be clipped — the help belongs in the open list,
          // where the author is deciding.
          selectedItemBuilder: (context) => [
            for (final option in options)
              Align(alignment: Alignment.centerLeft, child: Text(option)),
          ],
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: OptionLabel(
                  option: option,
                  describe: _describe(field, option),
                ),
              ),
          ],
          onChanged: (value) => _set(field.id, value),
        );

      case RecordFieldType.number:
      case RecordFieldType.rating:
        return TextFormField(
          key: inputKey,
          controller: _controllerFor(field),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: helper,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Parsed, not stored as text: the field is declared a number, and
          // the registry now type-checks it. Unparseable input is passed
          // through so validation reports it rather than this silently
          // discarding what was typed.
          onChanged: (text) =>
              _set(field.id, num.tryParse(text.trim()) ?? text),
        );

      // `dateRange` is deliberately absent: it is two moments, and one text
      // box would be a lie about what was stored. Nothing in the built-in
      // connection vocabulary declares one, so it reports as unsupported.
      case RecordFieldType.date:
        return TextFormField(
          key: inputKey,
          controller: _controllerFor(field),
          decoration: InputDecoration(
            labelText: field.label,
            // A date here is whatever the world's calendar is — `MapWorldClock`
            // reads a year, an ISO date, or a structured moment — so this is a
            // text box rather than a date picker, which would insist on ours.
            helperText: helper ??
                'A year, a date, or however this world '
                    'tells the time.',
          ),
          onChanged: (text) {
            final trimmed = text.trim();
            final year = num.tryParse(trimmed);
            _set(field.id, year ?? trimmed);
          },
        );

      case RecordFieldType.longText:
      case RecordFieldType.richText:
        return TextFormField(
          key: inputKey,
          controller: _controllerFor(field),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: helper,
          ),
          maxLines: 3,
          minLines: 2,
          onChanged: (text) => _set(field.id, text),
        );

      case RecordFieldType.shortText:
      case RecordFieldType.url:
        return TextFormField(
          key: inputKey,
          controller: _controllerFor(field),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: helper,
          ),
          onChanged: (text) => _set(field.id, text),
        );

      case RecordFieldType.list:
        // One per line, which is how an author already writes a list into a
        // box: festivals, fasts, closures. Stored as a `List<String>` because
        // that is what the field declares — a newline-joined string would be
        // this widget deciding the storage shape on the way past.
        return TextFormField(
          key: inputKey,
          controller: _controllerFor(field),
          decoration: InputDecoration(
            labelText: field.label,
            helperText: helper == null
                ? 'One per line.'
                : '$helper One per '
                    'line.',
          ),
          maxLines: 4,
          minLines: 2,
          onChanged: (text) => _set(
            field.id,
            [
              for (final line in text.split('\n'))
                if (line.trim().isNotEmpty) line.trim(),
            ],
          ),
        );

      case RecordFieldType.recordReference:
        final candidates = widget.references[field.id];
        // No candidates is not an empty dropdown: an author staring at a
        // control with nothing in it cannot tell whether they have no
        // calendars or whether this screen cannot see them. It reports as
        // unsupported, which says the second thing truthfully.
        if (candidates == null || candidates.isEmpty) return null;
        final current = _values[field.id];
        final ids = {for (final option in candidates) option.id};
        return DropdownButtonFormField<String>(
          key: inputKey,
          initialValue: ids.contains(current) ? current as String : null,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: helper,
          ),
          items: [
            for (final option in candidates)
              DropdownMenuItem(value: option.id, child: Text(option.title)),
          ],
          onChanged: (value) => _set(field.id, value),
        );

      // Everything else — images, tables, tags, date ranges. Reported by the
      // caller rather than rendered wrong.
      default:
        return null;
    }
  }
}
