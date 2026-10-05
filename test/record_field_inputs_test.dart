import 'package:authoros_core/civilisation_record_types.dart';
import 'package:authoros_core/record_types.dart';
import 'package:authoros_ui/option_label.dart';
import 'package:authoros_ui/record_field_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RecordFieldDefinition _field(
  String id,
  RecordFieldType type, {
  int order = 0,
  List<String> options = const [],
  String? optionSetId,
  Map<String, String> optionDescriptions = const {},
}) =>
    RecordFieldDefinition(
      id: id,
      label: id,
      type: type,
      order: order,
      options: options,
      optionSetId: optionSetId,
      optionDescriptions: optionDescriptions,
    );

void main() {
  late Map<String, Object?> reported;

  Future<void> pump(
    WidgetTester tester,
    List<RecordFieldDefinition> fields, {
    Map<String, Object?> values = const {},
    RecordTypeDefinition? definition,
    List<RecordFieldDefinition> Function(
      List<RecordFieldDefinition>,
      Map<String, Object?>,
    )? offer,
  }) async {
    reported = {...values};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordFieldInputs(
              fields: fields,
              values: values,
              definition: definition,
              offer: offer,
              onChanged: (next) => reported = next,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('text is reported as typed, and cleared text is absent',
      (tester) async {
    await pump(tester, [_field('name', RecordFieldType.shortText)]);
    await tester.enterText(find.byKey(const Key('field-name')), 'Aster');
    expect(reported, {'name': 'Aster'});
    await tester.enterText(find.byKey(const Key('field-name')), '');
    expect(reported, isEmpty);
  });

  testWidgets('a number is stored as a number, and a year in a date too',
      (tester) async {
    await pump(tester, [
      _field('count', RecordFieldType.number),
      _field('rose', RecordFieldType.date, order: 1),
    ]);
    await tester.enterText(find.byKey(const Key('field-count')), '12');
    await tester.enterText(find.byKey(const Key('field-rose')), '405');
    expect(reported, {'count': 12, 'rose': 405});
  });

  testWidgets('a list is one entry per line', (tester) async {
    await pump(tester, [_field('names', RecordFieldType.list)]);
    await tester.enterText(
      find.byKey(const Key('field-names')),
      'The Old Ones\n\n  Hill folk \n',
    );
    expect(reported, {
      'names': ['The Old Ones', 'Hill folk'],
    });
  });

  testWidgets('a boolean stores off as false, not as absent', (tester) async {
    await pump(
      tester,
      [_field('extinct', RecordFieldType.boolean)],
      values: {'extinct': true},
    );
    await tester.tap(find.byKey(const Key('field-extinct')));
    expect(reported, {'extinct': false});
  });

  testWidgets('choices from an option set resolve through the definition',
      (tester) async {
    final definition = CivilisationRecordTypes.definitions.single;
    final standing =
        definition.fields.singleWhere((field) => field.id == 'standing');
    await pump(tester, [standing], definition: definition);
    await tester.tap(find.byKey(const Key('field-standing')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Declining').last);
    await tester.pumpAndSettle();
    expect(reported, {'standing': 'Declining'});
  });

  testWidgets('without the definition, a set-backed choice is named as '
      'unsupported and its value kept', (tester) async {
    final definition = CivilisationRecordTypes.definitions.single;
    final standing =
        definition.fields.singleWhere((field) => field.id == 'standing');
    await pump(tester, [standing], values: {'standing': 'Rising'});
    expect(find.byKey(const Key('field-standing')), findsNothing);
    expect(find.textContaining('not editable here yet'), findsOneWidget);
    expect(reported, {'standing': 'Rising'});
  });

  testWidgets('an option explains itself in the open list', (tester) async {
    await pump(tester, [
      _field(
        'turn',
        RecordFieldType.singleChoice,
        options: ['reversal', 'crisis'],
        optionDescriptions: {'reversal': 'Fortune turns over.'},
      ),
    ]);
    await tester.tap(find.byKey(const Key('field-turn')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OptionLabel && widget.describe == 'Fortune turns over.',
      ),
      findsWidgets,
    );
  });

  testWidgets('a field this cannot edit is named, never dropped',
      (tester) async {
    await pump(
      tester,
      [
        _field('crest', RecordFieldType.image),
        _field('motto', RecordFieldType.shortText, order: 1),
      ],
      values: {'crest': 'crest.png'},
    );
    expect(find.text('crest is not editable here yet. Its current value is '
        'kept.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-motto')), 'Endure');
    expect(reported, {'crest': 'crest.png', 'motto': 'Endure'});
  });

  testWidgets('offer narrows the fields and is shown what is stored',
      (tester) async {
    final seen = <Map<String, Object?>>[];
    await pump(
      tester,
      [
        _field('free', RecordFieldType.shortText),
        _field('kept', RecordFieldType.shortText, order: 1),
        _field('withheld', RecordFieldType.shortText, order: 2),
      ],
      values: {'kept': 'written'},
      offer: (configured, stored) {
        seen.add(stored);
        return [
          for (final field in configured)
            if (field.id == 'free' || stored.containsKey(field.id)) field,
        ];
      },
    );
    expect(find.byKey(const Key('field-free')), findsOneWidget);
    expect(find.byKey(const Key('field-kept')), findsOneWidget);
    expect(find.byKey(const Key('field-withheld')), findsNothing);
    expect(seen.last, {'kept': 'written'});

    // Cleared this session, the field stays: offer sees the seeded value too.
    await tester.enterText(find.byKey(const Key('field-kept')), '');
    await tester.pump();
    expect(find.byKey(const Key('field-kept')), findsOneWidget);
  });

  testWidgets('hidden and disabled fields are not offered', (tester) async {
    await pump(tester, [
      const RecordFieldDefinition(
        id: 'hidden',
        label: 'hidden',
        type: RecordFieldType.shortText,
        order: 0,
        hidden: true,
      ),
      const RecordFieldDefinition(
        id: 'off',
        label: 'off',
        type: RecordFieldType.shortText,
        order: 1,
        enabled: false,
      ),
    ]);
    expect(find.byType(TextFormField), findsNothing);
  });
}
