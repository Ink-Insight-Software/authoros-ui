/// The family card draws the portrait its host resolved, and nothing else:
/// the Loom reads no storage and no file system (moved from AOS-Write on
/// October 10, 2026).
library;

import 'dart:convert';

import 'package:authoros_core/story_graph.dart';
import 'package:authoros_ui/loom/family_canvas.dart';
import 'package:authoros_ui/loom/graph_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const node = StoryGraphNode(
    id: 'ada',
    kind: StoryGraphNodeKind.record,
    typeId: 'character',
    categoryId: 'people',
    title: 'Ada Cruz',
    projectId: 'world',
    versioned: true,
    deletable: true,
  );

  Future<void> pump(WidgetTester tester, {ImageProvider? portrait}) async {
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: kFamilyNodeWidth,
              height: kFamilyNodeHeight,
              child: FamilyNodeCard(
                node: node,
                palette: GraphPalette.fromTheme(theme),
                ringColour: Colors.teal,
                isRoot: true,
                isSelected: false,
                portrait: portrait,
                onPickPhoto: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('with no portrait it offers to add one', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('a portrait the host resolved is drawn and can be changed',
      (tester) async {
    // A one-pixel PNG: real image data, so the ring decodes it.
    final portrait = MemoryImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    ));
    await pump(tester, portrait: portrait);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    final ring = tester.widgetList<Container>(find.byType(Container)).where(
          (c) => (c.decoration as BoxDecoration?)?.image?.image == portrait,
        );
    expect(ring, hasLength(1));
  });

  test('the palette resolves from any Material theme', () {
    final theme = ThemeData.dark();
    final palette = GraphPalette.fromTheme(
      theme,
      lineages: const [Colors.red, Colors.blue],
    );
    expect(palette.primary, theme.colorScheme.primary);
    expect(palette.selection, theme.colorScheme.primaryContainer);
    expect(palette.label.color, theme.colorScheme.onSurfaceVariant);
    expect(palette.title.color, theme.colorScheme.onSurface);
    expect(palette.lineages, const [Colors.red, Colors.blue]);
  });
}
