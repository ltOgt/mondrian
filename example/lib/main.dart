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
            text: id.value + " ${(tree.extractPath(path) as WindowManagerLeaf).fraction}",
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
                          isReorderInSameParent ? targetChild.fraction : cutPrecision(targetChild.fraction * 0.5);
                      final newSourceFraction =
                          isReorderInSameParent ? sourceNode.fraction : cutPrecision(targetChild.fraction * 0.5);

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
                  if (sourcePathToParent.length > targetPathToParent.length) {
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
                // 2) remove

                if (sourcePathToParent.isEmpty) {
                  tree = tree.updatePath(sourcePathToParent, (root) {
                    // Parent is root node
                    (root as WindowManagerBranch);
                    assert(root.children.any((e) => e is WindowManagerLeaf && e.id == sourceNode.id));

                    // ------------------------------------------------------------------------------------------------
                    // REMOVE SOURCE NODE + DISTRIBUTE ITS FRACTION AMONG REMAINING
                    final removedFractionToDistribute = sourceNode.fraction / (root.children.length - 1);
                    List<WindowManagerNodeAbst> rootChildrenWithoutSourceNode = [
                      for (final child in root.children) //
                        if (false == (child is WindowManagerLeaf && child.id == sourceNode.id)) //
                          child.updateFraction(
                            cutPrecision(child.fraction + removedFractionToDistribute),
                          ),
                    ];
                    assert(
                      () {
                        final distance = _sumDistanceToOne(rootChildrenWithoutSourceNode);
                        print("Resulting error on rebalance: $distance");
                        return distance < 0.01;
                      }(),
                    ); // TODO maybe rebalance here instead?

                    // ------------------------------------------------------------------------------------------------
                    // IF ROOT STILL HAS MULTIPLE CHILDREN => USE THOSE
                    if (rootChildrenWithoutSourceNode.length > 1) {
                      return WindowManagerBranch(
                        fraction: root.fraction,
                        children: rootChildrenWithoutSourceNode,
                      );
                    }

                    // ------------------------------------------------------------------------------------------------
                    // IF ROOT ONLY HAS A SINGLE CHILD, REPLACE ROOT WITH THAT CHILD
                    final onlyChild = rootChildrenWithoutSourceNode.first;

                    // Need to flip axis here to preserve orientation, since changing top level
                    initialAxis = Axis.values[(initialAxis.index + 1) % Axis.values.length];

                    // IF THE ONLY CHILD IS A LEAF, USE ROOT FRACTION => DONE
                    if (onlyChild is WindowManagerLeaf) {
                      return WindowManagerLeaf(
                        fraction: root.fraction,
                        id: onlyChild.id,
                      );
                    }

                    // IF THE ONLY CHILD IS A BRANCH, USE ROOT FRACTION => DONE
                    if (onlyChild is WindowManagerBranch) {
                      return WindowManagerBranch(
                        fraction: root.fraction,
                        children: onlyChild.children,
                      );
                    }
                    throw "Unknown node type: ${onlyChild.runtimeType}";
                  });
                } else {
                  final sourcePathToParentsParent = sourcePathToParent.sublist(0, sourcePathToParent.length - 1);
                  final sourcePathToParentIndex = sourcePathToParent.last;

                  tree = tree.updatePath(sourcePathToParentsParent, (parentsParent) {
                    (parentsParent as WindowManagerBranch);
                    final parent = parentsParent.children[sourcePathToParentIndex] as WindowManagerBranch;
                    assert(parent.children.any((e) => e is WindowManagerLeaf && e.id == sourceNode.id));

                    // ------------------------------------------------------------------------------------------------
                    // REMOVE SOURCE NODE + DISTRIBUTE ITS FRACTION AMONG REMAINING
                    final removedFractionToDistribute = sourceNode.fraction / (parent.children.length - 1);
                    List<WindowManagerNodeAbst> parentChildrenWithoutSourceNode = [
                      for (final child in parent.children) //
                        if (false == (child is WindowManagerLeaf && child.id == sourceNode.id)) //
                          child.updateFraction(
                            cutPrecision(child.fraction + removedFractionToDistribute),
                          ),
                    ];
                    assert(
                      () {
                        final distance = _sumDistanceToOne(parentChildrenWithoutSourceNode);
                        print("Resulting error on rebalance: $distance");
                        return distance < 0.01;
                      }(),
                    ); // TODO maybe rebalance here instead?

                    // ------------------------------------------------------------------------------------------------
                    // IF PARENT STILL HAS MULTIPLE CHILDREN => USE THOSE
                    if (parentChildrenWithoutSourceNode.length > 1) {
                      // PARENT WITH NEW CHILDREN
                      final newParent = WindowManagerBranch(
                        fraction: parent.fraction,
                        children: parentChildrenWithoutSourceNode,
                      );

                      final newParentInsideParentsParent = parentsParent.children;
                      newParentInsideParentsParent[sourcePathToParentIndex] = newParent;

                      // PARENTs PARENT (no change done here)
                      return WindowManagerBranch(
                        fraction: parentsParent.fraction,
                        children: newParentInsideParentsParent,
                      );
                    }

                    // ------------------------------------------------------------------------------------------------
                    // IF PARENT HAS A SINGLE CHILD => REPLACE PARENT WITH THAT CHILD
                    final onlyChild = parentChildrenWithoutSourceNode.first;

                    // IF THE ONLY CHILD IS A LEAF, USE PARENT FRACTION => DONE
                    if (onlyChild is WindowManagerLeaf) {
                      // replace parent with only child
                      final parentReplacement = WindowManagerLeaf(
                        id: onlyChild.id,
                        fraction: parent.fraction,
                      );
                      final replacedParentInsideParentsParent = parentsParent.children;
                      replacedParentInsideParentsParent[sourcePathToParentIndex] = parentReplacement;

                      return WindowManagerBranch(
                        fraction: parentsParent.fraction,
                        children: replacedParentInsideParentsParent,
                      );
                    }

                    // IF THE ONLY CHILD IS A BRANCH, REPLACE PARENT WITH THE CHILDREN OF THAT BRANCH
                    // § Root(A,Row(B,C)) with C above B => Root(A,Row(Col(B,C))); SHOULD BE Root(A, B, C)
                    // _ (Root == ParentParent, Row = Parent, Col(B,C) = Child)
                    if (onlyChild is WindowManagerBranch) {
                      // parent fraction will be split among childrens children based on their fraction inside of parents child
                      final parentFractionToDistribute = parent.fraction;

                      final childsChildrenInsteadOfParentInsideParentsParent = [
                        for (int i = 0; i < parentsParent.children.length; i++)
                          if (i != sourcePathToParentIndex) ...[
                            // Use the regular children of parentsParent
                            parentsParent.children[i],
                          ] else ...[
                            // But replace the parent with the childs children
                            for (int j = 0; j < onlyChild.children.length; j++) ...[
                              onlyChild.children[j].updateFraction(
                                cutPrecision(onlyChild.children[j].fraction * parentFractionToDistribute),
                              ),
                            ]
                          ]
                      ];
                      assert(() {
                        final distance = _sumDistanceToOne(childsChildrenInsteadOfParentInsideParentsParent);
                        print("Resulting error on rebalance: $distance");
                        return distance < 0.01;
                      }());

                      // PARENTs PARENT (removed direct parent, as well as direct child)
                      return WindowManagerBranch(
                        fraction: parentsParent.fraction,
                        children: childsChildrenInsteadOfParentInsideParentsParent,
                      );
                    }

                    throw "Unknown node type: ${onlyChild.runtimeType}";
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

double _sumDistanceToOne(List<WindowManagerNodeAbst> list) =>
    (1.0 - list.fold<double>(0.0, (double acc, ele) => acc + ele.fraction)).abs();

final k_tree = WindowManagerTree(
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
