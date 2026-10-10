/// Reading a family out of the graph, and placing it on the page.
///
/// A family tree is not a general graph drawing. Two people who partner each
/// other are one *unit* the reader sees as a pair, children hang from the point
/// between their parents rather than from either of them, and everyone born in
/// the same generation sits on the same line whether or not the shortest path
/// to them says so. None of that falls out of the radial or layered layouts, so
/// it lives here.
///
/// This file owns the whole family vocabulary — structure, placement, life
/// dates and lineage colour — so the painter and the layout read the same
/// fields and can never disagree about who is whose parent.
///
/// Like the other layouts, placement is a **deterministic pure function**:
/// the same subgraph always produces the same coordinates, so the view is
/// restful to read and a widget test can assert on it.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

import 'package:authoros_core/story_graph.dart';

/// Edges that mean "descends from", drawn source -> target as parent -> child.
///
/// `guardianOf` is here because a tree of found or fostered family is a family
/// tree; the product's own brief says parenthood by care counts.
const Set<String> kFamilyDescentEdgeTypes = {'parentOf', 'guardianOf'};

/// Edges that bind two people into a couple the tree draws as one unit.
const Set<String> kFamilyPartnerEdgeTypes = {'partnerOf'};

/// Horizontal distance between two people who are not partners.
const double kFamilyPersonSpacing = 172;

/// Horizontal distance between the two halves of a couple.
///
/// Deliberately tighter than [kFamilyPersonSpacing] — the gap is what makes a
/// pair read as a pair before the reader has looked at a single line.
const double kFamilyCoupleSpacing = 146;

/// Vertical distance between generations.
const double kFamilyGenerationSpacing = 200;

/// The two people in a partnership, ordered so the pair has one stable identity
/// however the edge happened to be stored.
class FamilyCouple {
  FamilyCouple(String a, String b)
      : left = a.compareTo(b) <= 0 ? a : b,
        right = a.compareTo(b) <= 0 ? b : a;

  final String left;
  final String right;

  String get key => '$left+$right';

  bool contains(String id) => id == left || id == right;

  String? other(String id) => id == left
      ? right
      : id == right
          ? left
          : null;

  @override
  bool operator ==(Object other) =>
      other is FamilyCouple && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

/// A family read out of a subgraph: who partners whom, who descends from whom,
/// which generation each person belongs to, and which line they come from.
///
/// Everything here is derived. Nothing is persisted, and nothing invents a
/// relationship the author did not draw — a person with no partner edge is a
/// unit of one, not half of an assumed pair.
class FamilyStructure {
  const FamilyStructure({
    required this.generations,
    required this.couples,
    required this.parents,
    required this.children,
    required this.lineages,
    required this.units,
  });

  static const FamilyStructure empty = FamilyStructure(
    generations: {},
    couples: [],
    parents: {},
    children: {},
    lineages: {},
    units: [],
  );

  /// Reads [subgraph] as a family.
  ///
  /// Only family edges are consulted. A subgraph carrying `employs` and
  /// `visits` alongside `parentOf` still draws as a tree — the rest is simply
  /// not descent, and a tree that invented a generation out of an employment
  /// would be lying.
  factory FamilyStructure.from(StorySubgraph subgraph) {
    if (subgraph.isEmpty) return empty;

    final ids = {for (final node in subgraph.nodes) node.id};
    final parents = <String, List<String>>{};
    final children = <String, List<String>>{};
    final coupleEdges = <FamilyCouple>{};

    // Sorted by edge id so a couple's ordering, and therefore every position
    // downstream of it, does not depend on repository iteration order.
    final edges = [...subgraph.edges]
      ..sort((left, right) => left.id.compareTo(right.id));

    for (final edge in edges) {
      if (!ids.contains(edge.sourceId) || !ids.contains(edge.targetId)) {
        continue;
      }
      if (edge.sourceId == edge.targetId) continue;
      if (kFamilyDescentEdgeTypes.contains(edge.typeId)) {
        (children[edge.sourceId] ??= []).add(edge.targetId);
        (parents[edge.targetId] ??= []).add(edge.sourceId);
      } else if (kFamilyPartnerEdgeTypes.contains(edge.typeId)) {
        coupleEdges.add(FamilyCouple(edge.sourceId, edge.targetId));
      }
    }

    // A person is packed into at most one couple, so they occupy one place on
    // the page. A remarriage's second partner edge is still drawn as a bond by
    // the painter; it just does not get to claim the same person twice.
    final claimed = <String>{};
    final couples = <FamilyCouple>[];
    for (final couple in coupleEdges.toList()
      ..sort((left, right) => left.key.compareTo(right.key))) {
      if (claimed.contains(couple.left) || claimed.contains(couple.right)) {
        continue;
      }
      claimed
        ..add(couple.left)
        ..add(couple.right);
      couples.add(couple);
    }

    final generations = _generations(ids, parents, couples);
    final units = _units(subgraph, generations, couples, parents, children);

    return FamilyStructure(
      generations: generations,
      couples: couples,
      parents: {
        for (final entry in parents.entries)
          entry.key: List.unmodifiable(entry.value),
      },
      children: {
        for (final entry in children.entries)
          entry.key: List.unmodifiable(entry.value),
      },
      lineages: _lineages(ids, parents, couples),
      units: units,
    );
  }

  /// Generation index per person, zero for the eldest drawn.
  final Map<String, int> generations;

  /// The partnerships that get packed as pairs.
  final List<FamilyCouple> couples;

  /// Child id -> the parents of theirs that are actually in this subgraph.
  final Map<String, List<String>> parents;

  /// Parent id -> their children in this subgraph.
  final Map<String, List<String>> children;

  /// Person -> the id of the ancestor their descent line starts at. Someone
  /// who married in is the head of their own line.
  final Map<String, String> lineages;

  /// Couples and singletons, in placement order.
  final List<FamilyUnit> units;

  bool get isEmpty => generations.isEmpty;

  /// True when this subgraph carries enough family to be worth drawing as one.
  bool get hasFamilyEdges => couples.isNotEmpty || parents.isNotEmpty;

  FamilyCouple? coupleFor(String id) {
    for (final couple in couples) {
      if (couple.contains(id)) return couple;
    }
    return null;
  }

  FamilyUnit? unitFor(String id) {
    for (final unit in units) {
      if (unit.members.contains(id)) return unit;
    }
    return null;
  }

  /// A stable index per descent line, for colouring rings and connectors.
  ///
  /// Sorted by ancestor id rather than by discovery, so re-running the graph
  /// never re-colours a tree the author has already learned to read.
  Map<String, int> get lineageIndices {
    final heads = lineages.values.toSet().toList()..sort();
    return {for (var i = 0; i < heads.length; i++) heads[i]: i};
  }

  /// The colour slot for [id], or 0 when the person is not in this family.
  int lineageIndexOf(String id) {
    final head = lineages[id];
    if (head == null) return 0;
    return lineageIndices[head] ?? 0;
  }
}

/// One box on the page: a couple drawn side by side, or a single person.
class FamilyUnit {
  const FamilyUnit({
    required this.members,
    required this.generation,
    required this.childUnitKeys,
  });

  /// One or two people, left to right.
  final List<String> members;
  final int generation;

  /// The units that descend from this one, in drawing order.
  final List<String> childUnitKeys;

  String get key => members.join('+');
  bool get isCouple => members.length > 1;

  /// Half the unit's horizontal extent, for keeping neighbours apart.
  double get halfWidth => isCouple ? kFamilyCoupleSpacing / 2 : 0;
}

/// Assigns everyone a generation, then pulls partners onto the same line.
///
/// Bounded relaxation rather than a topological sort: two characters can be
/// recorded as each other's parent in draft data, and a layout that threw or
/// looped forever on that would be worse than one that simply stops improving.
Map<String, int> _generations(
  Set<String> ids,
  Map<String, List<String>> parents,
  List<FamilyCouple> couples,
) {
  final generations = {for (final id in ids) id: 0};

  for (var pass = 0; pass <= ids.length; pass++) {
    var changed = false;

    for (final entry in parents.entries) {
      for (final parent in entry.value) {
        final wanted = (generations[parent] ?? 0) + 1;
        if ((generations[entry.key] ?? 0) < wanted) {
          generations[entry.key] = wanted;
          changed = true;
        }
      }
    }

    // A partner who married in has no parents here and would otherwise sit on
    // generation zero, one line above their own spouse.
    for (final couple in couples) {
      final left = generations[couple.left] ?? 0;
      final right = generations[couple.right] ?? 0;
      if (left == right) continue;
      final level = math.max(left, right);
      generations[couple.left] = level;
      generations[couple.right] = level;
      changed = true;
    }

    if (!changed) break;
  }

  return generations;
}

/// Walks each person up to the ancestor their line starts at.
///
/// The line is what the tree colours by, so the rule has to answer two things
/// a reader will notice immediately. A couple who founded the drawn family —
/// neither of them has parents here — heads **one** line between them, so their
/// whole descent reads as one family instead of splitting on whichever parent
/// happened to sort first. Someone who married into an existing line keeps
/// their own, because they did bring a different family in with them.
Map<String, String> _lineages(
  Set<String> ids,
  Map<String, List<String>> parents,
  List<FamilyCouple> couples,
) {
  final coupleOf = <String, FamilyCouple>{};
  for (final couple in couples) {
    coupleOf[couple.left] = couple;
    coupleOf[couple.right] = couple;
  }

  bool descends(String id) => (parents[id] ?? const []).isNotEmpty;

  final lineages = <String, String>{};

  String head(String id, Set<String> seen) {
    final known = lineages[id];
    if (known != null) return known;
    if (!seen.add(id)) return id;

    // Descent follows the parent who is already part of this tree. Sorting by
    // id alone would hand a grandchild the line of whichever parent's name
    // happened to come first — often the one who married in, which draws the
    // in-law's family as the one the grandchildren descend from.
    final above = [...?parents[id]]..sort();
    if (above.isNotEmpty) {
      final byBlood = above.where(descends);
      return head(byBlood.isEmpty ? above.first : byBlood.first, seen);
    }

    final couple = coupleOf[id];
    final founding =
        couple != null && !descends(couple.left) && !descends(couple.right);
    return founding ? couple.left : id;
  }

  for (final id in ids.toList()..sort()) {
    lineages[id] = head(id, <String>{});
  }
  return lineages;
}

/// Groups people into couples and singletons, and hangs children off them.
List<FamilyUnit> _units(
  StorySubgraph subgraph,
  Map<String, int> generations,
  List<FamilyCouple> couples,
  Map<String, List<String>> parents,
  Map<String, List<String>> children,
) {
  final coupleOf = <String, FamilyCouple>{};
  for (final couple in couples) {
    coupleOf[couple.left] = couple;
    coupleOf[couple.right] = couple;
  }

  bool descends(String id) => (parents[id] ?? const []).isNotEmpty;

  /// A couple's two people, blood descendant first.
  ///
  /// Which of a pair is drawn on the left is arbitrary to the data and not to
  /// the reader: alphabetical order puts the family's own child on the left in
  /// one couple and the person who married in on the left in the next, so a
  /// branch cannot be followed down a consistent side. Whoever descends from
  /// someone already in the tree goes first; when both do, or neither does,
  /// the id decides so the result is still stable.
  List<String> membersOf(FamilyCouple couple) =>
      descends(couple.left) == descends(couple.right) || descends(couple.left)
          ? [couple.left, couple.right]
          : [couple.right, couple.left];

  String unitKeyFor(String id) {
    final couple = coupleOf[id];
    return couple == null ? id : membersOf(couple).join('+');
  }

  final order = _placementOrder(subgraph, generations);
  final members = <String, List<String>>{};
  for (final id in order) {
    final couple = coupleOf[id];
    members[unitKeyFor(id)] = couple == null ? [id] : membersOf(couple);
  }

  final childKeys = <String, List<String>>{};
  for (final entry in members.entries) {
    final seen = <String>{};
    final descendants = <String>[];
    for (final member in entry.value) {
      for (final child in [...?children[member]]) {
        final key = unitKeyFor(child);
        // A unit is never its own child, whatever the draft data says.
        if (key == entry.key) continue;
        if (!seen.add(key)) continue;
        descendants.add(key);
      }
    }
    // Siblings order by the sibling, not by whoever they married: `first` is
    // the blood descendant now that `membersOf` puts them there, so a grown
    // child's place among their siblings comes from their own birth date.
    descendants.sort((left, right) {
      final leftIndex = order.indexOf(members[left]?.first ?? left);
      final rightIndex = order.indexOf(members[right]?.first ?? right);
      return leftIndex.compareTo(rightIndex);
    });
    childKeys[entry.key] = descendants;
  }

  final units = <FamilyUnit>[];
  final emitted = <String>{};
  for (final id in order) {
    final key = unitKeyFor(id);
    if (!emitted.add(key)) continue;
    final people = members[key]!;
    units.add(
      FamilyUnit(
        members: List.unmodifiable(people),
        generation:
            people.map((member) => generations[member] ?? 0).reduce(math.max),
        childUnitKeys: List.unmodifiable(childKeys[key] ?? const []),
      ),
    );
  }
  return units;
}

/// Everyone, eldest generation first, then eldest sibling first.
///
/// Sorting siblings by date of birth is what makes the tree read the way a
/// reader expects one to. Where a birth date is missing — draft characters
/// usually have none — the title decides, so the order is still stable.
List<String> _placementOrder(
  StorySubgraph subgraph,
  Map<String, int> generations,
) {
  final nodes = [...subgraph.nodes]..sort((left, right) {
      final byGeneration =
          (generations[left.id] ?? 0).compareTo(generations[right.id] ?? 0);
      if (byGeneration != 0) return byGeneration;

      final leftBirth = familyLifeDates(left).birthYear;
      final rightBirth = familyLifeDates(right).birthYear;
      if (leftBirth != rightBirth) {
        if (leftBirth == null) return 1;
        if (rightBirth == null) return -1;
        return leftBirth.compareTo(rightBirth);
      }

      final byTitle = left.title.compareTo(right.title);
      return byTitle != 0 ? byTitle : left.id.compareTo(right.id);
    });
  return [for (final node in nodes) node.id];
}

/// Places a family: generations on rows, couples paired, parents centred over
/// the children they had together.
///
/// Coordinates are in the same origin-centred model space every layout uses.
Map<String, Offset> familyLayout(StorySubgraph subgraph) {
  if (subgraph.isEmpty) return const {};
  final family = FamilyStructure.from(subgraph);
  return familyPositions(family);
}

/// The placement half of [familyLayout], for a caller that already read the
/// structure and should not pay to read it twice.
Map<String, Offset> familyPositions(FamilyStructure family) {
  if (family.units.isEmpty) return const {};

  final byKey = {for (final unit in family.units) unit.key: unit};
  final centres = <String, double>{};
  final visiting = <String>{};
  var cursor = 0.0;

  // Leaves are laid out left to right in descent order and everyone above them
  // is centred on what they produced, which is what gives a family tree its
  // shape: the pair sits over the children, not beside them.
  double place(String key) {
    final known = centres[key];
    if (known != null) return known;

    final unit = byKey[key];
    if (unit == null) return 0;

    if (!visiting.add(key)) {
      // A descent cycle. Park it rather than recursing forever.
      final x = cursor;
      cursor += kFamilyPersonSpacing;
      return centres[key] = x;
    }

    final childCentres = <double>[];
    for (final childKey in unit.childUnitKeys) {
      if (visiting.contains(childKey)) continue;
      childCentres.add(place(childKey));
    }
    visiting.remove(key);

    final double centre;
    if (childCentres.isEmpty) {
      centre = cursor + unit.halfWidth;
      cursor = centre + unit.halfWidth + kFamilyPersonSpacing;
    } else {
      childCentres.sort();
      centre = (childCentres.first + childCentres.last) / 2;
    }
    return centres[key] = centre;
  }

  // Roots first, so the natural reading order drives the cursor and a stray
  // descendant does not get placed before the line it belongs to.
  final roots = [
    for (final unit in family.units)
      if (unit.members
          .every((member) => (family.parents[member] ?? const []).isEmpty))
        unit.key,
  ];
  for (final key in roots) {
    place(key);
  }
  for (final unit in family.units) {
    place(unit.key);
  }

  _spreadOverlaps(family, byKey, centres);

  return _toPersonPositions(family, byKey, centres);
}

/// Pushes apart units that centring left sitting on top of one another.
///
/// Centring a parent over its children is right until two parents' children
/// interleave; then the parents collide. One left-to-right sweep per generation
/// fixes it, and costs a little of the centring rather than legibility.
void _spreadOverlaps(
  FamilyStructure family,
  Map<String, FamilyUnit> byKey,
  Map<String, double> centres,
) {
  final byGeneration = <int, List<String>>{};
  for (final unit in family.units) {
    (byGeneration[unit.generation] ??= []).add(unit.key);
  }

  for (final generation in byGeneration.keys.toList()..sort()) {
    final keys = byGeneration[generation]!
      ..sort((left, right) {
        final byCentre = (centres[left] ?? 0).compareTo(centres[right] ?? 0);
        return byCentre != 0 ? byCentre : left.compareTo(right);
      });

    for (var index = 1; index < keys.length; index++) {
      final previous = byKey[keys[index - 1]]!;
      final current = byKey[keys[index]]!;
      final minimum = (centres[previous.key] ?? 0) +
          previous.halfWidth +
          current.halfWidth +
          kFamilyPersonSpacing;
      if ((centres[current.key] ?? 0) < minimum) {
        centres[current.key] = minimum;
      }
    }
  }
}

/// Turns unit centres into a position per person, centred on the origin.
Map<String, Offset> _toPersonPositions(
  FamilyStructure family,
  Map<String, FamilyUnit> byKey,
  Map<String, double> centres,
) {
  final positions = <String, Offset>{};
  for (final unit in family.units) {
    final centre = centres[unit.key] ?? 0;
    final y = kFamilyGenerationSpacing * unit.generation;
    if (unit.isCouple) {
      positions[unit.members.first] =
          Offset(centre - kFamilyCoupleSpacing / 2, y);
      positions[unit.members.last] =
          Offset(centre + kFamilyCoupleSpacing / 2, y);
    } else {
      positions[unit.members.first] = Offset(centre, y);
    }
  }

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

/// The birth and death a person's record carries, if any.
class FamilyLifeDates {
  const FamilyLifeDates({this.birth = '', this.death = ''});

  final String birth;
  final String death;

  bool get isEmpty => birth.isEmpty && death.isEmpty;

  int? get birthYear => _year(birth);
  int? get deathYear => _year(death);

  /// `1880 - 1962`, or `1975 - Present` for someone the author has not killed.
  ///
  /// Falls back to whatever the field actually held when it is not a date the
  /// app can parse — an author writing "Third Age 2931" is recording a real
  /// birth, and blanking it because it is not ISO-8601 would be worse than
  /// showing it.
  String get label {
    if (isEmpty) return '';
    final born = birthYear?.toString() ?? birth;
    if (death.isEmpty) return born.isEmpty ? '' : '$born - Present';
    final died = deathYear?.toString() ?? death;
    return born.isEmpty ? died : '$born - $died';
  }

  static int? _year(String value) {
    final match = RegExp(r'-?\d{1,6}').firstMatch(value.trim());
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }
}

/// Reads the life dates off a node's record.
///
/// Character Studio writes `identity.dateOfBirth` and `identity.dateOfDeath`
/// straight onto the record, so this reads them where they actually live rather
/// than where the record type declares them.
FamilyLifeDates familyLifeDates(StoryGraphNode node) {
  final fields = node.record?.fields;
  if (fields == null) return const FamilyLifeDates();
  String read(String key) => fields[key]?.toString().trim() ?? '';
  return FamilyLifeDates(
    birth: read('identity.dateOfBirth'),
    death: read('identity.dateOfDeath'),
  );
}

/// The portrait to draw in a person's circle, or empty when they have none.
///
/// Character Studio stores the picked file under `_character.portraitPath`
/// while the record type declares `media.primaryPortrait`; a character created
/// either way should still show their face.
String familyPortraitPath(StoryGraphNode node) {
  final fields = node.record?.fields;
  if (fields == null) return '';
  for (final key in const [
    '_character.portraitPath',
    'media.primaryPortrait'
  ]) {
    final value = fields[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

/// Up to two initials, for a person with no portrait.
String familyInitials(String title) {
  final words = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final word = words.first;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return (words.first.substring(0, 1) + words.last.substring(0, 1))
      .toUpperCase();
}
