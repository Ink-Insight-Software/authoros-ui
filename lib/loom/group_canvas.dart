/// Drawing a roster: the group above, its people banded below it.
///
/// The member card is the family tree's portrait card with a different second
/// line — a face, a name, and the author's own word for the job rather than a
/// lifespan. That reuse is the point: a person looks like a person wherever the
/// graph draws them, and only the thing being said about them changes.
///
/// What is different is everything around them. Descent earns square connectors
/// because a child comes from a point between two parents. Belonging is drawn
/// as a spine down from the group, a rail across each band, and a stub into each
/// person — because the alternative, one line from the group to every member,
/// fans forty lines out of a single point and crosses every card between.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:authoros_core/story_graph.dart';
import 'family_canvas.dart';
import 'graph_canvas.dart';
import 'graph_layout.dart';
import 'group_roster.dart';

/// The drawn size of the group's own card.
const double kGroupCardWidth = 208;
const double kGroupCardHeight = 96;

/// One person on the roster.
///
/// Deliberately the family tree's card: same portrait, same ring, same initials
/// fallback. The caption underneath is the member's rank rather than their
/// lifespan, which is the only thing belonging says that descent does not.
class RosterMemberCard extends StatelessWidget {
  const RosterMemberCard({
    super.key,
    required this.node,
    required this.member,
    required this.palette,
    required this.ringColour,
    required this.isSelected,
    this.portrait,
    this.onTap,
    this.onOpen,
  });

  final StoryGraphNode node;
  final GroupMember member;
  final GraphPalette palette;
  final Color ringColour;
  final bool isSelected;
  final ImageProvider? portrait;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    // Someone who has left is drawn quietly rather than dropped: an author who
    // wrote a betrayal wants to see it on the roster, not have it tidied away.
    final faded = member.hasLeft;
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: FamilyNodeCard(
        node: node,
        palette: palette,
        ringColour: ringColour,
        isRoot: false,
        isSelected: isSelected,
        portrait: portrait,
        caption: member.caption,
        captionStruck: faded,
        onTap: onTap,
        onOpen: onOpen,
      ),
    );
  }
}

/// The group's own card: its name, its kind, and how many belong to it.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.node,
    required this.palette,
    required this.isSelected,
    this.group,
    this.onTap,
    this.onOpen,
  });

  final StoryGraphNode node;

  /// The roster behind this card, when this is the group the mode is showing.
  ///
  /// Null for a group drawn *beside* the roster — an ally or a rival. Their
  /// membership was never loaded, and "0 members" would be a claim rather than
  /// an absence.
  final GroupStructure? group;
  final GraphPalette palette;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;

  /// `12 members`, or `9 members · 3 former` when some have gone.
  ///
  /// Counting the departed separately rather than folding them in: a guild of
  /// nine with three who left is a different fact from a guild of twelve, and
  /// the roster should not have to be counted by eye to tell them apart.
  String get _summary {
    final roster = group;
    if (roster == null) return node.bucket.label;
    final current = roster.members.where((member) => !member.hasLeft).length;
    final former = roster.members.length - current;
    final people = current == 1 ? '1 member' : '$current members';
    return former == 0 ? people : '$people · $former former';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${node.title}, $_summary',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? palette.primary : palette.outline,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.14),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconForBucket(node.bucket),
                    size: 17,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: palette.title.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: palette.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Membership lines, group ties, and the label on each band.
///
/// The rail joining a band is not claiming its people are related to each
/// other — unlike siblings, two members of a guild have no tie the guild does
/// not already express. It is saying they stand on the same rung, which is
/// exactly what the band means.
class RosterEdgePainter extends CustomPainter {
  const RosterEdgePainter({
    required this.subgraph,
    required this.group,
    required this.positions,
    required this.projection,
    required this.palette,
    this.selectedId,
  });

  final StorySubgraph subgraph;
  final GroupStructure group;
  final Map<String, Offset> positions;
  final GraphProjection projection;
  final GraphPalette palette;
  final String? selectedId;

  Offset? _canvasOf(String id) {
    final model = positions[id];
    return model == null ? null : projection.toCanvas(model);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintMemberships(canvas);
    _paintGroupTies(canvas);
    _paintBandLabels(canvas, size);
  }

  /// A spine down from the group, a rail across each band, a stub into each
  /// person.
  ///
  /// The obvious drawing — one line from the group to every member — is the
  /// wrong one: forty lines from a single point fan across the whole roster and
  /// cross every card between. Banding is what says who belongs where, so the
  /// lines only have to connect a band to the group, not each person to it.
  void _paintMemberships(Canvas canvas) {
    final groupCentre = _canvasOf(group.groupId);
    if (groupCentre == null) return;

    final spineX = groupCentre.dx;
    final spineTop = groupCentre.dy + kGroupCardHeight / 2;
    var spineBottom = spineTop;
    // The lowest edge drawn so far — the group's card, then each band's — so a
    // rail knows what it has to clear.
    var previousBottom = spineTop;

    for (final entry in group.bands.entries) {
      final tops = <Offset>[];
      var ended = 0;
      for (final member in entry.value) {
        final centre = _canvasOf(member.id);
        if (centre == null) continue;
        tops.add(centre.translate(0, -kFamilyNodeHeight / 2));
        if (member.hasLeft) ended++;
      }
      if (tops.isEmpty) continue;

      // A band everyone has left is drawn dashed throughout; a mixed band
      // stays solid and the individual stubs carry the difference.
      final allEnded = ended == tops.length;
      final touched = entry.value.any((member) => member.id == selectedId) ||
          selectedId == group.groupId;
      final paint = Paint()
        ..color = palette.outline
            .withValues(alpha: allEnded ? 0.3 : (touched ? 0.9 : 0.5))
        ..strokeWidth = touched ? 2 : 1.4
        ..style = PaintingStyle.stroke;

      // Cards are drawn at a fixed pixel size while the arrangement scales, so
      // the gap between two bands is not a constant and a fixed offset puts the
      // rail through the captions of the band above. Sit it in whatever gap
      // there actually is.
      final bandTop = tops.map((top) => top.dy).reduce(math.min);
      final railY = previousBottom <= 0
          ? bandTop - 24
          : ((previousBottom + bandTop) / 2)
              .clamp(previousBottom + 3, bandTop - 3);
      final left = tops.map((top) => top.dx).reduce(math.min);
      final right = tops.map((top) => top.dx).reduce(math.max);

      if (left != right) {
        _line(canvas, Offset(left, railY), Offset(right, railY), paint,
            dashed: allEnded);
      }
      // The rail is centred on the same axis as the group, so it already meets
      // the spine; all the spine has to do is reach the lowest one.
      spineBottom = math.max(spineBottom, railY);

      for (var index = 0; index < tops.length; index++) {
        _line(canvas, Offset(tops[index].dx, railY), tops[index], paint,
            dashed: entry.value[index].hasLeft);
      }

      previousBottom = bandTop + kFamilyNodeHeight;
    }

    if (spineBottom > spineTop) {
      final spine = Paint()
        ..color = palette.outline.withValues(alpha: 0.5)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(spineX, spineTop),
        Offset(spineX, spineBottom),
        spine,
      );
    }
  }

  void _line(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    bool dashed = false,
  }) {
    if (dashed) {
      _drawDashed(canvas, start, end, paint);
    } else {
      canvas.drawLine(start, end, paint);
    }
  }

  void _paintGroupTies(Canvas canvas) {
    final groupCentre = _canvasOf(group.groupId);
    if (groupCentre == null) return;

    for (final edge in subgraph.edges) {
      if (!kGroupToGroupEdgeTypes.contains(edge.typeId)) continue;
      if (edge.sourceId != group.groupId && edge.targetId != group.groupId) {
        continue;
      }
      final other = _canvasOf(edge.otherEnd(group.groupId));
      if (other == null) continue;

      // An alliance and an enmity are opposite facts and must not look alike.
      final hostile = edge.typeId == 'enemyOf';
      final paint = Paint()
        ..color = (hostile ? palette.onSurfaceVariant : palette.primary)
            .withValues(alpha: 0.7)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;

      if (hostile) {
        _drawDashed(canvas, groupCentre, other, paint);
      } else {
        canvas.drawLine(groupCentre, other, paint);
      }
    }
  }

  /// A quiet heading beside each band, so a reader can tell an officer from an
  /// initiate without opening either.
  void _paintBandLabels(Canvas canvas, Size size) {
    if (projection.zoom < 0.6) return;

    for (final entry in group.bands.entries) {
      final first = entry.value.first;
      final centre = _canvasOf(first.id);
      if (centre == null) continue;

      final painter = TextPainter(
        text: TextSpan(
          text: entry.key.bandLabel.toUpperCase(),
          style: palette.label.copyWith(
            fontSize: 10,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      // Left of the band's first member, vertically on their portrait.
      final origin = Offset(
        centre.dx - kFamilyNodeWidth / 2 - painter.width - 18,
        centre.dy - kFamilyAvatarCentreOffset - painter.height / 2,
      );
      if (origin.dx < 0 || origin.dy < 0 || origin.dy > size.height) continue;
      painter.paint(canvas, origin);
    }
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    final total = (end - start).distance;
    if (total < 1) return;
    final unit = (end - start) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final next = travelled + dash < total ? travelled + dash : total;
      canvas.drawLine(start + unit * travelled, start + unit * next, paint);
      travelled = next + gap;
    }
  }

  @override
  bool shouldRepaint(RosterEdgePainter old) =>
      old.subgraph != subgraph ||
      old.group != group ||
      old.positions != positions ||
      old.projection.pan != projection.pan ||
      old.projection.zoom != projection.zoom ||
      old.selectedId != selectedId;
}
