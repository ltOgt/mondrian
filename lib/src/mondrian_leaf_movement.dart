import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:mondrian/mondrian.dart';

// ============================================================================= DROP POSITION

/// The position inside the [MondrianLeafMoveTarget] where the [MondrianLeafMoveHandle] was dropped.
/// Depending on the drop position, the tree has to be altered in different ways.
enum MondrianLeafMoveTargetDropPosition {
  top,
  left,
  center,
  right,
  bottom,
}

// TODO still need to use the helpers provided by this extension in more of the movement code
extension MondrianLeafMoveTargetDropPositionX on MondrianLeafMoveTargetDropPosition {
  bool get isTop => this == MondrianLeafMoveTargetDropPosition.top;
  bool get isLeft => this == MondrianLeafMoveTargetDropPosition.left;
  bool get isCenter => this == MondrianLeafMoveTargetDropPosition.center;
  bool get isRight => this == MondrianLeafMoveTargetDropPosition.right;
  bool get isBottom => this == MondrianLeafMoveTargetDropPosition.bottom;

  MondrianAxis? get asAxis {
    switch (this) {
      case MondrianLeafMoveTargetDropPosition.center:
        return null;
      case MondrianLeafMoveTargetDropPosition.left:
      case MondrianLeafMoveTargetDropPosition.right:
        return MondrianAxis.horizontal;
      case MondrianLeafMoveTargetDropPosition.top:
      case MondrianLeafMoveTargetDropPosition.bottom:
        return MondrianAxis.vertical;
    }
  }

  bool? get isPositionBefore {
    switch (this) {
      case MondrianLeafMoveTargetDropPosition.center:
        return null;
      case MondrianLeafMoveTargetDropPosition.top:
      case MondrianLeafMoveTargetDropPosition.left:
        return true;
      case MondrianLeafMoveTargetDropPosition.right:
      case MondrianLeafMoveTargetDropPosition.bottom:
        return false;
    }
  }

  bool? get isPositionAfter {
    switch (this) {
      case MondrianLeafMoveTargetDropPosition.center:
        return null;
      case MondrianLeafMoveTargetDropPosition.top:
      case MondrianLeafMoveTargetDropPosition.left:
        return false;
      case MondrianLeafMoveTargetDropPosition.right:
      case MondrianLeafMoveTargetDropPosition.bottom:
        return true;
    }
  }
}

// ============================================================================= MOVE HANDLE

/// Wrap [child] with this widget to enable dragging it onto [MondrianLeafMoveTarget]s.
class MondrianLeafMoveHandle extends StatefulWidget {
  const MondrianLeafMoveHandle({
    Key? key,
    required this.child,
    required this.dragIndicator,
    this.dragIndicatorSize = const Size(40, 40),
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.leafPathOfMoving,
  }) : super(key: key);

  /// The widget that should be draggable.
  final Widget child;

  /// The widget that will be displayed under the cursor during dragging.
  final Widget dragIndicator;

  /// The size of [dragIndicator].
  /// This is used to center the indicator under the cursor.
  final Size dragIndicatorSize;

  /// Called when the moving starts.
  final VoidCallback onMoveStart;

  /// Called when the moving continues.
  final Function(DragUpdateDetails d) onMoveUpdate;

  /// Called when the moving ends.
  final VoidCallback onMoveEnd;

  /// The path to the leaf that is beeing dragged
  final MondrianTreePathWithTabIndexIfAny leafPathOfMoving;

  @override
  State<MondrianLeafMoveHandle> createState() => _MondrianLeafMoveHandleState();
}

class _MondrianLeafMoveHandleState extends State<MondrianLeafMoveHandle> {
  /// The current offset of the cursor that is dragging the [widget.dragIndicator].
  Offset? _indicatorOffset;

  /// The overlay that contains and positions the [widget.dragIndicator] during movement.
  OverlayEntry? _indicatorOverlayEntry;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        child: widget.child,
        onPanStart: (d) {
          setState(() {
            _indicatorOffset = d.globalPosition;
            _indicatorOverlayEntry = OverlayEntry(builder: (context) {
              return IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      width: widget.dragIndicatorSize.width,
                      height: widget.dragIndicatorSize.height,
                      top: _indicatorOffset!.dy - (widget.dragIndicatorSize.height / 2),
                      left: _indicatorOffset!.dx - (widget.dragIndicatorSize.width / 2),
                      child: widget.dragIndicator,
                    ),
                  ],
                ),
              );
            });
            Overlay.of(context)!.insert(_indicatorOverlayEntry!);
          });
          widget.onMoveStart();
        },
        onPanUpdate: (d) {
          setState(() {
            _indicatorOffset = d.globalPosition;
            Overlay.of(context)!.setState(() {});
          });
          widget.onMoveUpdate(d);
        },
        onPanEnd: (d) {
          /// Check if the indicator has been dropped above a [MondrianLeafMoveTarget].
          /// If so, the target will have injected [MondrianLeafMoveTargetMetaData] into the tree.
          final HitTestResult r = HitTestResult();
          WidgetsBinding.instance.hitTest(r, _indicatorOffset!);
          for (final HitTestEntry hte in r.path) {
            final target = hte.target;

            if (target is RenderMetaData) {
              final metaData = target.metaData;
              if (metaData is MondrianLeafMoveTargetMetaData) {
                /// Call the callback registered in the [MondrianLeafMoveTarget]
                metaData.onDrop(widget.leafPathOfMoving);
              }
            }
          }

          setState(() {
            _indicatorOffset = null;
            _indicatorOverlayEntry!.remove();
            _indicatorOverlayEntry = null;
          });

          widget.onMoveEnd();
        },
      ),
    );
  }
}

// ============================================================================= DROP TARGET
class MondrianLeafMoveTargetMetaData {
  final void Function(MondrianTreePathWithTabIndexIfAny leafPathOfMoving) onDrop;

  MondrianLeafMoveTargetMetaData({
    required this.onDrop,
  });
}

class MondrianLeafMoveTarget extends StatelessWidget {
  const MondrianLeafMoveTarget({
    Key? key,
    required this.isActive,
    required this.child,
    required this.buildTargetPositionIndicators,
    required this.onDrop,
  }) : super(key: key);

  /// Whether this target can receive [MondrianLeafMoveHandle]s.
  ///
  /// Turned of e.g. for the leaf that is beeing moved.
  final bool isActive;

  /// The widget above which the move target should appear
  final Widget child;

  /// {@macro DropTargetWidgetBuilder}
  final DropTargetWidgetBuilder buildTargetPositionIndicators;

  /// The callback that will be executed if a [MondrianLeafMoveHandle] is dropped on this target.
  ///
  /// [position] is the side on which the handle was dropped.
  /// [leafPathOfMoving] is the path to the leaf that was dropped.
  final Function(
    MondrianLeafMoveTargetDropPosition position,
    MondrianTreePathWithTabIndexIfAny leafPathOfMoving,
  ) onDrop;

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: child),
            buildTargetPositionIndicators(
              (position, child) => MetaData(
                metaData: MondrianLeafMoveTargetMetaData(
                  onDrop: (leafPathOfMoving) => onDrop(position, leafPathOfMoving),
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.cell,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
