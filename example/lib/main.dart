import 'package:flutter/foundation.dart';
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

  Axis initialAxis = Axis.vertical;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mondrian Example',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MondrianWM(
          tree: tree,
          initialAxis: initialAxis,
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
              final sourcePathToParent = sourcePath.sublist(0, sourcePath.length - 1);
              final sourceNode = tree.extractPath(sourcePath) as WindowManagerLeaf;

              final targetPath = path;
              final targetPathToParent = targetPath.sublist(0, targetPath.length - 1);
              final targetChildIndex = targetPath.last;
              final targetAxis = axis;

              bool isReorderInSameParent = false;

              // TODO !!!!! special case if root is branch with only two leaf children and they want to change axis
              // => just change initial axis

              /**
               1) insert
                a) _
                  -- same axis
                    => insert into parent (Split fraction of previous child between prev and new)
                  -- other axis
                    => replace child with branch and insert child and source there (both .5 fraction)
               2) remove
                a) remove from parent
                b) iff parent-P child.lenght == 1
                  -- child-C is leaf
                    => remove parent-P and insert child-C with parents fraction
                  -- child-C is branch
                    => remove parent-P and extract children of child-C into parent-Ps parent, splitting parent-Ps fraction among child-Cs children
                      0) _
                         Col(
                           Row(
                             Col(C1,C2),
                             C3
                           ),
                           C4
                         )
                      1) REMOVE C3
                      2) WRONG:
                         Col(
                           Row(C1,C2), // Col would be turned into row since col=>row=>col=>...
                           C4
                         )
                      2) RIGHT:
                         Col(
                           C1,
                           C2, // C1 and C2 remaing visually under each other
                           C4
                         )
               */

              if (pos.isCenter) throw UnimplementedError("TODO Need to implement tabbing"); // TODO __________

              // 1) insert
              //  a) _
              //    -- same axis
              bool bothHorizontal = (pos.isLeft || pos.isRight) && targetAxis == Axis.horizontal;
              bool bothVertical = (pos.isTop || pos.isBottom) && targetAxis == Axis.vertical;
              bool bothSameAxis = bothHorizontal || bothVertical;
              if (bothSameAxis) {
                //      => insert into parent (Split fraction of previous child between prev and new)
                tree = tree.updatePath(targetPathToParent, (node) {
                  final branch = node as WindowManagerBranch;
                  final children = <WindowManagerNodeAbst>[];

                  // cant just skip, since in this case we want to keep the same sizes
                  int sourceInTargetsParent =
                      branch.children.indexWhere((e) => (e is WindowManagerLeaf && e.id == sourceNode.id));
                  if (sourceInTargetsParent != -1) {
                    isReorderInSameParent = true;
                  }

                  for (int i = 0; i < branch.children.length; i++) {
                    final targetChild = branch.children[i];

                    // Skip if the sourceNode is already present in the targets parent (i.e. reorder inside of parent)
                    if (i == sourceInTargetsParent) {
                      continue;
                    }

                    if (i == targetChildIndex) {
                      // on reorder in same parent we want to keep the same sizes, otherwise we split the size of the target between the two
                      final newTargetFraction =
                          isReorderInSameParent ? targetChild.fraction : targetChild.fraction * 0.5;
                      final newSourceFraction =
                          isReorderInSameParent ? sourceNode.fraction : targetChild.fraction * 0.5;

                      if (pos.isLeft || pos.isTop) {
                        children.add(sourceNode.updateFraction(newSourceFraction));
                      }
                      children.add(targetChild.updateFraction(newTargetFraction));

                      if (pos.isRight || pos.isBottom) {
                        children.add(sourceNode.updateFraction(newSourceFraction));
                      }
                    } else {
                      children.add(branch.children[i]);
                    }
                  }

                  // TODO might need to adjust the source parent path at this point
                  // § source [0,1,0] with target [0,0] on same axis
                  // _ => will result in target parent (0,1) => (0,1,2)
                  // _ _ -- insert before
                  // _ _ _ => target is now at [0,1]
                  // _ _ _ => source is now at [0,0]
                  // _ _ _ => source old parent is now at [0,2] instead of [0,1]
                  // _ _ -- insert after
                  // _ _ _ => target is now at [0,0]
                  // _ _ _ => source is now at [0,1]
                  // _ _ _ => source old parent is now at [0,2] instead of [0,1]
                  // ==> Need to adjust source parent iff the children of a source-parents ancestor have been adjusted
                  if (sourcePathToParent.length >= targetPathToParent.length) {
                    final potentiallySharedParentPath = sourcePathToParent.sublist(0, targetPathToParent.length);
                    if (listEquals(potentiallySharedParentPath, targetPathToParent)) {
                      // equal parent; iff sourcePath comes after target, needs to be incremented by one because of insertion before it
                      if (sourcePath[targetPath.length - 1] > targetPath.last) {
                        sourcePathToParent[targetPath.length - 1] += 1;
                      }
                    }
                  }

                  return WindowManagerBranch(
                    fraction: branch.fraction,
                    children: children,
                  );
                });
              } else {
                //    -- other axis
                //      => replace child with branch and insert child and source there (both .5 fraction)
                tree = tree.updatePath(targetPath, (node) {
                  final leaf = node as WindowManagerLeaf;

                  return WindowManagerBranch(
                    fraction: leaf.fraction,
                    children: [
                      if (pos.isLeft || pos.isTop) ...[
                        sourceNode.updateFraction(0.5),
                      ],
                      leaf.updateFraction(0.5),
                      if (pos.isRight || pos.isBottom) ...[
                        sourceNode.updateFraction(0.5),
                      ],
                    ],
                  );
                });
              }

              if (!isReorderInSameParent) {
                late final List<WindowManagerNodeAbst> adjustedChildren;
                // 2) remove

                if (sourcePathToParent.isEmpty) {
                  tree = tree.updatePath(sourcePathToParent, (parent) {
                    final branch = (parent as WindowManagerBranch);

                    adjustedChildren = [
                      for (final child in branch.children) //
                        if (false == (child is WindowManagerLeaf && child.id == sourceNode.id)) //
                          child,
                    ];

                    if (adjustedChildren.length == 1) {
                      // Need to flip axis here to preserve orientation, since changing top level
                      initialAxis = Axis.values[(initialAxis.index + 1) % (Axis.values.length - 1)];

                      final onlyChild = adjustedChildren.first;
                      if (onlyChild is WindowManagerLeaf) {
                        return WindowManagerLeaf(id: onlyChild.id, fraction: parent.fraction);
                      }
                      if (onlyChild is WindowManagerBranch) {
                        return WindowManagerBranch(
                          fraction: branch.fraction,
                          children: onlyChild.children,
                        );
                      }
                      throw "Unknown node type: ${onlyChild.runtimeType}";
                    } else {
                      return WindowManagerBranch(
                        fraction: branch.fraction,
                        children: adjustedChildren,
                      );
                    }
                  });
                } else {
                  final sourcePathToParentsParent = sourcePathToParent.sublist(0, sourcePathToParent.length - 1);
                  final sourcePathToParentIndex = sourcePathToParent.last;

                  tree = tree.updatePath(sourcePathToParentsParent, (parentsParent) {
                    final parent = (parentsParent as WindowManagerBranch).children[sourcePathToParentIndex];
                    final branch = (parent as WindowManagerBranch);

                    adjustedChildren = [
                      for (final child in branch.children) //
                        if (false == (child is WindowManagerLeaf && child.id == sourceNode.id)) //
                          child,
                    ];

                    if (adjustedChildren.length == 1) {
                      final onlyChild = adjustedChildren.first;
                      if (onlyChild is WindowManagerLeaf) {
                        // replace parent with only child
                        final replacedParentInsideParentsParent = parentsParent.children;
                        replacedParentInsideParentsParent[sourcePathToParentIndex] =
                            WindowManagerLeaf(id: onlyChild.id, fraction: parent.fraction);

                        return WindowManagerBranch(
                          fraction: parentsParent.fraction,
                          children: replacedParentInsideParentsParent,
                        );
                      }
                      if (onlyChild is WindowManagerBranch) {
                        // § Row(Col(A, B), ...) with A move right to B => Row(Col(_,Row(A,B)), ...) SHOULD ACTUALLY BE => Row(A, B, ...)
                        if (false == onlyChild.children.any((e) => e is WindowManagerBranch)) {
                          // TODO previously also had this check in here: /*|| parentsParent.children.length < 3*/ not sure if that was just a hack during fixing

                          final replacedParentInsideParentsParent = [
                            for (int i = 0; i < parentsParent.children.length; i++)
                              if (i == sourcePathToParentIndex) ...[
                                for (int j = 0; j < onlyChild.children.length; j++) ...[
                                  onlyChild.children[j]
                                      .updateFraction(parent.fraction * (1 / onlyChild.children.length)),
                                ]
                              ] else ...[
                                parentsParent.children[i],
                              ]
                          ];
                          // PARENTs PARENT (removed direct parent, as well as direct child)
                          return WindowManagerBranch(
                            fraction: parentsParent.fraction,
                            children: replacedParentInsideParentsParent,
                          );
                        } else {
                          // final replacedParentInsideParentsParent = [for (int i = 0; i < parentsParent.children.length; i++)
                          //   if (i == sourcePathToParentIndex)
                          // ];
                          final replacedParentInsideParentsParent = parentsParent.children;

                          replacedParentInsideParentsParent[sourcePathToParentIndex] = WindowManagerBranch(
                            fraction: branch.fraction,
                            children: onlyChild.children,
                          );

                          // PARENTs PARENT (removed direct parent, since only one child left)
                          return WindowManagerBranch(
                            fraction: parentsParent.fraction,
                            children: replacedParentInsideParentsParent,
                          );
                        }
                      }
                      throw "Unknown node type: ${onlyChild.runtimeType}";
                    } else {
                      // PARENT
                      final replacedParentInsideParentsParent = parentsParent.children;
                      replacedParentInsideParentsParent[sourcePathToParentIndex] = WindowManagerBranch(
                        fraction: branch.fraction,
                        children: adjustedChildren,
                      );

                      // PARENTs PARENT (no change done here, needed for case above)
                      return WindowManagerBranch(
                        fraction: parentsParent.fraction,
                        children: replacedParentInsideParentsParent,
                      );
                    }
                  });
                }
              }
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
