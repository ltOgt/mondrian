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
  var tabs = k_tabs;

  WindowManagerLeafId? movingId;
  List<int>? lastMovingPath;

  void toggleDebugPaint() {
    MondrianDebugSingleton.instance.toggleBranchDebugPainting();
    setState(() {});
  }

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
        body: MondrianWithTabs(
          tabs: tabs,
          onTabSwitch: (t) {
            setState(() {
              tabs[t.id] = t;
            });
          },
          tree: tree,
          onMoveDone: (tree) {
            setState(() {
              this.tree = tree;
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

final k_tabs = <WindowManagerTabLeafId, TabbedWindow>{
  const WindowManagerTabLeafId("Tab Group 1"): const TabbedWindow(
    id: WindowManagerTabLeafId("Tab Group 1"),
    tabs: [
      WindowManagerLeafId("Tab Child 1"),
      WindowManagerLeafId("Tab Child 2"),
      WindowManagerLeafId("Tab Child 3"),
    ],
    activeTabIndex: 0,
  ),
};
const k_tree = WindowManagerTree(
  rootAxis: WindowAxis.vertical,
  rootNode: WindowManagerBranch(
    fraction: 1,
    children: [
      WindowManagerBranch(
        fraction: .7,
        children: [
          WindowManagerLeaf(
            fraction: .7,
            //id: WindowManagerLeafId("Big top left"),
            id: WindowManagerTabLeafId("Tab Group 1"),
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
