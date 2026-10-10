/// A group is drawn as a ladder, not as a bloodline.
///
/// These assert on the shape a roster has to have — who the group is, which
/// band each member lands in, that a departure is visible rather than tidied
/// away — rather than on exact pixels, so a spacing constant stays tunable.
library;

import 'package:authoros_core/connected_domain.dart';
import 'package:authoros_core/built_in_connection_types.dart';
import 'package:authoros_core/story_graph.dart';
import 'package:authoros_core/story_graph_modes.dart';
import 'package:authoros_ui/loom/graph_layout.dart';
import 'package:authoros_ui/loom/group_roster.dart';
import 'package:flutter_test/flutter_test.dart';

final _timestamp = DateTime.utc(2026, 8, 27, 12);

StoryGraphNode _record(String id, String typeId, String categoryId) =>
    StoryGraphNode.fromRecord(
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        projectId: 'project-a',
        title: id,
        createdAt: _timestamp,
        updatedAt: _timestamp,
      ),
      categoryId: categoryId,
    );

StoryGraphNode _person(String id) => _record(id, 'character', 'characters');
StoryGraphNode _group(String id) => _record(id, 'faction', 'factions');

StoryGraphEdge _edge(
  String source,
  String target,
  String typeId, {
  Map<String, Object?> metadata = const {},
}) =>
    StoryGraphEdge(
      link: RecordLink(
        id: '$source-$typeId-$target',
        sourceId: source,
        targetId: target,
        typeId: typeId,
        scopeId: 'project-a',
        createdAt: _timestamp,
        updatedAt: _timestamp,
        metadata: metadata,
      ),
      inverseLabel: '',
      wildcard: false,
    );

StoryGraphEdge _member(
  String person,
  String group, {
  String? role,
  String rank = '',
  String left = '',
}) =>
    _edge(person, group, 'memberOf', metadata: {
      if (role != null) 'role': role,
      if (rank.isNotEmpty) 'rank': rank,
      if (left.isNotEmpty) 'leftDate': left,
    });

StorySubgraph _subgraph(
  List<StoryGraphNode> nodes,
  List<StoryGraphEdge> edges, {
  String? rootId,
}) =>
    StorySubgraph(
      nodes: nodes,
      edges: edges,
      depthReached: 2,
      truncated: false,
      rootId: rootId,
    );

/// A guild with a master, a second, two ordinary members and one who left.
StorySubgraph _guild() => _subgraph(
      [
        _group('order'),
        _person('magister'),
        _person('deputy'),
        _person('adept'),
        _person('scribe'),
        _person('traitor'),
      ],
      [
        _member('magister', 'order', role: 'Leader', rank: 'Grand Magister'),
        _member('deputy', 'order', role: 'Second', rank: 'Warden'),
        _member('adept', 'order', role: 'Member', rank: 'Adept'),
        _member('scribe', 'order', role: 'Member'),
        _member('traitor', 'order', role: 'Former', left: '1188'),
      ],
      rootId: 'order',
    );

void main() {
  group('reading a group out of the graph', () {
    test('the root is the group and everyone else is a member', () {
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      expect(roster.groupId, 'order');
      expect(roster.isGroup('order'), isTrue);
      expect(roster.isGroup('magister'), isFalse);
      expect(roster.members, hasLength(5));
    });

    test('the group is found without a root when one is not given', () {
      // Every membership points at it, so nothing else can be the group.
      expect(GroupStructure.from(_guild()).groupId, 'order');
    });

    test('roles are read off the membership edge', () {
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      expect(roster.memberById('magister')!.role, GroupRole.leader);
      expect(roster.memberById('deputy')!.role, GroupRole.second);
      expect(roster.memberById('adept')!.role, GroupRole.member);
    });

    test('a membership with no role recorded is an ordinary member', () {
      // Linking someone to a guild without saying what they do still says they
      // are in the guild. Refusing to place them would be worse.
      final subgraph = _subgraph(
        [_group('order'), _person('nobody')],
        [_member('nobody', 'order')],
        rootId: 'order',
      );

      expect(
        GroupStructure.from(subgraph, rootId: 'order')
            .memberById('nobody')!
            .role,
        GroupRole.member,
      );
      expect(GroupRole.parse(null), GroupRole.member);
      expect(GroupRole.parse(''), GroupRole.member);
      expect(GroupRole.parse('nonsense from an old import'), GroupRole.member);
    });

    test('a role reads whether it was stored by name or by label', () {
      expect(GroupRole.parse('leader'), GroupRole.leader);
      expect(GroupRole.parse('Leader'), GroupRole.leader);
      expect(GroupRole.parse('  FORMER '), GroupRole.former);
    });

    test('the author\'s own title is what the card shows', () {
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      // A title where they gave one...
      expect(roster.memberById('magister')!.caption, 'Grand Magister');
      // ...and the role's plain word where they did not.
      expect(roster.memberById('scribe')!.caption, 'Member');
    });

    test('a departure is visible from either thing that means it', () {
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      expect(roster.memberById('traitor')!.hasLeft, isTrue);
      expect(roster.memberById('magister')!.hasLeft, isFalse);

      // A leaving date alone is enough, without the role saying so.
      final subgraph = _subgraph(
        [_group('order'), _person('quiet')],
        [_member('quiet', 'order', role: 'Officer', left: '1190')],
        rootId: 'order',
      );
      final member =
          GroupStructure.from(subgraph, rootId: 'order').memberById('quiet')!;
      expect(member.role, GroupRole.officer);
      expect(member.hasLeft, isTrue);
    });

    test('a former member is kept on the roster, not dropped', () {
      // An author who wrote a betrayal wants to see it.
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      expect(
        roster.members.map((member) => member.id),
        contains('traitor'),
      );
      expect(roster.bands[GroupRole.former], hasLength(1));
    });

    test('membership pointing at another group is not this roster', () {
      final subgraph = _subgraph(
        [_group('order'), _group('rivals'), _person('spy')],
        [_member('spy', 'rivals')],
        rootId: 'order',
      );

      final roster = GroupStructure.from(subgraph, rootId: 'order');
      expect(roster.members, isEmpty);
      expect(roster.hasMembers, isFalse);
    });

    test('group-to-group ties are collected, not treated as members', () {
      final subgraph = _subgraph(
        [_group('order'), _group('friends'), _group('rivals')],
        [
          _edge('order', 'friends', 'alliedWith'),
          _edge('rivals', 'order', 'enemyOf'),
        ],
        rootId: 'order',
      );

      final roster = GroupStructure.from(subgraph, rootId: 'order');
      expect(roster.allies, unorderedEquals(['friends', 'rivals']));
      expect(roster.members, isEmpty);
    });

    test('an empty graph is an empty roster', () {
      expect(GroupStructure.from(StorySubgraph.empty).isEmpty, isTrue);
      expect(GroupStructure.empty.isEmpty, isTrue);
      expect(rosterPositions(GroupStructure.empty), isEmpty);
      expect(rosterLayout(StorySubgraph.empty), isEmpty);
    });
  });

  group('placing a roster', () {
    test('the group sits above everyone who belongs to it', () {
      final positions = rosterLayout(_guild(), rootId: 'order');

      for (final id in ['magister', 'deputy', 'adept', 'scribe', 'traitor']) {
        expect(
          positions['order']!.dy,
          lessThan(positions[id]!.dy),
          reason: '$id should be drawn below the group',
        );
      }
    });

    test('bands descend the ladder in order', () {
      final positions = rosterLayout(_guild(), rootId: 'order');

      expect(positions['magister']!.dy, lessThan(positions['deputy']!.dy));
      expect(positions['deputy']!.dy, lessThan(positions['adept']!.dy));
      expect(positions['adept']!.dy, lessThan(positions['traitor']!.dy));
    });

    test('everyone in a band shares a row', () {
      final positions = rosterLayout(_guild(), rootId: 'order');

      expect(positions['adept']!.dy, positions['scribe']!.dy);
      expect(positions['adept']!.dx, isNot(positions['scribe']!.dx));
    });

    test('an empty role leaves no gap', () {
      // This guild has no founder, officers or initiates. A roster should be
      // the shape of the group, not of the vocabulary.
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      expect(
        roster.bands.keys,
        [
          GroupRole.leader,
          GroupRole.second,
          GroupRole.member,
          GroupRole.former
        ],
      );

      final positions = rosterLayout(_guild(), rootId: 'order');
      final rows = positions.values.map((position) => position.dy).toSet();
      // The group's own row plus four bands, and nothing in between.
      expect(rows, hasLength(5));
    });

    test('a titled member sorts before an untitled one in the same band', () {
      final roster = GroupStructure.from(_guild(), rootId: 'order');

      expect(
        roster.bands[GroupRole.member]!.map((member) => member.id),
        ['adept', 'scribe'],
      );
    });

    test('the same group always lands in the same place', () {
      expect(
        rosterLayout(_guild(), rootId: 'order'),
        rosterLayout(_guild(), rootId: 'order'),
      );
    });

    test('the roster is centred on the origin', () {
      final positions = rosterLayout(_guild(), rootId: 'order').values.toList();

      final xs = positions.map((position) => position.dx).toList()..sort();
      final ys = positions.map((position) => position.dy).toList()..sort();

      expect((xs.first + xs.last) / 2, closeTo(0, 0.01));
      expect((ys.first + ys.last) / 2, closeTo(0, 0.01));
    });

    test('allied groups sit on the group\'s own line, not in a band', () {
      final subgraph = _subgraph(
        [_group('order'), _group('friends'), _person('adept')],
        [
          _member('adept', 'order', role: 'Member'),
          _edge('order', 'friends', 'alliedWith'),
        ],
        rootId: 'order',
      );

      final positions = rosterLayout(subgraph, rootId: 'order');
      expect(positions['friends']!.dy, positions['order']!.dy);
      expect(positions['friends']!.dx, greaterThan(positions['order']!.dx));
    });

    test('the mode routes through the roster layout', () {
      expect(StoryGraphModes.group.layout, StoryGraphLayout.roster);
      expect(
        layoutSubgraph(_guild(), layout: StoryGraphModes.group.layout),
        rosterLayout(_guild(), rootId: 'order'),
      );
    });
  });

  group('the role vocabulary', () {
    test('every value the field offers is one the roster can read', () {
      // The declared options and the enum are two lists that could drift; a
      // role the author can pick but the layout cannot parse would silently
      // band them as an ordinary member.
      final memberOf = BuiltInConnectionTypes.registry().resolve('memberOf');
      final role =
          memberOf.metadataFields.singleWhere((field) => field.id == 'role');

      expect(role.options, hasLength(GroupRole.values.length));
      for (final option in role.options) {
        expect(
          GroupRole.parse(option).label,
          option,
          reason: '"$option" is offered but does not round-trip',
        );
      }
    });

    test('the ladder is declared in seniority order', () {
      // The layout bands by `index`, so declaration order is load-bearing.
      expect(GroupRole.values.map((role) => role.label), [
        'Founder',
        'Leader',
        'Second',
        'Officer',
        'Member',
        'Initiate',
        'Former',
      ]);
    });
  });
}
