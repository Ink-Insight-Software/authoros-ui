/// Reading a group out of the graph, and placing its roster on the page.
///
/// A group is not a family and must not be drawn as one. Descent has a shape —
/// generations, pairs, children between their parents — that says something
/// true about a bloodline and nothing at all about a war band. What a war band
/// has is a *ladder*: someone leads it, someone is second, most are neither,
/// and some have left. So this file bands rather than descends, and shares no
/// code with `family_tree.dart` beyond the idea of a pure layout.
///
/// The split is deliberate and structural. `family_tree.dart` reads
/// `parentOf`/`partnerOf`; this reads `memberOf`. Neither knows the other
/// exists, so a house that is both a bloodline and an organisation is drawn by
/// whichever mode the author opens, from the same records.
///
/// Like every other layout here, placement is a **deterministic pure function**:
/// the same group always lands in the same place, so the view is restful and a
/// test can assert on it.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import 'package:authoros_core/story_graph.dart';

/// The edge that makes someone a member of something.
const String kGroupMembershipEdgeType = 'memberOf';

/// Ties between groups, drawn beside the roster rather than inside it.
const Set<String> kGroupToGroupEdgeTypes = {
  'alliedWith',
  'enemyOf',
  'rules',
  'controls',
};

/// Horizontal distance between two members in the same band.
const double kRosterMemberSpacing = 186;

/// Vertical distance between bands.
///
/// Deliberately tight. A roster is tall — seven bands where a family tree has
/// three or four generations — and node cards are drawn at a fixed pixel size
/// while the arrangement scales, so an over-tall roster is zoomed out far
/// enough by `fitted` that neighbouring cards start to collide sideways. Less
/// air between rows keeps the whole ladder legible on one screen.
const double kRosterBandSpacing = 142;

/// How far the group's own card sits above the first band.
const double kRosterGroupOffset = 196;

/// Where a member stands in a group, from the top of the ladder down.
///
/// A closed vocabulary because a roster has to *sort*, and free text cannot.
/// The author's own word for the job lives in [GroupMember.rank] beside this,
/// so a guild can have a Grand Magister without this enum knowing the word.
///
/// Declaration order is the ladder, and [index] is the rank — so a band's
/// position is the enum's own order rather than a second list that could
/// disagree with it.
enum GroupRole {
  founder('Founder', 'Founders'),
  leader('Leader', 'Leadership'),
  second('Second', 'Seconds'),
  officer('Officer', 'Officers'),
  member('Member', 'Members'),
  initiate('Initiate', 'Initiates'),
  former('Former', 'Former members');

  const GroupRole(this.label, this.bandLabel);

  /// What one person is.
  final String label;

  /// What a row of them is called, for the band's heading.
  final String bandLabel;

  /// Reads the value stored in `memberOf.role`.
  ///
  /// An unrecognised or absent value is [member]: an author who linked someone
  /// to a guild without saying what they do has said they are in the guild, and
  /// that is exactly what "member" means. Refusing to place them would be
  /// worse than placing them plainly.
  static GroupRole parse(Object? value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return member;
    for (final role in values) {
      if (role.name == text || role.label.toLowerCase() == text) return role;
    }
    return member;
  }
}

/// One person's place in one group.
class GroupMember {
  const GroupMember({
    required this.id,
    required this.role,
    this.rank = '',
    this.status = '',
    this.joined = '',
    this.left = '',
  });

  final String id;
  final GroupRole role;

  /// The author's own title for the job — 'Grand Magister', 'Whisperer'.
  final String rank;

  final String status;
  final String joined;
  final String left;

  /// True when this membership has ended.
  ///
  /// Derived rather than stored, and from either of the two things that mean
  /// it: a departure date, or the role saying so. A former member is drawn
  /// quietly rather than dropped — an author who wrote a betrayal wants to see
  /// it on the roster.
  bool get hasLeft => role == GroupRole.former || left.trim().isNotEmpty;

  /// What to show under the name: the author's title, or the role's own label
  /// when they did not give one.
  String get caption => rank.trim().isNotEmpty ? rank.trim() : role.label;
}

/// A group read out of a subgraph: which record is the group, who belongs to
/// it, and where each of them stands.
///
/// Everything is derived. Nothing is persisted, and nothing invents a
/// membership the author did not draw.
class GroupStructure {
  const GroupStructure({
    required this.groupId,
    required this.members,
    required this.allies,
  });

  static const GroupStructure empty =
      GroupStructure(groupId: '', members: [], allies: []);

  /// Reads [subgraph] as one group's roster.
  ///
  /// [rootId] names the group when the caller knows it — the mode roots on a
  /// faction, so it usually does. Without one, the record the most `memberOf`
  /// edges point at is the group, which is the only answer that can be right
  /// when a subgraph holds more than one.
  factory GroupStructure.from(StorySubgraph subgraph, {String? rootId}) {
    if (subgraph.isEmpty) return empty;

    final ids = {for (final node in subgraph.nodes) node.id};

    // Sorted by edge id so the roster does not depend on repository iteration
    // order — the same reason the family tree sorts its edges.
    final edges = [...subgraph.edges]
      ..sort((left, right) => left.id.compareTo(right.id));

    final memberships = [
      for (final edge in edges)
        if (edge.typeId == kGroupMembershipEdgeType &&
            ids.contains(edge.sourceId) &&
            ids.contains(edge.targetId) &&
            edge.sourceId != edge.targetId)
          edge,
    ];

    final groupId = rootId != null && ids.contains(rootId)
        ? rootId
        : _mostJoined(memberships);
    if (groupId.isEmpty) return empty;

    final seen = <String>{};
    final members = <GroupMember>[];
    for (final edge in memberships) {
      // `memberOf` runs member -> group, so the group is the target.
      if (edge.targetId != groupId) continue;
      if (!seen.add(edge.sourceId)) continue;
      members.add(_memberFrom(edge));
    }

    final allies = [
      for (final edge in edges)
        if (kGroupToGroupEdgeTypes.contains(edge.typeId) &&
            (edge.sourceId == groupId || edge.targetId == groupId))
          edge.otherEnd(groupId),
    ];

    return GroupStructure(
      groupId: groupId,
      members: List.unmodifiable(members),
      allies: List.unmodifiable(allies.toSet()),
    );
  }

  /// The record every membership points at.
  final String groupId;

  /// Everyone linked to it, in no particular order — [bands] does the ordering.
  final List<GroupMember> members;

  /// Other groups tied to this one, drawn beside the roster rather than in it.
  final List<String> allies;

  bool get isEmpty => groupId.isEmpty;

  /// True when this subgraph carries enough membership to be worth drawing.
  bool get hasMembers => members.isNotEmpty;

  GroupMember? memberById(String id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Whether [id] is the group itself rather than one of its people.
  bool isGroup(String id) => id == groupId;

  /// Members grouped into bands, ladder order, empty roles omitted.
  ///
  /// A group with no officers should not be drawn with a gap where the
  /// officers would be — the shape of a roster is the shape of the group, not
  /// of the vocabulary.
  Map<GroupRole, List<GroupMember>> get bands {
    final byRole = <GroupRole, List<GroupMember>>{};
    for (final member in members) {
      (byRole[member.role] ??= []).add(member);
    }
    return {
      for (final role in GroupRole.values)
        if (byRole[role] != null)
          role: List.unmodifiable(byRole[role]!..sort(_order)),
    };
  }

  /// Within a band: the author's own title first, then name, then id.
  ///
  /// Sorting by `rank` before the record's title means a guild that named its
  /// people Adept, Master and Novice reads in the author's order where they
  /// gave one, and alphabetically where they did not.
  static int _order(GroupMember left, GroupMember right) {
    final byRank = left.rank.toLowerCase().compareTo(right.rank.toLowerCase());
    if (byRank != 0) {
      // A member with no title sorts after one with a title, rather than first.
      if (left.rank.isEmpty) return 1;
      if (right.rank.isEmpty) return -1;
      return byRank;
    }
    return left.id.compareTo(right.id);
  }

  static GroupMember _memberFrom(StoryGraphEdge edge) {
    final metadata = edge.link.metadata;
    String read(String key) => metadata[key]?.toString().trim() ?? '';
    return GroupMember(
      id: edge.sourceId,
      role: GroupRole.parse(metadata['role']),
      rank: read('rank'),
      status: read('status'),
      joined: read('joinedDate'),
      left: read('leftDate'),
    );
  }

  /// The record the most memberships point at.
  static String _mostJoined(List<StoryGraphEdge> memberships) {
    final counts = <String, int>{};
    for (final edge in memberships) {
      counts[edge.targetId] = (counts[edge.targetId] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';

    var best = '';
    var bestCount = -1;
    // Ties break on id so two groups of equal size still resolve the same way
    // every run.
    for (final id in counts.keys.toList()..sort()) {
      final count = counts[id]!;
      if (count > bestCount) {
        best = id;
        bestCount = count;
      }
    }
    return best;
  }
}

/// Places a group: the group's own card above, its members in bands below.
///
/// Coordinates are in the same origin-centred model space every layout uses.
Map<String, Offset> rosterLayout(StorySubgraph subgraph, {String? rootId}) {
  if (subgraph.isEmpty) return const {};
  return rosterPositions(GroupStructure.from(subgraph, rootId: rootId));
}

/// The placement half of [rosterLayout], for a caller that already read the
/// structure and should not pay to read it twice.
Map<String, Offset> rosterPositions(GroupStructure group) {
  if (group.isEmpty) return const {};

  final positions = <String, Offset>{};
  final bands = group.bands;

  // The group sits above its first band rather than in the middle of the
  // roster: a reader's eye starts at the thing everyone belongs to.
  positions[group.groupId] = Offset.zero;

  var y = kRosterGroupOffset;
  for (final entry in bands.entries) {
    final row = entry.value;
    final offset = (row.length - 1) / 2;
    for (var index = 0; index < row.length; index++) {
      positions[row[index].id] =
          Offset(kRosterMemberSpacing * (index - offset), y);
    }
    y += kRosterBandSpacing;
  }

  // Allied groups sit on the group's own line, out to the right, so a council
  // of houses reads as peers rather than as members of one another.
  final allies = [...group.allies]..sort();
  for (var index = 0; index < allies.length; index++) {
    positions[allies[index]] = Offset(
      kRosterMemberSpacing * 1.6 * (index + 1),
      0,
    );
  }

  return _centred(positions);
}

/// Centres the whole arrangement on the origin.
Map<String, Offset> _centred(Map<String, Offset> positions) {
  if (positions.isEmpty) return positions;

  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;
  for (final position in positions.values) {
    minX = math.min(minX, position.dx);
    maxX = math.max(maxX, position.dx);
    minY = math.min(minY, position.dy);
    maxY = math.max(maxY, position.dy);
  }
  final shift = Offset(-(minX + maxX) / 2, -(minY + maxY) / 2);

  return {
    for (final entry in positions.entries) entry.key: entry.value + shift,
  };
}
