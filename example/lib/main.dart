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

  MondrianTreeLeafId? movingId;
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
        body: MondrianWidget(
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

final k_tabs = <MondrianTreeTabLeafId, TabbedWindow>{
  const MondrianTreeTabLeafId("Tab Group 1"): const TabbedWindow(
    id: MondrianTreeTabLeafId("Tab Group 1"),
    tabs: [
      MondrianTreeLeafId("Tab Child 1"),
      MondrianTreeLeafId("Tab Child 2"),
      MondrianTreeLeafId("Tab Child 3"),
    ],
    activeTabIndex: 0,
  ),
};
final k_tree = MondrianTree(
  rootAxis: MondrianAxis.vertical,
  rootNode: MondrianTreeBranch(
    fraction: 1,
    children: [
      MondrianTreeBranch(
        fraction: .7,
        children: [
          MondrianTreeTabLeaf(
            fraction: .7,
            tabs: const [
              MondrianTreeLeafId("Tab Child 1"),
              MondrianTreeLeafId("Tab Child 2"),
              MondrianTreeLeafId("Tab Child 3"),
            ],
            activeTabIndex: 0,
          ),
          const MondrianTreeBranch(
            fraction: .3,
            children: [
              MondrianTreeLeaf(
                fraction: .5,
                id: MondrianTreeLeafId("Medium Top Right"),
              ),
              MondrianTreeLeaf(
                fraction: .5,
                id: MondrianTreeLeafId("Small Mid Right"),
              ),
            ],
          ),
        ],
      ),
      const MondrianTreeBranch(
        fraction: .3,
        children: [
          MondrianTreeLeaf(
            fraction: .3,
            id: MondrianTreeLeafId("Bottom Left"),
          ),
          MondrianTreeLeaf(
            fraction: .3,
            id: MondrianTreeLeafId("Bottom Mid"),
          ),
          MondrianTreeLeaf(
            fraction: .4,
            id: MondrianTreeLeafId("Bottom Right"),
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
  final Function(MondrianMoveTargetDropPosition position) onDrop;

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
