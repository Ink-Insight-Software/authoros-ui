/// Drawing a family: portraits in rings, and the orthogonal lines between.
///
/// The general graph draws a labelled chip and a straight line, because that is
/// what reads best when a node might be a location, a scene or a plot beat. A
/// family is all people, so it can afford the thing people actually recognise
/// as a family tree — a face, a name, a lifespan, and square connectors that
/// descend rather than point.
///
/// Geometry here is in canvas pixels and deliberately unscaled by zoom, which
/// is the same choice `GraphCanvas` already makes for its chips: a node keeps
/// its size while the arrangement spreads out, so a zoomed-out tree stays
/// readable instead of turning into confetti.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:authoros_core/story_graph.dart';
import 'family_tree.dart';
import 'graph_canvas.dart';
import 'graph_layout.dart';

/// The drawn size of one person.
const double kFamilyNodeWidth = 128;
const double kFamilyNodeHeight = 104;

/// The portrait circle, and where it sits inside the node box.
const double kFamilyAvatarDiameter = 60;

/// Distance from the node's centre up to the centre of its portrait.
const double kFamilyAvatarCentreOffset =
    (kFamilyNodeHeight - kFamilyAvatarDiameter) / 2;

/// How far above the child row the shared horizontal run sits.
const double kFamilySiblingBusOffset = 30;

/// One person's card: portrait, name, lifespan.
class FamilyNodeCard extends StatelessWidget {
  const FamilyNodeCard({
    super.key,
    required this.node,
    required this.palette,
    required this.ringColour,
    required this.isRoot,
    required this.isSelected,
    this.portrait,
    this.caption,
    this.captionStruck = false,
    this.onTap,
    this.onOpen,
    this.onPickPhoto,
    this.onRemovePhoto,
  });

  final StoryGraphNode node;
  final GraphPalette palette;

  /// The descent line's colour, so a reader can tell a Cruz from a Young
  /// without reading a surname.
  final Color ringColour;
  final bool isRoot;
  final bool isSelected;

  /// This person's picture, if they have one.
  ///
  /// The host resolves it — from the photo the project stores, or from a path
  /// a character was given before photos were stored — so this widget never
  /// reads storage or the file system itself.
  final ImageProvider? portrait;

  /// The second line under the name. Defaults to the person's lifespan, which
  /// is what descent has to say about them; a roster passes their rank instead,
  /// which is what belonging has to say.
  final String? caption;

  /// Draws the caption struck through — a membership that has ended.
  final bool captionStruck;

  final VoidCallback? onTap;
  final VoidCallback? onOpen;

  /// Set or replace this person's photo. Null where the tree is read-only.
  final VoidCallback? onPickPhoto;

  /// Clear it. Null when there is nothing to clear.
  final VoidCallback? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final dates = familyLifeDates(node);
    final line = caption ?? dates.label;
    final provider = portrait;

    return Semantics(
      button: true,
      selected: isSelected,
      label: dates.label.isEmpty ? node.title : '${node.title}, ${dates.label}',
      child: Tooltip(
        message:
            dates.label.isEmpty ? node.title : '${node.title} · ${dates.label}',
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onDoubleTap: onOpen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatar(context, provider),
              const SizedBox(height: 6),
              Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: palette.title.copyWith(fontWeight: FontWeight.w600),
              ),
              if (line.isNotEmpty)
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: palette.label.copyWith(
                    color: ringColour,
                    decoration:
                        captionStruck ? TextDecoration.lineThrough : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The portrait circle, with the control that changes it.
  ///
  /// The button sits on the picture rather than in a panel elsewhere: the thing
  /// being changed is right there, and an author looking at a face they want to
  /// replace should not have to go and find where photos are kept.
  Widget _avatar(BuildContext context, ImageProvider? provider) {
    final emphasis = isSelected || isRoot;
    return SizedBox(
      width: kFamilyNodeWidth,
      height: kFamilyAvatarDiameter,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _ring(context, provider, emphasis),
          if (onPickPhoto != null && (isSelected || isRoot))
            Positioned(
              right: (kFamilyNodeWidth - kFamilyAvatarDiameter) / 2 - 8,
              bottom: -2,
              child: _photoButton(context),
            ),
        ],
      ),
    );
  }

  Widget _photoButton(BuildContext context) {
    final hasPhoto = portrait != null;
    return Material(
      color: palette.surface,
      shape: CircleBorder(
        side: BorderSide(color: palette.outline.withValues(alpha: 0.6)),
      ),
      elevation: 1,
      child: InkWell(
        key: Key('family-photo-button-${node.id}'),
        customBorder: const CircleBorder(),
        // A long press clears the picture, so removing one does not need a
        // second control taking up room beside a sixty-pixel circle.
        onTap: onPickPhoto,
        onLongPress: onRemovePhoto,
        child: Tooltip(
          message:
              hasPhoto ? 'Change photo. Long press to remove.' : 'Add a photo',
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              hasPhoto ? Icons.edit_outlined : Icons.add_a_photo_outlined,
              size: 13,
              color: palette.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(BuildContext context, ImageProvider? provider, bool emphasis) {
    return Container(
      width: kFamilyAvatarDiameter,
      height: kFamilyAvatarDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(
          color: emphasis ? palette.primary : ringColour,
          width: emphasis ? 3.5 : 2.5,
        ),
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
        boxShadow: [
          BoxShadow(
            color: ringColour.withValues(alpha: emphasis ? 0.34 : 0.16),
            blurRadius: emphasis ? 12 : 6,
          ),
        ],
      ),
      // A character with no portrait still needs a face-shaped thing
      // in the ring, or their branch reads as a hole in the tree.
      child: provider != null
          ? null
          : Center(
              child: Text(
                familyInitials(node.title),
                style: palette.title.copyWith(
                  color: ringColour,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
    );
  }
}

/// How a person is drawn on a family tree.
enum FamilyNodeStyle {
  /// [FamilyNodeCard]: portrait, name and lifespan, with a tooltip and the
  /// photo control, each person a widget. What a reader looks at.
  portrait,

  /// [FamilyMarkPainter]: a small ring in the line's colour and the name,
  /// painted. What a reader scans: hundreds of people at once, for the cost
  /// of one widget rather than one each.
  compact,
}

/// The ring a compact mark draws, centred where a card's portrait is so the
/// same lines meet it.
const double kFamilyMarkDiameter = 26;

/// Every person on a family tree drawn small: a ring and a name, painted.
///
/// For a tree too large to read face by face. A portrait card is some thirty
/// elements, so six hundred people on screen were eighteen thousand before a
/// frame could draw; painted, they are none. Each mark keeps a card's
/// geometry (the ring sits where the portrait would, so every bond and
/// descent line lands on it unchanged), and each still answers a screen
/// reader with the name and lifespan a card would say, through
/// [semanticsBuilder]. Taps are found with [personAt].
class FamilyMarkPainter extends CustomPainter {
  const FamilyMarkPainter({
    required this.subgraph,
    required this.positions,
    required this.projection,
    required this.palette,
    required this.colourOf,
    this.selectedId,
    this.onTap,
  });

  final StorySubgraph subgraph;
  final Map<String, Offset> positions;
  final GraphProjection projection;
  final GraphPalette palette;

  /// The colour of a person's ring: their line's, or one the host chose.
  final Color Function(String id) colourOf;
  final String? selectedId;

  /// What a screen reader's tap on a person does.
  final ValueChanged<StoryGraphNode>? onTap;

  /// The card-sized box a person occupies on the canvas.
  static Rect footprint(Offset centre) => Rect.fromCenter(
        center: centre,
        width: kFamilyNodeWidth,
        height: kFamilyNodeHeight,
      );

  /// The person whose footprint holds the canvas point [at], nearest first,
  /// or null on empty ground.
  static StoryGraphNode? personAt(
    Offset at, {
    required StorySubgraph subgraph,
    required Map<String, Offset> positions,
    required GraphProjection projection,
  }) {
    StoryGraphNode? best;
    var distance = double.infinity;
    for (final node in subgraph.nodes) {
      final model = positions[node.id];
      if (model == null) continue;
      final centre = projection.toCanvas(model);
      if (!footprint(centre).contains(at)) continue;
      final d = (centre - at).distanceSquared;
      if (d < distance) {
        distance = d;
        best = node;
      }
    }
    return best;
  }

  Iterable<(StoryGraphNode, Offset)> _visible(Size size) sync* {
    final screen = (Offset.zero & size).inflate(kFamilyNodeWidth);
    for (final node in subgraph.nodes) {
      final model = positions[node.id];
      if (model == null) continue;
      final centre = projection.toCanvas(model);
      if (screen.contains(centre)) yield (node, centre);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (node, centre) in _visible(size)) {
      final ring = centre.translate(0, -kFamilyAvatarCentreOffset);
      final colour = colourOf(node.id);
      final selected = node.id == selectedId;
      canvas.drawCircle(
        ring,
        kFamilyMarkDiameter / 2,
        Paint()..color = colour.withValues(alpha: selected ? 0.9 : 0.35),
      );
      canvas.drawCircle(
        ring,
        kFamilyMarkDiameter / 2,
        Paint()
          ..color = selected ? palette.primary : colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 2,
      );
      final name = TextPainter(
        text: TextSpan(
          text: node.title,
          style: palette.label.copyWith(color: palette.onSurface),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: kFamilyNodeWidth);
      name.paint(
        canvas,
        ring.translate(-name.width / 2, kFamilyMarkDiameter / 2 + 4),
      );
      name.dispose();
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) => [
        for (final (node, centre) in _visible(size))
          CustomPainterSemantics(
            key: ValueKey('family-mark-${node.id}'),
            rect: footprint(centre),
            properties: SemanticsProperties(
              button: true,
              selected: node.id == selectedId,
              label: familyLifeDates(node).label.isEmpty
                  ? node.title
                  : '${node.title}, ${familyLifeDates(node).label}',
              textDirection: TextDirection.ltr,
              onTap: onTap == null ? null : () => onTap!(node),
            ),
          ),
      ];

  @override
  bool shouldRepaint(FamilyMarkPainter old) =>
      old.subgraph != subgraph ||
      old.positions != positions ||
      old.projection.pan != projection.pan ||
      old.projection.zoom != projection.zoom ||
      old.selectedId != selectedId ||
      old.colourOf != colourOf;

  @override
  bool shouldRebuildSemantics(FamilyMarkPainter old) => shouldRepaint(old);
}

/// Couple bonds and descent lines, drawn square.
///
/// Straight point-to-point lines are what make a general graph legible and what
/// make a family tree unreadable: six siblings produce six diverging diagonals
/// out of one point. Descent is drawn as a trunk down, a shared run across, and
/// a drop into each child — the shape a reader already knows how to follow.
class FamilyEdgePainter extends CustomPainter {
  const FamilyEdgePainter({
    required this.subgraph,
    required this.family,
    required this.positions,
    required this.projection,
    required this.palette,
    required this.lineageColours,
    this.ringColours = const {},
    this.selectedId,
  });

  final StorySubgraph subgraph;
  final FamilyStructure family;
  final Map<String, Offset> positions;
  final GraphProjection projection;
  final GraphPalette palette;

  /// The categorical ramp, indexed by lineage.
  final List<Color> lineageColours;

  /// Colours the host chose for particular people (a House's, say), in place
  /// of their line's. A line takes the colour of the person it starts from.
  final Map<String, Color> ringColours;
  final String? selectedId;

  Color _lineageColour(String id) =>
      ringColours[id] ??
      (lineageColours.isEmpty
          ? palette.outline
          : lineageColours[family.lineageIndexOf(id) % lineageColours.length]);

  Offset? _canvasOf(String id) {
    final model = positions[id];
    return model == null ? null : projection.toCanvas(model);
  }

  /// The centre of a person's portrait circle.
  Offset? _portraitCentre(String id) {
    final centre = _canvasOf(id);
    return centre?.translate(0, -kFamilyAvatarCentreOffset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintDescent(canvas);
    _paintBonds(canvas);
  }

  /// Every partnership, including the second marriage the packer could not
  /// place as a pair — a bond the author recorded is a bond the tree draws.
  void _paintBonds(Canvas canvas) {
    for (final edge in subgraph.edges) {
      if (!kFamilyPartnerEdgeTypes.contains(edge.typeId)) continue;
      final left = _portraitCentre(edge.sourceId);
      final right = _portraitCentre(edge.targetId);
      if (left == null || right == null) continue;

      final colour = _lineageColour(edge.sourceId);
      final touched =
          selectedId == edge.sourceId || selectedId == edge.targetId;
      final paint = Paint()
        ..color = colour.withValues(alpha: touched ? 1 : 0.8)
        ..strokeWidth = touched ? 2.4 : 1.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(left, right, paint);

      final midpoint = Offset(
        (left.dx + right.dx) / 2,
        (left.dy + right.dy) / 2,
      );
      // A plate under the heart, or the bond line shows through its notch.
      canvas.drawCircle(
        midpoint,
        7,
        Paint()..color = palette.background,
      );
      canvas.drawPath(
        _heartPath(midpoint, 11),
        Paint()..color = colour,
      );
    }
  }

  void _paintDescent(Canvas canvas) {
    for (final unit in family.units) {
      final children = unit.childUnitKeys
          .map((key) => _descendantIn(key, unit))
          .whereType<String>()
          .where(positions.containsKey)
          .toList();
      if (children.isEmpty) continue;

      final origin = _descentOrigin(unit);
      if (origin == null) continue;

      final childTops = <String, Offset>{};
      for (final childId in children) {
        final centre = _canvasOf(childId);
        if (centre == null) continue;
        childTops[childId] = centre.translate(0, -kFamilyNodeHeight / 2);
      }
      if (childTops.isEmpty) continue;

      final colour = _lineageColour(unit.members.first);
      final touched = selectedId != null &&
          (unit.members.contains(selectedId) ||
              childTops.keys.contains(selectedId));
      final paint = Paint()
        ..color = colour.withValues(alpha: touched ? 0.95 : 0.6)
        ..strokeWidth = touched ? 2.2 : 1.6
        ..style = PaintingStyle.stroke;

      final busY = childTops.values.map((top) => top.dy).reduce(math.min) -
          kFamilySiblingBusOffset;

      // The trunk down from the couple, or from below a single parent's card.
      canvas.drawLine(origin, Offset(origin.dx, busY), paint);

      // One shared run across, so siblings hang from the same line.
      final xs = [origin.dx, ...childTops.values.map((top) => top.dx)];
      canvas.drawLine(
        Offset(xs.reduce(math.min), busY),
        Offset(xs.reduce(math.max), busY),
        paint,
      );

      for (final entry in childTops.entries) {
        // Parenthood by care is real parenthood and gets a line, but not the
        // same line — a reader should be able to see which ties are blood.
        final byBlood = _descentIsBlood(unit, entry.key);
        final drop = Offset(entry.value.dx, busY);
        if (byBlood) {
          canvas.drawLine(drop, entry.value, paint);
        } else {
          _drawDashed(canvas, drop, entry.value, paint);
        }
      }
    }
  }

  /// Where a unit's descent line starts.
  ///
  /// A couple's children come from the point between them, which is the whole
  /// visual argument for pairing them. A lone parent has a name and a lifespan
  /// under their portrait, so their line has to start below the card rather
  /// than through the text.
  Offset? _descentOrigin(FamilyUnit unit) {
    if (unit.isCouple) {
      final left = _portraitCentre(unit.members.first);
      final right = _portraitCentre(unit.members.last);
      if (left == null || right == null) return null;
      return Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);
    }
    final centre = _canvasOf(unit.members.first);
    return centre?.translate(0, kFamilyNodeHeight / 2);
  }

  /// Which half of a child unit actually descends from [parent].
  ///
  /// A grown child drawn beside the person they married is one unit of two, and
  /// the descent line belongs to the child — pointing it at their spouse would
  /// draw the in-law as the blood heir.
  String? _descendantIn(String childUnitKey, FamilyUnit parent) {
    final members = childUnitKey.split('+');
    for (final member in members) {
      final above = family.parents[member] ?? const <String>[];
      if (above.any(parent.members.contains)) return member;
    }
    return members.isEmpty ? null : members.first;
  }

  bool _descentIsBlood(FamilyUnit unit, String childId) {
    for (final edge in subgraph.edges) {
      if (edge.targetId != childId) continue;
      if (!unit.members.contains(edge.sourceId)) continue;
      if (edge.typeId == 'parentOf') return true;
    }
    return false;
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (end - start).distance;
    if (total < 1) return;
    final unit = (end - start) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final next = math.min(travelled + dash, total);
      canvas.drawLine(start + unit * travelled, start + unit * next, paint);
      travelled = next + gap;
    }
  }

  Path _heartPath(Offset centre, double size) {
    final width = size;
    final height = size;
    return Path()
      ..moveTo(centre.dx, centre.dy + height * 0.36)
      ..cubicTo(
        centre.dx - width * 0.78,
        centre.dy - height * 0.08,
        centre.dx - width * 0.5,
        centre.dy - height * 0.62,
        centre.dx,
        centre.dy - height * 0.22,
      )
      ..cubicTo(
        centre.dx + width * 0.5,
        centre.dy - height * 0.62,
        centre.dx + width * 0.78,
        centre.dy - height * 0.08,
        centre.dx,
        centre.dy + height * 0.36,
      )
      ..close();
  }

  @override
  bool shouldRepaint(FamilyEdgePainter old) =>
      old.subgraph != subgraph ||
      old.family != family ||
      old.positions != positions ||
      old.projection.pan != projection.pan ||
      old.projection.zoom != projection.zoom ||
      old.selectedId != selectedId ||
      old.lineageColours != lineageColours ||
      old.ringColours != ringColours;
}
