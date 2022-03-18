import 'package:flutter/widgets.dart';
import 'package:mondrian/mondrian.dart';

class MondrianDebugSingleton {
  static MondrianDebugSingleton instance = MondrianDebugSingleton._();
  MondrianDebugSingleton._();
  factory MondrianDebugSingleton() => instance;

  /// Public variable to toggle debug painting of branches
  bool mondrianShowBranchDebugPaint = false;
  void toggleBranchDebugPainting() {
    mondrianShowBranchDebugPaint = !mondrianShowBranchDebugPaint;
  }

  // transparent red
  static const Color color = Color(0x88FF3333);
}

/// Overlays a branch group with a border, whos width increases with tree depth.
class MondrianBranchDebugOverlay extends StatelessWidget {
  const MondrianBranchDebugOverlay({
    Key? key,
    required this.path,
    required this.child,
  }) : super(key: key);

  final MondrianTreePath path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (false == MondrianDebugSingleton.instance.mondrianShowBranchDebugPaint) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: MondrianDebugSingleton.color,
                  width: 10.0 * path.length,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
