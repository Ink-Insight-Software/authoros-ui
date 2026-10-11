/// A large graph builds only the nodes on its canvas; a small one builds
/// every node, as it always has.
library;

import 'package:authoros_core/story_graph.dart';
import 'package:authoros_ui/loom/graph_canvas.dart';
import 'package:authoros_ui/loom/graph_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StoryGraphNode _node(int i) => StoryGraphNode(
      id: 'n$i',
      kind: StoryGraphNodeKind.record,
      typeId: 'character',
      categoryId: 'people',
      title: 'Node $i',
      projectId: 'world',
      versioned: true,
      deletable: true,
    );

/// [count] nodes in a row, 200 apart, the first in the canvas's centre.
Future<void> _pump(WidgetTester tester, int count) async {
  final theme = ThemeData.light();
  final nodes = [for (var i = 0; i < count; i++) _node(i)];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      // Small type: the test font is taller than a chip's text is drawn
      // in, and what is counted here is nodes, not their lettering.
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
            subgraph: StorySubgraph(
              nodes: nodes,
              edges: const [],
              depthReached: 0,
              truncated: false,
            ),
            positions: {
              for (var i = 0; i < count; i++) 'n$i': Offset(i * 200.0, 0),
            },
            projection: const GraphProjection(size: Size(800, 600)),
            palette: GraphPalette.fromTheme(theme),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a small graph builds every node, on the canvas or not',
      (tester) async {
    await _pump(tester, 10);
    expect(find.byKey(const Key('graph-node-n0')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-n9')), findsOneWidget);
  });

  testWidgets('a large graph builds only the nodes on its canvas',
      (tester) async {
    await _pump(tester, GraphCanvas.cullAbove + 1);
    // The centre is at 400; a node is 132 wide, so n0 to n2 show (n2's left
    // edge is at 734) and n3 (934) does not.
    expect(find.byKey(const Key('graph-node-n0')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-n2')), findsOneWidget);
    expect(find.byKey(const Key('graph-node-n3')), findsNothing);
    expect(
      find.byKey(Key('graph-node-n${GraphCanvas.cullAbove}')),
      findsNothing,
    );
  });
}
