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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mondrian Example',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MondrianWM(
          tree: tree,
          initialAxis: Axis.vertical,
          onResize: (pathToParent, newFraction, index) {
            tree = tree.updatePath(pathToParent, (node) {
              return (node as WindowManagerBranch).updateChildFraction(
                index: index,
                newFraction: newFraction,
              );
            });
            setState(() {});
          },
          resolveLeafToWidget: (id, path, axis) => WindowExample(
            // Needed to put in meta data <
            path: path,
            axis: axis,
            // Needed to put in meta data >
            text: id.value,
            onMoveStart: () {
              movingId = id;
              lastMovingPath = path;
              setState(() {});
            },
            onMoveEnd: () {
              movingId = null;
              setState(() {});
            },
            onMoveUpdate: (d) {},
            isMoving: movingId != null && movingId != id,
            onDrop: (pos) {
              final sourcePath = lastMovingPath!;

              final targetPath = path;
              final targetPathToParent = path.sublist(0, path.length - 1);
              final targetChildIndex = path.last;
              final targetAxis = axis;

              bool reorderInSameParent = false;

              /**
               1) insert
                a) _
                  -- same axis
                    => insert into parent (Split fraction of previous child between prev and new)
                  -- other axis
                    => replace child with branch and insert child and source there (both .5 fraction)
               2) remove
                a) remove from parent
                b) iff parent child.lenght == 1
                  => remove parent and insert child with parents fraction
               */

              if (pos.isCenter) throw UnimplementedError("TODO Need to implement tabbing"); // TODO __________

              // 1) insert
              //  a) _
              //    -- same axis
              bool bothHorizontal = (pos.isLeft || pos.isRight) && targetAxis == Axis.horizontal;
              bool bothVertical = (pos.isTop || pos.isBottom) && targetAxis == Axis.vertical;
              if (bothHorizontal || bothVertical) {
                //      => insert into parent (Split fraction of previous child between prev and new)
                tree = tree.updatePath(targetPathToParent, (node) {
                  final branch = node as WindowManagerBranch;
                  final children = <WindowManagerNodeAbst>[];

                  final sourceNode = tree.extractPath(sourcePath) as WindowManagerLeaf;

                  for (int i = 0; i < branch.children.length; i++) {
                    final targetChild = branch.children[i];

                    // Skip if the sourceNode is already present in the targets parent (i.e. reorder inside of parent)
                    if (targetChild is WindowManagerLeaf && targetChild.id == sourceNode.id) {
                      reorderInSameParent = true;
                      continue;
                    }

                    if (i == targetChildIndex) {
                      if (pos.isLeft || pos.isTop) {
                        children.add(sourceNode.updateFraction(targetChild.fraction * 0.5));
                      }
                      children.add(targetChild.updateFraction(targetChild.fraction * 0.5));

                      if (pos.isRight || pos.isBottom) {
                        children.add(sourceNode.updateFraction(targetChild.fraction * 0.5));
                      }
                    } else {
                      children.add(branch.children[i]);
                    }
                  }

                  return WindowManagerBranch(
                    fraction: branch.fraction,
                    children: children,
                  );
                });
              }

              //    -- other axis
              //      => replace child with branch and insert child and source there (both .5 fraction)

              if (!reorderInSameParent) {
                // 2) remove
                //  a) remove from parent
                //  b) iff parent child.lenght == 1
                //    => remove parent and insert child with parents fraction
              }

              // add to destination

              print("Hit <$id> at pos <$pos>");
              setState(() {});
            },
          ),
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
                fraction: .6,
                id: WindowManagerLeafId("Medium Top Right"),
              ),
              WindowManagerLeaf(
                fraction: .6,
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
    required this.path,
    required this.axis,
  });

  final String text;
  final VoidCallback onMoveStart;
  final Function(DragUpdateDetails d) onMoveUpdate;
  final VoidCallback onMoveEnd;
  final bool isMoving;
  final Function(WindowMoveTargetDropPosition position) onDrop;

  // Needed to put in meta data <
  final List<int> path;
  final Axis axis;
  // Needed to put in meta data >

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
