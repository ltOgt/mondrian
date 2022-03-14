import 'package:flutter/material.dart';

class WindowMoveHandle extends StatefulWidget {
  const WindowMoveHandle({
    required this.child,
    required this.dragIndicator,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
  });

  final Widget child;
  final Widget dragIndicator;
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
              return Stack(
                children: [
                  Positioned(
                    top: indicatorOffset!.dy,
                    left: indicatorOffset!.dx,
                    child: widget.dragIndicator,
                  ),
                ],
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
        onPanEnd: (_) {
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

class WindowMoveTarget extends StatelessWidget {
  const WindowMoveTarget({
    Key? key,
    required this.isActive,
    required this.child,
    required this.target,
  }) : super(key: key);

  final bool isActive;
  final Widget child;
  final Widget target;

  static const _targetLarge = 20.0;
  static const _targetSmall = 10.0;
  static const _targetGap = SizedBox.square(dimension: 5.0);

  Widget _target({
    required double width,
    required double height,
  }) =>
      SizedBox(
        width: width,
        height: height,
        child: target,
      );
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
                        width: _targetSmall,
                        height: _targetLarge,
                      ),
                      _targetGap,
                      // CENTER
                      _target(
                        width: _targetLarge,
                        height: _targetLarge,
                      ),
                      _targetGap,
                      // RIGHT
                      _target(
                        width: _targetSmall,
                        height: _targetLarge,
                      ),
                    ],
                  ),
                  _targetGap,
                  // BOTTOM

                  _target(
                    width: _targetLarge,
                    height: _targetSmall,
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}
