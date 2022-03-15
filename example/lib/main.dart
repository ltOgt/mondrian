import 'package:flutter/material.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var tree = k_tree;

  WindowManagerLeafId? movingId;
  List<int>? lastMovingPath;

  void toggleDebugPaint() {
    MondrianDebugSingleton.instance.toggleBranchDebugPainting();
    setState(() {});
  }

  Axis initialAxis = Axis.vertical;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mondrian Example',
      theme: ThemeData.dark(),
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: toggleDebugPaint,
          child: const Icon(Icons.brush),
        ),
        body: MondrianMoveable(
          axis: initialAxis,
          tree: tree,
          onMoveDone: (tree, axis) {
            setState(() {
              this.tree = tree;
              initialAxis = axis;
            });
          },
          onResizeDone: (tree) {
            setState(() {
              this.tree = tree;
            });
          },
        ),
      ),
    );
  }
}

const k_tree = WindowManagerTree(
  rootNode: WindowManagerBranch(
    fraction: 1,
    children: [
      WindowManagerBranch(
        fraction: .7,
        children: [
          WindowManagerLeaf(
            fraction: .7,
            id: WindowManagerLeafId("Big top left"),
          ),
          WindowManagerBranch(
            fraction: .3,
            children: [
              WindowManagerLeaf(
                fraction: .5,
                id: WindowManagerLeafId("Medium Top Right"),
              ),
              WindowManagerLeaf(
                fraction: .5,
                id: WindowManagerLeafId("Small Mid Right"),
              ),
            ],
          ),
        ],
      ),
      WindowManagerBranch(
        fraction: .3,
        children: [
          WindowManagerLeaf(
            fraction: .3,
            id: WindowManagerLeafId("Bottom Left"),
          ),
          WindowManagerLeaf(
            fraction: .3,
            id: WindowManagerLeafId("Bottom Mid"),
          ),
          WindowManagerLeaf(
            fraction: .4,
            id: WindowManagerLeafId("Bottom Right"),
          ),
        ],
      )
    ],
  ),
);

class WindowExample extends StatelessWidget {
  const WindowExample({
    required this.text,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.isMoving,
    required this.onDrop,
  });

  final String text;
  final VoidCallback onMoveStart;
  final Function(DragUpdateDetails d) onMoveUpdate;
  final VoidCallback onMoveEnd;
  final bool isMoving;
  final Function(WindowMoveTargetDropPosition position) onDrop;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WindowMoveHandle(
          dragIndicator: Container(
            height: 100,
            width: 100,
            color: Colors.white.withAlpha(100),
          ),
          child: Container(
            height: 10,
            color: Colors.black,
          ),
          onMoveEnd: onMoveEnd,
          onMoveStart: onMoveStart,
          onMoveUpdate: onMoveUpdate,
        ),
        Expanded(
          child: WindowMoveTarget(
            onDrop: onDrop,
            isActive: isMoving,
            target: Container(
              color: Colors.red,
            ),
            child: Center(
              child: AutoSizeText(text: text),
            ),
          ),
        ),
      ],
    );
  }
}

/*


________________________________
                        |
                        |
                        |_______
                        |
________________________|_______
          |         |
__________|_________|___________


Column(
  0.70: Row(
    0.70: WINDOW
    0.30: Column(
      0.60: WINDOW
      0.40: WINDOW
    )
  )
  0.30: Row(
    0.30: WINDOW
    0.30: WINDOW
    0.40: WINDOW
  )
)
*/
