/// The family tree reads descent out of the graph and places it.
///
/// These assert on the *shape* rather than on exact pixels: which generation a
/// person lands on, whether a pair is drawn as a pair, whether a parent sits
/// over the children they had. A spacing constant should be tunable without
/// rewriting the suite; a parent drifting off their own children should not.
library;

import 'package:authoros_core/connected_domain.dart';
import 'package:authoros_core/story_graph.dart';
import 'package:authoros_core/story_graph_modes.dart';
import 'package:authoros_ui/loom/family_tree.dart';
import 'package:authoros_ui/loom/graph_layout.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 27, 12);

StoryGraphNode _person(String id, {String? birth, String? death}) =>
    StoryGraphNode.fromRecord(
      AuthorRecord(
        id: id,
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        projectId: 'project-a',
        title: id,
        fields: {
          if (birth != null) 'identity.dateOfBirth': birth,
          if (death != null) 'identity.dateOfDeath': death,
        },
        createdAt: _timestamp,
        updatedAt: _timestamp,
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
        scopeId: 'project-a',
        direction: typeId == 'partnerOf'
            ? RecordLinkDirection.undirected
            : RecordLinkDirection.directed,
        createdAt: _timestamp,
        updatedAt: _timestamp,
      ),
      inverseLabel: '',
      wildcard: false,
    );

StorySubgraph _subgraph(
  List<StoryGraphNode> nodes,
  List<StoryGraphEdge> edges, {
  String? rootId,
}) =>
    StorySubgraph(
      nodes: nodes,
      edges: edges,
      depthReached: 3,
      truncated: false,
      rootId: rootId,
    );

/// Two grandparents, their two children, one of whom married in a partner and
/// had two children of their own.
StorySubgraph _threeGenerations() => _subgraph(
      [
        _person('grandpa', birth: '1918-04-02', death: '2003-01-09'),
        _person('grandma', birth: '1920-06-11'),
        _person('parent', birth: '1945-02-01', death: '2022-08-30'),
        _person('aunt', birth: '1950-03-04'),
        _person('inlaw', birth: '1946-11-20'),
        _person('kid-elder', birth: '1970-01-01'),
        _person('kid-younger', birth: '1975-05-05'),
      ],
      [
        _edge('grandpa', 'grandma', 'partnerOf'),
        _edge('grandpa', 'parent', 'parentOf'),
        _edge('grandma', 'parent', 'parentOf'),
        _edge('grandpa', 'aunt', 'parentOf'),
        _edge('grandma', 'aunt', 'parentOf'),
        _edge('parent', 'inlaw', 'partnerOf'),
        _edge('parent', 'kid-elder', 'parentOf'),
        _edge('inlaw', 'kid-elder', 'parentOf'),
        _edge('parent', 'kid-younger', 'parentOf'),
        _edge('inlaw', 'kid-younger', 'parentOf'),
      ],
    );

void main() {
  group('reading a family out of the graph', () {
    test('generations follow descent, not distance from the root', () {
      final family = FamilyStructure.from(_threeGenerations());

      expect(family.generations['grandpa'], 0);
      expect(family.generations['grandma'], 0);
      expect(family.generations['parent'], 1);
      expect(family.generations['aunt'], 1);
      expect(family.generations['kid-elder'], 2);
      expect(family.generations['kid-younger'], 2);
    });

    test('a partner who married in is pulled onto their spouse\'s line', () {
      final family = FamilyStructure.from(_threeGenerations());

      // `inlaw` has no parents in the tree, so descent alone would leave them
      // on generation zero — a full line above the person they married.
      expect(family.generations['inlaw'], family.generations['parent']);
    });

    test('a couple is one unit and a lone person is a unit of one', () {
      final family = FamilyStructure.from(_threeGenerations());

      expect(family.coupleFor('grandpa')?.other('grandpa'), 'grandma');
      expect(family.coupleFor('aunt'), isNull);
      expect(family.unitFor('aunt')!.members, ['aunt']);
      expect(family.unitFor('grandpa')!.isCouple, isTrue);
    });

    test('children hang off the couple, not off each parent separately', () {
      final family = FamilyStructure.from(_threeGenerations());
      final unit = family.unitFor('parent')!;

      expect(unit.members, containsAll(['parent', 'inlaw']));
      expect(unit.childUnitKeys, hasLength(2));
      expect(
        unit.childUnitKeys,
        containsAll(['kid-elder', 'kid-younger']),
      );
    });

    test('a founding couple and their whole descent are one line', () {
      final family = FamilyStructure.from(_threeGenerations());

      // Both grandparents married in from outside the drawn tree, so the line
      // is theirs jointly rather than whichever of them sorted first.
      expect(family.lineages['grandma'], family.lineages['grandpa']);
      expect(family.lineages['parent'], family.lineages['grandpa']);
      expect(family.lineages['aunt'], family.lineages['grandpa']);
      expect(family.lineages['kid-elder'], family.lineages['grandpa']);
      expect(
        family.lineageIndexOf('grandma'),
        family.lineageIndexOf('grandpa'),
      );
    });

    test('a grandchild descends through the family, not through the in-law',
        () {
      final family = FamilyStructure.from(_threeGenerations());

      // `inlaw` sorts before `parent`, so picking the first parent by id alone
      // would colour both grandchildren as the in-law's family rather than the
      // one they actually descend from.
      expect(family.parents['kid-elder'], ['inlaw', 'parent']);
      expect(family.lineages['kid-elder'], family.lineages['grandpa']);
      expect(family.lineages['kid-younger'], family.lineages['grandpa']);
      expect(
        family.lineageIndexOf('kid-elder'),
        isNot(family.lineageIndexOf('inlaw')),
      );
    });

    test('someone who married into a line keeps their own', () {
      final family = FamilyStructure.from(_threeGenerations());

      // `inlaw` married a person who already descends from someone here, so
      // they brought a different family in rather than joining this one.
      expect(family.lineages['inlaw'], 'inlaw');
      expect(
        family.lineageIndexOf('inlaw'),
        isNot(family.lineageIndexOf('grandpa')),
      );
    });

    test('non-family edges do not invent a generation', () {
      final subgraph = _subgraph(
        [_person('a'), _person('b')],
        [_edge('a', 'b', 'employs')],
      );
      final family = FamilyStructure.from(subgraph);

      expect(family.hasFamilyEdges, isFalse);
      expect(family.generations['b'], 0);
      expect(family.generations['a'], 0);
    });

    test('a descent cycle in draft data terminates instead of hanging', () {
      final subgraph = _subgraph(
        [_person('a'), _person('b')],
        [_edge('a', 'b', 'parentOf'), _edge('b', 'a', 'parentOf')],
      );

      // The contract is that it returns at all, and returns everyone.
      final positions = familyLayout(subgraph);
      expect(positions.keys, containsAll(['a', 'b']));
    });

    test('a second marriage does not place the same person twice', () {
      final subgraph = _subgraph(
        [_person('a'), _person('b'), _person('c')],
        [
          _edge('a', 'b', 'partnerOf'),
          _edge('a', 'c', 'partnerOf'),
        ],
      );
      final family = FamilyStructure.from(subgraph);

      expect(family.couples, hasLength(1));
      // Every person still gets exactly one place on the page.
      expect(familyLayout(subgraph).keys, hasLength(3));
    });
  });

  group('placing a family', () {
    test('generations sit on their own rows', () {
      final positions = familyLayout(_threeGenerations());

      double rowOf(String id) => positions[id]!.dy;
      expect(rowOf('grandpa'), rowOf('grandma'));
      expect(rowOf('parent'), rowOf('aunt'));
      expect(rowOf('kid-elder'), rowOf('kid-younger'));
      expect(rowOf('grandpa'), lessThan(rowOf('parent')));
      expect(rowOf('parent'), lessThan(rowOf('kid-elder')));
      expect(
        rowOf('parent') - rowOf('grandpa'),
        kFamilyGenerationSpacing,
      );
    });

    test('partners are drawn closer together than neighbours are', () {
      final positions = familyLayout(_threeGenerations());

      final betweenPartners =
          (positions['parent']!.dx - positions['inlaw']!.dx).abs();
      final toTheAunt = (positions['parent']!.dx - positions['aunt']!.dx).abs();

      expect(betweenPartners, kFamilyCoupleSpacing);
      expect(betweenPartners, lessThan(toTheAunt));
    });

    test('a couple sits centred over the children they had', () {
      final positions = familyLayout(_threeGenerations());

      final coupleCentre =
          (positions['parent']!.dx + positions['inlaw']!.dx) / 2;
      final childrenCentre =
          (positions['kid-elder']!.dx + positions['kid-younger']!.dx) / 2;

      expect(coupleCentre, closeTo(childrenCentre, 0.01));
    });

    test('siblings are ordered eldest first', () {
      final positions = familyLayout(_threeGenerations());

      expect(
        positions['kid-elder']!.dx,
        lessThan(positions['kid-younger']!.dx),
      );
      expect(positions['parent']!.dx, lessThan(positions['aunt']!.dx));
    });

    test('nobody overlaps anybody else on their own row', () {
      final positions = familyLayout(_threeGenerations());

      final byRow = <double, List<double>>{};
      for (final position in positions.values) {
        (byRow[position.dy] ??= []).add(position.dx);
      }
      for (final row in byRow.values) {
        row.sort();
        for (var index = 1; index < row.length; index++) {
          expect(
            row[index] - row[index - 1],
            greaterThanOrEqualTo(kFamilyCoupleSpacing - 0.01),
            reason: 'Two people on one row are close enough to collide.',
          );
        }
      }
    });

    test('the same family always lands in the same place', () {
      expect(
          familyLayout(_threeGenerations()), familyLayout(_threeGenerations()));
    });

    test('the tree is centred on the origin', () {
      final positions = familyLayout(_threeGenerations()).values.toList();

      final xs = positions.map((position) => position.dx).toList()..sort();
      final ys = positions.map((position) => position.dy).toList()..sort();

      expect((xs.first + xs.last) / 2, closeTo(0, 0.01));
      expect((ys.first + ys.last) / 2, closeTo(0, 0.01));
    });

    test('an empty graph places nobody', () {
      expect(familyLayout(StorySubgraph.empty), isEmpty);
      expect(FamilyStructure.empty.isEmpty, isTrue);
      expect(familyPositions(FamilyStructure.empty), isEmpty);
    });

    test('the mode routes through the family layout', () {
      final viaMode = layoutSubgraph(
        _threeGenerations(),
        layout: StoryGraphModes.family.layout,
      );

      expect(StoryGraphModes.family.layout, StoryGraphLayout.family);
      expect(viaMode, familyLayout(_threeGenerations()));
    });

    test('a married child is still placed under their own parents', () {
      // The spouse sorts before the child by id, so anything that reaches for
      // "the first member of the child's unit" points the descent line at the
      // in-law instead of the heir.
      final subgraph = _subgraph(
        [_person('zara'), _person('adam'), _person('elder')],
        [
          _edge('elder', 'zara', 'parentOf'),
          _edge('zara', 'adam', 'partnerOf'),
        ],
      );
      final family = FamilyStructure.from(subgraph);

      final unit = family.unitFor('zara')!;
      // Blood descendant first, despite `adam` sorting before `zara`.
      expect(unit.members, ['zara', 'adam']);
      expect(family.parents['zara'], ['elder']);
      expect(family.parents['adam'], isNull);

      // Both halves of the couple sit on the generation below the parent.
      final positions = familyLayout(subgraph);
      expect(positions['zara']!.dy, positions['adam']!.dy);
      expect(positions['elder']!.dy, lessThan(positions['zara']!.dy));
    });

    test('the blood descendant is always on the same side of a couple', () {
      // Two couples where the in-law sorts on opposite sides of the child:
      // `adam` < `zara`, and `wren` > `bela`. Alphabetical ordering would put
      // the family's own child on the left in one and the right in the other.
      final subgraph = _subgraph(
        [
          _person('elder'),
          _person('zara'),
          _person('adam'),
          _person('bela'),
          _person('wren'),
        ],
        [
          _edge('elder', 'zara', 'parentOf'),
          _edge('elder', 'bela', 'parentOf'),
          _edge('zara', 'adam', 'partnerOf'),
          _edge('bela', 'wren', 'partnerOf'),
        ],
      );
      final family = FamilyStructure.from(subgraph);

      expect(family.unitFor('zara')!.members.first, 'zara');
      expect(family.unitFor('bela')!.members.first, 'bela');

      // And that consistency reaches the page: both children sit left of the
      // person they married.
      final positions = familyLayout(subgraph);
      expect(positions['zara']!.dx, lessThan(positions['adam']!.dx));
      expect(positions['bela']!.dx, lessThan(positions['wren']!.dx));
    });

    test('a founding couple with no descent falls back to a stable order', () {
      // Neither partner descends from anyone drawn, so nothing distinguishes
      // them; the id keeps the result from moving between runs.
      final subgraph = _subgraph(
        [_person('zoe'), _person('abe')],
        [_edge('zoe', 'abe', 'partnerOf')],
      );

      expect(
        FamilyStructure.from(subgraph).unitFor('zoe')!.members,
        ['abe', 'zoe'],
      );
    });

    test('siblings order by their own birth date, not their spouse\'s', () {
      // `aaron` is the elder sibling's spouse and was born long before the
      // younger sibling, so ordering a couple by whoever sorts first would put
      // the younger sibling's family on the wrong side.
      final subgraph = _subgraph(
        [
          _person('elder-parent', birth: '1940'),
          _person('firstborn', birth: '1965'),
          _person('aaron', birth: '1999'),
          _person('secondborn', birth: '1970'),
        ],
        [
          _edge('elder-parent', 'firstborn', 'parentOf'),
          _edge('elder-parent', 'secondborn', 'parentOf'),
          _edge('firstborn', 'aaron', 'partnerOf'),
        ],
      );

      final positions = familyLayout(subgraph);
      expect(positions['firstborn']!.dx, lessThan(positions['secondborn']!.dx));
    });

    test('placement survives a person nobody is related to', () {
      final base = _threeGenerations();
      final subgraph = _subgraph(
        [...base.nodes, _person('stranger')],
        base.edges,
      );

      final positions = familyLayout(subgraph);
      expect(positions['stranger'], isA<Offset>());
      expect(positions, hasLength(8));
    });
  });

  group('life dates', () {
    test('a living character reads as Present', () {
      final dates = familyLifeDates(_person('kali', birth: '1975-03-02'));
      expect(dates.label, '1975 - Present');
    });

    test('a dead character reads as a span', () {
      final dates = familyLifeDates(
        _person('timothy', birth: '1880-01-01', death: '1962-11-04'),
      );
      expect(dates.label, '1880 - 1962');
      expect(dates.birthYear, 1880);
      expect(dates.deathYear, 1962);
    });

    test('a character with no dates shows no lifespan line', () {
      expect(familyLifeDates(_person('nobody')).label, isEmpty);
      expect(familyLifeDates(_person('nobody')).isEmpty, isTrue);
    });

    test('a date the app cannot parse is still shown, not blanked', () {
      // An author writing in their own calendar is recording a real birth.
      final dates = familyLifeDates(_person('elrond', birth: 'Third Age 109'));
      expect(dates.label, contains('109'));
    });

    test('initials stand in for a character with no portrait', () {
      expect(familyInitials('Alexander Cruz'), 'AC');
      expect(familyInitials('Madonna'), 'MA');
      expect(familyInitials('   '), '?');
      expect(familyPortraitPath(_person('kali')), isEmpty);
    });
  });
}
