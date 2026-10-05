/// One option in a chooser, with what it means underneath.
///
/// The rendering half of `RecordFieldDefinition.optionDescriptions` — the
/// fourth Lock 4 capability. A field-level description covers the field; this
/// covers the several different things the field offers, which is where a term
/// of art actually needs explaining. An author choosing between *reversal* and
/// *crisis* is not helped by a sentence about the field.
///
/// It lives in its own file because several builders draw choice fields —
/// `record_field_inputs.dart` here, and AOS-Write's Character, Codex and World
/// workspaces — and a widget owned by one of them would be an odd thing for
/// the others to import. It moved here from AOS-Write's `lib/ui/` with
/// [RecordFieldInputs](record_field_inputs.dart) on October 5, 2026.
library;

import 'package:flutter/material.dart';

/// An option, and its explanation when it has one.
///
/// Renders the option alone when nothing describes it, so a list where two
/// entries are terms of art and the rest are self-evident does not grow a
/// blank second line for every one of them.
class OptionLabel extends StatelessWidget {
  const OptionLabel({super.key, required this.option, required this.describe});

  final String option;

  /// What the option means, or empty.
  final String describe;

  @override
  Widget build(BuildContext context) {
    if (describe.isEmpty) return Text(option);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(option),
        Text(
          describe,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
