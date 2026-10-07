import 'package:authoros_core/hidden_truth.dart';
import 'package:authoros_core/record_types.dart';
import 'package:flutter/material.dart';

import 'record_field_inputs.dart';

/// One field and, where the author wants one, the truth behind it
/// (`HiddenTruths`, `_truth.values`): what the record says, and what is
/// really so.
///
/// Moved here from AOS-Write's bible pages (October 7, 2026) so AOS
/// Worldsmith's record pages edit a civilisation's public identity and its
/// hidden reality with the same widget, not a second copy of it.
///
/// **Who may add a truth is the caller's to say.** AOS-Write sells hidden
/// truths with Codex Bibles, and so does Worldsmith; neither ownership model
/// lives here. [truthsOpen] says whether a new truth may be added and
/// [onLocked] is what a locked *Add* does instead. A truth already written is
/// always shown and editable, open or not: what an author wrote is never
/// withheld.
class FieldWithTruth extends StatefulWidget {
  const FieldWithTruth({
    super.key,
    required this.field,
    required this.fields,
    required this.onEdit,
    this.keyPrefix = 'bible',
    this.truthsOpen = true,
    this.onLocked,
    this.definition,
    this.offer,
  });

  final RecordFieldDefinition field;

  /// The record's whole field map as it stands now, truths included. Read on
  /// every build and every edit, so edits to other fields are never lost.
  final Map<String, Object?> Function() fields;

  /// Called with the whole field map after every edit, to the field or to
  /// its truth.
  final ValueChanged<Map<String, Object?>> onEdit;

  /// Prefix for the keys: `<prefix>-field-<id>` on the input,
  /// `<prefix>-truth-<id>`, `<prefix>-truth-add-<id>` and
  /// `<prefix>-truth-remove-<id>` on the truth.
  final String keyPrefix;

  /// Whether a new truth may be added.
  final bool truthsOpen;

  /// What a locked *Add the hidden truth* does: say what sells it, in
  /// practice. Ignored while [truthsOpen].
  final VoidCallback? onLocked;

  /// Passed to [RecordFieldInputs].
  final RecordTypeDefinition? definition;

  /// Passed to [RecordFieldInputs].
  final List<RecordFieldDefinition> Function(
    List<RecordFieldDefinition> configured,
    Map<String, Object?> storedValues,
  )? offer;

  /// Field types a hidden truth can sit beside: anything said in words.
  static bool takesTruth(RecordFieldDefinition field) => const {
        RecordFieldType.shortText,
        RecordFieldType.longText,
        RecordFieldType.richText,
        RecordFieldType.number,
        RecordFieldType.date,
        RecordFieldType.singleChoice,
        RecordFieldType.list,
        RecordFieldType.tags,
      }.contains(field.type);

  @override
  State<FieldWithTruth> createState() => _FieldWithTruthState();
}

class _FieldWithTruthState extends State<FieldWithTruth> {
  late bool open = HiddenTruths.has(widget.fields(), widget.field.id);

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final fields = widget.fields();
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.68);
    final truth = HiddenTruths.truthOf(fields, field.id);
    final differs = HiddenTruths.differs(fields, field.id);
    final prefix = widget.keyPrefix;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecordFieldInputs(
            fields: [field],
            values: {
              if (fields[field.id] != null) field.id: fields[field.id],
            },
            keyPrefix: '$prefix-field',
            definition: widget.definition,
            offer: widget.offer,
            onChanged: (values) {
              final next = {...widget.fields()}..remove(field.id);
              widget.onEdit({...next, ...values});
            },
          ),
          if (FieldWithTruth.takesTruth(field))
            if (open)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.7),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: Key('$prefix-truth-${field.id}'),
                        initialValue: truth == null ? '' : '$truth',
                        minLines: 1,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'The truth (for you)',
                          helperText: differs
                              ? 'The record says otherwise.'
                              : 'What is really so, if the record lies.',
                          prefixIcon: Icon(
                            Icons.visibility_off_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ),
                        onChanged: (value) {
                          widget.onEdit(HiddenTruths.withTruth(
                            widget.fields(),
                            field.id,
                            value,
                          ));
                          setState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      key: Key('$prefix-truth-remove-${field.id}'),
                      tooltip: 'Remove the hidden truth',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        widget.onEdit(HiddenTruths.withTruth(
                          widget.fields(),
                          field.id,
                          null,
                        ));
                        setState(() => open = false);
                      },
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('$prefix-truth-add-${field.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: muted,
                  ),
                  onPressed: widget.truthsOpen
                      ? () => setState(() => open = true)
                      : widget.onLocked,
                  icon: Icon(
                    widget.truthsOpen
                        ? Icons.visibility_off_outlined
                        : Icons.lock_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('Add the hidden truth'),
                ),
              ),
        ],
      ),
    );
  }
}
