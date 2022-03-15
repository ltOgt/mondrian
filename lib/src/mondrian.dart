import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
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
}

extension WindowAxisFlutterX on WindowAxis {
  Axis get asFlutterAxis {
    switch (this) {
      case WindowAxis.horizontal:
        return Axis.horizontal;
      case WindowAxis.vertical:
        return Axis.vertical;
    }
  }
}

class MondrianMoveable extends StatefulWidget {
  const MondrianMoveable({
    Key? key,
    required this.tree,
    required this.onMoveDone,
    required this.onResizeDone,
  }) : super(key: key);

  final WindowManagerTree tree;
  final void Function(WindowManagerTree tree) onResizeDone;
  final void Function(WindowManagerTree tree) onMoveDone;

  @override
  State<MondrianMoveable> createState() => _MondrianMoveableState();
}

class _MondrianMoveableState extends State<MondrianMoveable> {
  WindowManagerLeafId? movingId;
  List<int>? lastMovingPath;

  @override
  Widget build(BuildContext context) {
    return MondrianWM(
      tree: widget.tree,
      initialAxis: widget.tree.rootAxis.asFlutterAxis,
      onResize: (pathToParent, newFraction, index) {
        final updatedTree = widget.tree.updatePath(pathToParent, (node) {
          return (node as WindowManagerBranch).updateChildFraction(
            index: index,
            newFraction: newFraction,
          );
        });
        widget.onResizeDone(updatedTree);
      },
      resolveLeafToWidget: (leafId, leafPath, leafAxis) {
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
              onMoveEnd: () {
                movingId = null;
                setState(() {});
              },
              onMoveStart: () {
                movingId = leafId;
                lastMovingPath = leafPath;
                setState(() {});
              },
              onMoveUpdate: (d) {},
            ),
            Expanded(
              child: WindowMoveTarget(
                onDrop: (pos) => onDrop(pos, leafPath, leafAxis),
                isActive: movingId != null && movingId != leafId,
                target: Container(
                  color: Colors.red,
                ),
                child: Center(
                  child: AutoSizeText(
                      text: leafId.value), // + " ${(tree.extractPath(path) as WindowManagerLeaf).fraction}"),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void onDrop(WindowMoveTargetDropPosition pos, List<int> leafPath, Axis leafAxis) {
    var _tree = widget.tree;
    var _rootAxis = widget.tree.rootAxis;

    final sourcePath = lastMovingPath!;
    final sourcePathToParent = sourcePath.sublist(0, sourcePath.length - 1);
    final sourceNode = _tree.extractPath(sourcePath) as WindowManagerLeaf;

    final targetPath = leafPath;
    final targetPathToParent = targetPath.sublist(0, targetPath.length - 1);
    final targetChildIndex = targetPath.last;
    final targetAxis = leafAxis;

    bool isReorderInSameParent = false;

    if (pos.isCenter) throw UnimplementedError("TODO Need to implement tabbing"); // TODO __________

    // 1) insert
    //  a) _
    //    -- same axis
    bool bothHorizontal = (pos.isLeft || pos.isRight) && targetAxis == Axis.horizontal;
    bool bothVertical = (pos.isTop || pos.isBottom) && targetAxis == Axis.vertical;
    bool bothSameAxis = bothHorizontal || bothVertical;
    if (bothSameAxis) {
      //      => insert into parent (Split fraction of previous child between prev and new)
      _tree = _tree.updatePath(targetPathToParent, (node) {
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
      _tree = _tree.updatePath(targetPath, (node) {
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
        _tree = _tree.updatePath(sourcePathToParent, (root) {
          // Parent is root node
          (root as WindowManagerBranch);
          assert(root.children.any((e) => e is WindowManagerLeaf && e.id == sourceNode.id));

          // ------------------------------------------------------------------------------------------------
          // REMOVE SOURCE NODE + DISTRIBUTE ITS FRACTION AMONG REMAINING
          final removedFractionToDistribute = sourceNode.fraction / (root.children.length - 1);

          // Cant use this for now, see https://github.com/flutter/flutter/issues/100135
          // List<WindowManagerNodeAbst> rootChildrenWithoutSourceNode = [
          //   for (final child in root.children) //
          //     if (false == (child is WindowManagerLeaf && child.id == sourceNode.id)) //
          //       child.updateFraction(
          //         cutPrecision(child.fraction + removedFractionToDistribute),
          //       ),
          // ];
          List<WindowManagerNodeAbst> rootChildrenWithoutSourceNode = [];
          for (final child in root.children) {
            if (child is WindowManagerLeaf && child.id == sourceNode.id) {
              // skip the source to remove it
              continue;
            }

            rootChildrenWithoutSourceNode.add(
              child.updateFraction(
                cutPrecision(child.fraction + removedFractionToDistribute),
              ),
            );
          }
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
          _rootAxis = WindowAxis.values[(_rootAxis.index + 1) % Axis.values.length];

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

        _tree = _tree.updatePath(sourcePathToParentsParent, (parentsParent) {
          (parentsParent as WindowManagerBranch);
          final parent = parentsParent.children[sourcePathToParentIndex] as WindowManagerBranch;
          assert(parent.children.any((e) => e is WindowManagerLeaf && e.id == sourceNode.id));

          // ------------------------------------------------------------------------------------------------
          // REMOVE SOURCE NODE + DISTRIBUTE ITS FRACTION AMONG REMAINING
          final removedFractionToDistribute = sourceNode.fraction / (parent.children.length - 1);

          // Cant use this for now, see https://github.com/flutter/flutter/issues/100135
          // List<WindowManagerNodeAbst> parentChildrenWithoutSourceNode = [
          //   for (final child in parent.children) //
          //     if (false == (child is WindowManagerLeaf && child.id == sourceNode.id)) //
          //       child.updateFraction(
          //         cutPrecision(child.fraction + removedFractionToDistribute),
          //       ),
          // ];
          List<WindowManagerNodeAbst> parentChildrenWithoutSourceNode = [];
          for (final child in parent.children) {
            if (child is WindowManagerLeaf && child.id == sourceNode.id) {
              // Skip source child
              continue;
            }

            parentChildrenWithoutSourceNode.add(
              child.updateFraction(
                cutPrecision(child.fraction + removedFractionToDistribute),
              ),
            );
          }

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

    widget.onMoveDone(
      WindowManagerTree(rootNode: _tree.rootNode, rootAxis: _rootAxis),
    );
  }
}

double _sumDistanceToOne(List<WindowManagerNodeAbst> list) =>
    (1.0 - list.fold<double>(0.0, (double acc, ele) => acc + ele.fraction)).abs();
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

typedef LeafResolver = Widget Function(WindowManagerLeafId, WindowManagerTreePath path, Axis axis);

class MondrianWM extends StatelessWidget {
  const MondrianWM({
    Key? key,
    required this.tree,
    required this.onResize,
    required this.resolveLeafToWidget,
    required this.initialAxis,
  }) : super(key: key);

  final WindowManagerTree tree;

  /// Called when a the seperator between two nodes is used to resize the nodes next to it.
  /// The [pathToParent] points to the parent branch in which the children have been resized.
  /// The [index] points to the node before the seperator inside the list of children pointerd to by [pathToParent].
  /// The [newFraction] also points to the node before the seperator, the difference must be subtracted from the node after.
  final void Function(WindowManagerTreePath pathToParent, double newFraction, int index) onResize;

  /// Resolve leafs to the widgets representing them.
  final LeafResolver resolveLeafToWidget;

  final Axis initialAxis;

  @override
  Widget build(BuildContext context) {
    return _MondrianNode(
      node: tree.rootNode,
      axis: initialAxis,
      onResize: onResize,
      resolveLeafToWidget: resolveLeafToWidget,
      path: const [],
    );
  }
}

class _MondrianNode extends StatelessWidget {
  const _MondrianNode({
    Key? key,
    required this.node,
    required this.axis,
    required this.onResize,
    required this.resolveLeafToWidget,
    required this.path,
  }) : super(key: key);

  final WindowManagerNodeAbst node;
  final Axis axis;

  /// See [MondrianWM.onResize]
  final void Function(WindowManagerTreePath pathToParent, double newFraction, int index) onResize;

  /// See [MondrianWM.resolveLeafToWidget]
  final LeafResolver resolveLeafToWidget;

  final WindowManagerTreePath path;

  static const double _dragWidth = 2;

  void onDragUpdate(DragUpdateDetails d, BoxConstraints bc, int index) {
    final delta = d.delta;

    final double deltaAxis = axis.isHorizontal ? delta.dx : delta.dy;
    final double maxExtendAxis = axis.isHorizontal ? bc.maxWidth : bc.maxHeight;

    /// xtnd = max * frac
    /// xtnd' = max * frac'
    /// frac' = xtnd' / max

    final double oldExtend = maxExtendAxis * (node as WindowManagerBranch).children[index].fraction;
    final double newFraction = (oldExtend + deltaAxis) / maxExtendAxis;

    onResize(path, newFraction, index);
  }

  @override
  Widget build(BuildContext context) {
    if (node is WindowManagerLeaf) {
      return resolveLeafToWidget((node as WindowManagerLeaf).id, path, axis.previous);
    }
    final nextAxis = axis.next;

    final children = (node as WindowManagerBranch).children;
    final childrenLength = children.length;
    final lastIndex = childrenLength - 1;

    Widget __buildSeperator(int i, BoxConstraints constraints) => MouseRegion(
          cursor: axis.isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
          // TODO might want to insert an overlay here to increase hit area on hover without having to visually increase the border
          child: GestureDetector(
            onVerticalDragUpdate: axis.isVertical ? (d) => onDragUpdate(d, constraints, i) : null,
            onHorizontalDragUpdate: axis.isHorizontal ? (d) => onDragUpdate(d, constraints, i) : null,
            child: Container(
              color: Colors.blue,
              width: axis.isHorizontal ? _MondrianNode._dragWidth : null,
              height: axis.isVertical ? _MondrianNode._dragWidth : null,
            ),
          ),
        );

    return ConditionalParentWidget(
      condition: MondrianDebugSingleton.instance.mondrianShowBranchDebugPaint,
      parentBuilder: (child) {
        return Stack(
          children: [
            Positioned.fill(child: child),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withAlpha(100), width: 10.0 * path.length),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) => RowOrColumn(
          axis: axis,
          children: [
            for (int i = 0; i < childrenLength; i++) ...[
              Flexible(
                // cant use doubles, but this is the suggested workaround
                // see e.g. https://github.com/flutter/flutter/issues/22512
                flex: (children[i].fraction * 1000).round(),
                child: _MondrianNode(
                  node: children[i],
                  axis: nextAxis,
                  resolveLeafToWidget: resolveLeafToWidget,
                  onResize: onResize,
                  path: [...path, i],
                ),
              ),
              if (i != lastIndex) ...[
                __buildSeperator(i, constraints),
              ],
            ]
          ],
        ),
      ),
    );
  }
}

extension _AxisX on Axis {
  bool get isHorizontal => this == Axis.horizontal;
  bool get isVertical => this == Axis.vertical;

  Axis get previous => next;
  Axis get next {
    switch (this) {
      case Axis.horizontal:
        return Axis.vertical;
      case Axis.vertical:
        return Axis.horizontal;
    }
  }
}
