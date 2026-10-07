import 'package:authoros_core/hidden_truth.dart';
import 'package:authoros_core/record_types.dart';
import 'package:authoros_ui/field_with_truth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _name = RecordFieldDefinition(
  id: 'demonym',
  label: 'Name for its people',
  type: RecordFieldType.shortText,
  order: 0,
);

void main() {
  late Map<String, Object?> stored;

  Future<void> show(
    WidgetTester tester, {
    bool open = true,
    VoidCallback? onLocked,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FieldWithTruth(
                field: _name,
                fields: () => stored,
                onEdit: (fields) => setState(() => stored = fields),
                keyPrefix: 'p',
                truthsOpen: open,
                onLocked: onLocked,
              ),
            ),
          ),
        ),
      );

  setUp(() => stored = {'demonym': 'Vaelin', 'standing': 'Rising'});

  testWidgets('a truth is added beside the field, and removed', (tester) async {
    await show(tester);
    expect(find.byKey(const Key('p-truth-demonym')), findsNothing);
    await tester.tap(find.byKey(const Key('p-truth-add-demonym')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('p-truth-demonym')),
      'The Drowned',
    );
    await tester.pump();
    expect(HiddenTruths.truthOf(stored, 'demonym'), 'The Drowned');
    expect(stored['demonym'], 'Vaelin');
    expect(stored['standing'], 'Rising');
    expect(find.text('The record says otherwise.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('p-truth-remove-demonym')));
    await tester.pump();
    expect(HiddenTruths.has(stored, 'demonym'), isFalse);
    expect(stored.containsKey(HiddenTruths.key), isFalse);
  });

  testWidgets('editing the field keeps its truth and the other fields',
      (tester) async {
    stored = HiddenTruths.withTruth(stored, 'demonym', 'The Drowned');
    await show(tester);
    await tester.enterText(find.byKey(const Key('p-field-demonym')), 'Vael');
    await tester.pump();
    expect(stored['demonym'], 'Vael');
    expect(stored['standing'], 'Rising');
    expect(HiddenTruths.truthOf(stored, 'demonym'), 'The Drowned');
  });

  testWidgets('locked, Add says so and adds nothing', (tester) async {
    var asked = 0;
    await show(tester, open: false, onLocked: () => asked++);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('p-truth-add-demonym')));
    await tester.pump();
    expect(asked, 1);
    expect(find.byKey(const Key('p-truth-demonym')), findsNothing);
  });

  testWidgets('a truth already written stays shown and editable while locked',
      (tester) async {
    stored = HiddenTruths.withTruth(stored, 'demonym', 'The Drowned');
    await show(tester, open: false, onLocked: () {});
    expect(find.byKey(const Key('p-truth-demonym')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('p-truth-demonym')),
      'The Drowned Kings',
    );
    await tester.pump();
    expect(HiddenTruths.truthOf(stored, 'demonym'), 'The Drowned Kings');
  });

  test('truths sit beside fields said in words, not beside references', () {
    expect(FieldWithTruth.takesTruth(_name), isTrue);
    expect(
      FieldWithTruth.takesTruth(const RecordFieldDefinition(
        id: 'ruler',
        label: 'Ruler',
        type: RecordFieldType.recordReference,
        order: 0,
      )),
      isFalse,
    );
  });
}
