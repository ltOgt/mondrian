import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

class WindowMoveHandle extends StatefulWidget {
  const WindowMoveHandle({
    required this.child,
    required this.dragIndicator,
    this.dragIndicatorSize = const Size(40, 40),
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
  });

  final Widget child;
  final Widget dragIndicator;
  final Size dragIndicatorSize;
  final VoidCallback onMoveStart;
  final Function(DragUpdateDetails d) onMoveUpdate;
  final VoidCallback onMoveEnd;

  @override
  State<WindowMoveHandle> createState() => _WindowMoveHandleState();
}

class _WindowMoveHandleState extends State<WindowMoveHandle> {
  Offset? indicatorOffset;
  OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        onPanStart: (d) {
          setState(() {
            indicatorOffset = d.globalPosition;
            entry = OverlayEntry(builder: (context) {
              return IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      width: widget.dragIndicatorSize.width,
                      height: widget.dragIndicatorSize.height,
                      top: indicatorOffset!.dy - (widget.dragIndicatorSize.height / 2),
                      left: indicatorOffset!.dx - (widget.dragIndicatorSize.width / 2),
                      child: widget.dragIndicator,
                    ),
                  ],
                ),
              );
            });
            Overlay.of(context)!.insert(entry!);
          });
          widget.onMoveStart();
        },
        onPanUpdate: (d) {
          setState(() {
            indicatorOffset = d.globalPosition;
            Overlay.of(context)!.setState(() {});
          });
          widget.onMoveUpdate(d);
        },
        onPanEnd: (d) {
          final HitTestResult r = HitTestResult();
          WidgetsBinding.instance.hitTest(r, indicatorOffset!);
          for (final HitTestEntry hte in r.path) {
            final target = hte.target;

            if (target is RenderMetaData) {
              final metaData = target.metaData;
              if (metaData is WindowMoveTargetMetaData) {
                metaData.onDrop();
              }
            }
          }

          setState(() {
            indicatorOffset = null;
            entry!.remove();
            entry = null;
          });

          widget.onMoveEnd();
        },
        child: widget.child,
      ),
    );
  }
}

enum MondrianMoveTargetDropPosition {
  top,
  left,
  center,
  right,
  bottom,
}

extension WindowMoveTargetDropPositionX on MondrianMoveTargetDropPosition {
  bool get isTop => this == MondrianMoveTargetDropPosition.top;
  bool get isLeft => this == MondrianMoveTargetDropPosition.left;
  bool get isCenter => this == MondrianMoveTargetDropPosition.center;
  bool get isRight => this == MondrianMoveTargetDropPosition.right;
  bool get isBottom => this == MondrianMoveTargetDropPosition.bottom;
}

class WindowMoveTargetMetaData {
  final VoidCallback onDrop;

  WindowMoveTargetMetaData({
    required this.onDrop,
  });
}

class WindowMoveTarget extends StatelessWidget {
  const WindowMoveTarget({
    Key? key,
    required this.isActive,
    required this.child,
    required this.target,
    required this.onDrop,
  }) : super(key: key);

  final bool isActive;
  final Widget child;
  final Widget target;

  static const _targetLarge = 30.0;
  static const _targetSmall = 20.0;
  static const _targetGap = SizedBox.square(dimension: 5.0);

  final Function(MondrianMoveTargetDropPosition position) onDrop;

  Widget _target({
    required double width,
    required double height,
    required MondrianMoveTargetDropPosition position,
  }) =>
      MetaData(
        metaData: WindowMoveTargetMetaData(
          onDrop: () => onDrop(position),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.cell,
          child: SizedBox(
            width: width,
            height: height,
            child: target,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: child),
            if (isActive)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOP
                    _target(
                      position: MondrianMoveTargetDropPosition.top,
                      width: _targetLarge,
                      height: _targetSmall,
                    ),
                    _targetGap,
                    // LEFT CENTER RIGHT
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LEFT
                        _target(
                          position: MondrianMoveTargetDropPosition.left,
                          width: _targetSmall,
                          height: _targetLarge,
                        ),
                        _targetGap,
                        // CENTER
                        _target(
                          position: MondrianMoveTargetDropPosition.center,
                          width: _targetLarge,
                          height: _targetLarge,
                        ),
                        _targetGap,
                        // RIGHT
                        _target(
                          position: MondrianMoveTargetDropPosition.right,
                          width: _targetSmall,
                          height: _targetLarge,
                        ),
                      ],
                    ),
                    _targetGap,
                    // BOTTOM
                    _target(
                      position: MondrianMoveTargetDropPosition.bottom,
                      width: _targetLarge,
                      height: _targetSmall,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
