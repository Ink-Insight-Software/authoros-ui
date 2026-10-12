/// A host chooses how a family is drawn: portrait cards or compact marks,
/// a colour of its own for particular people, and the line under a name.
library;

import 'package:authoros_core/connected_domain.dart';
import 'package:authoros_core/story_graph.dart';
import 'package:authoros_ui/loom/family_canvas.dart';
import 'package:authoros_ui/loom/family_tree.dart';
import 'package:authoros_ui/loom/graph_canvas.dart';
import 'package:authoros_ui/loom/graph_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 10, 12);

StoryGraphNode _person(String id) => StoryGraphNode.fromRecord(
      AuthorRecord(
        id: id,
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: 'w',
        projectId: 'w',
        title: id,
        fields: {'identity.dateOfBirth': '1900'},
        createdAt: _at,
        updatedAt: _at,
      ),
      categoryId: 'characters',
    );

StoryGraphEdge _edge(String source, String target, String typeId) =>
    StoryGraphEdge(
      link: RecordLink(
        id: '$source-$typeId-$target',
        sourceId: source,
        targetId: target,
        typeId: typeId,
        scopeId: 'w',
        direction: typeId == 'partnerOf'
            ? RecordLinkDirection.undirected
            : RecordLinkDirection.directed,
        createdAt: _at,
        updatedAt: _at,
      ),
      inverseLabel: '',
      wildcard: false,
    );

final _family = StorySubgraph(
  nodes: [_person('Ada'), _person('Bram'), _person('Cora')],
  edges: [
    _edge('Ada', 'Bram', 'partnerOf'),
    _edge('Ada', 'Cora', 'parentOf'),
    _edge('Bram', 'Cora', 'parentOf'),
  ],
  depthReached: 0,
  truncated: false,
);

Future<void> _pump(
  WidgetTester tester, {
  FamilyNodeStyle style = FamilyNodeStyle.portrait,
  Map<String, Color> ringColours = const {},
  Map<String, String> captions = const {},
  ValueChanged<StoryGraphNode>? onTap,
  ValueChanged<StoryGraphNode>? onOpen,
  VoidCallback? onBackground,
}) async {
  final theme = ThemeData.light();
  final family = FamilyStructure.from(_family);
  final positions = familyPositions(family);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      // Small type: the test font is taller than a card's text is drawn in.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.5),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: GraphCanvas(
            subgraph: _family,
            family: family,
            positions: positions,
            projection: const GraphProjection(
              size: Size(800, 600),
            ).fitted(positions.values),
            palette: GraphPalette.fromTheme(
              theme,
              lineages: const [Colors.teal],
            ),
            familyNodeStyle: style,
            ringColours: ringColours,
            captions: captions,
            onNodeTap: onTap,
            onNodeOpen: onOpen,
            onBackgroundTap: onBackground,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('portraits by default, with the lifespan under each name', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(FamilyNodeCard), findsNWidgets(3));
    expect(find.byKey(const Key('family-marks')), findsNothing);
    expect(find.text('1900 - Present'), findsNWidgets(3));
  });

  testWidgets('a caption the host gives replaces the lifespan', (tester) async {
    await _pump(tester, captions: {'Cora': 'House Vell'});
    expect(find.text('House Vell'), findsOneWidget);
    expect(find.text('1900 - Present'), findsNWidgets(2));
  });

  testWidgets(
      'a colour the host gives replaces the line\'s, on the ring '
      'and the lines drawn from that person', (tester) async {
    await _pump(tester, ringColours: {'Cora': Colors.purple});
    final cora = tester.widget<FamilyNodeCard>(
      find.descendant(
        of: find.byKey(const Key('graph-node-Cora')),
        matching: find.byType(FamilyNodeCard),
      ),
    );
    expect(cora.ringColour, Colors.purple);
    final ada = tester.widget<FamilyNodeCard>(
      find.descendant(
        of: find.byKey(const Key('graph-node-Ada')),
        matching: find.byType(FamilyNodeCard),
      ),
    );
    expect(ada.ringColour, Colors.teal);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<FamilyEdgePainter>()
        .single;
    expect(painter.ringColours, {'Cora': Colors.purple});
  });

  testWidgets(
      'compact paints marks, with no widget per person, which '
      'still answer a tap and a double tap', (tester) async {
    StoryGraphNode? tapped;
    StoryGraphNode? opened;
    var background = 0;
    await _pump(
      tester,
      style: FamilyNodeStyle.compact,
      onTap: (node) => tapped = node,
      onOpen: (node) => opened = node,
      onBackground: () => background++,
    );
    expect(find.byType(FamilyNodeCard), findsNothing);
    expect(find.byKey(const Key('graph-node-Ada')), findsNothing);
    expect(find.byKey(const Key('family-marks')), findsOneWidget);

    final canvas = tester.widget<GraphCanvas>(find.byType(GraphCanvas));
    Offset centreOf(String id) =>
        tester.getTopLeft(find.byType(GraphCanvas)) +
        canvas.projection.toCanvas(canvas.positions[id]!);

    await tester.tapAt(centreOf('Cora'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tapped?.id, 'Cora');

    await tester.tapAt(centreOf('Ada') + const Offset(0, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(background, 1);

    await tester.tapAt(centreOf('Bram'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(centreOf('Bram'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened?.id, 'Bram');
  });

  testWidgets('each mark tells a screen reader who it is', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, style: FamilyNodeStyle.compact);
    final labels = <String>[];
    bool visit(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren(visit);
      return true;
    }

    visit(tester.getSemantics(find.byKey(const Key('family-marks'))));
    expect(
        labels, containsAll(['Ada, 1900 - Present', 'Cora, 1900 - Present']));
    semantics.dispose();
  });

  test('a person is found by their footprint, nearest first', () {
    final positions = {'Ada': Offset.zero, 'Bram': const Offset(100, 0)};
    const projection = GraphProjection(size: Size(800, 600));
    StoryGraphNode? at(Offset model) => FamilyMarkPainter.personAt(
          projection.toCanvas(model),
          subgraph: _family,
          positions: positions,
          projection: projection,
        );
    expect(at(const Offset(10, 0))?.id, 'Ada');
    expect(at(const Offset(90, 0))?.id, 'Bram');
    expect(at(const Offset(0, 400)), isNull);
  });
}
