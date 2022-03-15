import 'package:flutter/foundation.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';

enum WindowAxis {
  horizontal,
  vertical,
}

extension WindowAxisX on WindowAxis {
  WindowAxis get previous => WindowAxis.values[(index - 1) % WindowAxis.values.length];
  WindowAxis get next => WindowAxis.values[(index + 1) % WindowAxis.values.length];

  bool get isHorizontal => WindowAxis.horizontal == this;
  bool get isVertical => WindowAxis.vertical == this;
}

/// The index for each child that must be passed to reach the destination node.
typedef WindowManagerTreePath = List<int>;

/// The tree of [WindowManagerNodeAbst]s specifying the partition of the window.
class WindowManagerTree {
  final WindowManagerNodeAbst rootNode;
  final WindowAxis rootAxis;

  const WindowManagerTree({
    required this.rootNode,
    required this.rootAxis,
  });

  WindowManagerTree updatePath(WindowManagerTreePath path, NodeUpdater updateNode) {
    if (rootNode is WindowManagerLeaf) {
      final n = (rootNode as WindowManagerLeaf);
      return WindowManagerTree(
        rootNode: n.updatePath(path, updateNode),
        rootAxis: rootAxis,
      );
    } else if (rootNode is WindowManagerBranch) {
      final n = (rootNode as WindowManagerBranch);
      return WindowManagerTree(
        rootNode: n.updatePath(path, updateNode),
        rootAxis: rootAxis,
      );
    }
    throw "Unknown type ${rootNode.runtimeType}";
  }

  WindowManagerNodeAbst extractPath(WindowManagerTreePath path) {
    if (rootNode is WindowManagerLeaf) {
      assert(path.isEmpty);
      return rootNode;
    } else if (rootNode is WindowManagerBranch) {
      return (rootNode as WindowManagerBranch).extractPath(path);
    }
    throw "Unknown type ${rootNode.runtimeType}";
  }

  // TODO consider adding a method "leafPathFromId(WindowLeafId)" that searches the tree recursively, while building a path and returning it on match

  WindowManagerTree moveLeaf({
    required WindowManagerTreePath sourcePath,
    required WindowManagerTreePath targetPath,
    required WindowMoveTargetDropPosition targetSide,
  }) {
    var _tree = this;
    var _rootAxis = rootAxis;

    final sourcePathToParent = sourcePath.sublist(0, sourcePath.length - 1);
    final sourceNode = _tree.extractPath(sourcePath) as WindowManagerLeaf;

    final targetPathToParent = targetPath.sublist(0, targetPath.length - 1);
    final targetChildIndex = targetPath.last;
    final targetAxis = targetPath.length.isOdd ? _rootAxis : _rootAxis.next;

    bool isReorderInSameParent = false;

    // 1) insert
    // TODO: when splitting a targets fraction with the newly added source, we still need to ensure that the fractions dont get too small
    // TODO: actually, checking for minumum size in mondrian does not make much sense, need to check for minimum fraction instead
    // TODO: depending on the min fraction, this also imposes a limit on how many children a branch can have

    // 1) insert
    if (targetSide.isCenter) {
      throw UnimplementedError();
      /*
      // x) into tab group
      _tree = _tree.updatePath(targetPathToParent, (parent) {
        (parent as WindowManagerBranch);
        final children = parent.children;

        // Must be a leaf, since can only drop onto leafs
        final target = children[targetChildIndex] as WindowManagerLeaf;

        if (parent.isTabbed) {
          // If the parent is already in tabbed mode => add to parents tab group

          // NOTE: it is guaranteed that the source can not already be in the same parent:
          // moving the source will mean that the tab group does not get the drop overlay (only the tab reorder overlay)
          // // TODO make sure of this, ALSO need to change focus to the moving tab if it is moved without already having focus

          // TODO Splitting the targets fraction with the source might not be a good idea:
          // _ the diminishing fraction is not visible while in tab mode, if multiple sources are dropped onto the same target over and over again, it will shrink and shirnk
          final childrenWithNew = [
            for (final child in children)
              if (child == target) ...[
                target.updateFraction(target.fraction * 0.5),
                sourceNode.updateFraction(target.fraction * 0.5),
              ] else ...[
                child,
              ]
          ];

          return WindowManagerBranch(
            fraction: parent.fraction,
            children: childrenWithNew,
            // make newly dropped child focused
            tabFocusIndex: targetChildIndex + 1,
          );
        } else {
          // If Parent is not already tabbed => replace target leaf with a new branch in tabbed mode.

          // check if the source is already in the same parent, if so we can just quickly remove it here to skip the removal phase later
          int sourceInTargetsParent =
              parent.children.indexWhere((e) => (e is WindowManagerLeaf && e.tabs == sourceNode.tabs));
          if (sourceInTargetsParent != -1) {
            // Means we dont have to do the removal step later
            isReorderInSameParent = true;
          }
          final sourceFractionIfRemoved = (isReorderInSameParent ? sourceNode.fraction : 0);

          final childrenPotentiallyWithRemovedSource = <WindowManagerNodeAbst>[
            for (int i = 0; i < children.length; i++)
              if (i != sourceInTargetsParent) // skip source if present
                if (i == targetChildIndex) ...[
                  WindowManagerBranch(
                    fraction: target.fraction + sourceFractionIfRemoved,
                    children: [
                      // TODO rename "update" to "copyWith"
                      target.updateFraction(.5),
                      sourceNode.updateFraction(.5),
                    ],
                    // make newly dropped child focused
                    tabFocusIndex: 1,
                  )
                ] else ...[
                  children[i],
                ]
          ];

          // insert children back into parent
          return WindowManagerBranch(
            fraction: parent.fraction,
            children: childrenPotentiallyWithRemovedSource,
            tabFocusIndex: null,
          );
        }
      });
      */
    } else {
      //  a) _
      //    -- same axis
      bool bothHorizontal = (targetSide.isLeft || targetSide.isRight) && targetAxis.isHorizontal;
      bool bothVertical = (targetSide.isTop || targetSide.isBottom) && targetAxis.isVertical;
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

              if (targetSide.isLeft || targetSide.isTop) {
                children.add(sourceNode.updateFraction(newSourceFraction));
              }
              children.add(targetChild.updateFraction(newTargetFraction));

              if (targetSide.isRight || targetSide.isBottom) {
                children.add(sourceNode.updateFraction(newSourceFraction));
              }
            } else {
              children.add(branch.children[i]);
            }
          }

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
              if (targetSide.isLeft || targetSide.isTop) ...[
                sourceNode.updateFraction(0.5),
              ],
              leaf.updateFraction(0.5),
              if (targetSide.isRight || targetSide.isBottom) ...[
                sourceNode.updateFraction(0.5),
              ],
            ],
          );
        });
      }
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
          _rootAxis = rootAxis.next;

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

    return WindowManagerTree(
      rootNode: _tree.rootNode,
      rootAxis: _rootAxis,
    );
  }

  double _sumDistanceToOne(List<WindowManagerNodeAbst> list) =>
      (1.0 - list.fold<double>(0.0, (double acc, ele) => acc + ele.fraction)).abs();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WindowManagerTree && other.rootNode == rootNode;
  }

  @override
  int get hashCode => rootNode.hashCode;

  @override
  String toString() => 'WindowManagerTree(rootNode: $rootNode)';
}

typedef NodeUpdater = WindowManagerNodeAbst Function(WindowManagerNodeAbst node);

/// A part of the [WindowManagerTree], either a [WindowManagerBranch] or a [WindowManagerLeaf].
abstract class WindowManagerNodeAbst {
  /// The fraction of the parent slice taken up by this slice
  double get fraction;

  const WindowManagerNodeAbst();

  WindowManagerNodeAbst updatePath(WindowManagerTreePath path, NodeUpdater updateNode);

  WindowManagerNodeAbst updateFraction(double newFraction);
}

/// Id to identify a [WindowManagerLeaf]
class WindowManagerLeafId {
  final String value;
  const WindowManagerLeafId(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WindowManagerLeafId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'WindowManagerLeafId(value: $value)';
}

/// Lead in the tree, represents a single widget.
///
/// Can be placed inside [WindowManagerBranch].
class WindowManagerLeaf extends WindowManagerNodeAbst {
  @override
  final double fraction;

  /// The id representing this leaf.
  /// Used by [MondrianWM.resolveLeafToWidget] to resolve the widget representing this leaf.
  final WindowManagerLeafId id;

  const WindowManagerLeaf({
    required this.id,
    required this.fraction,
  });

  @override
  WindowManagerNodeAbst updatePath(WindowManagerTreePath path, NodeUpdater updateNode) {
    assert(path.isEmpty, "Arrived at leaf, but path is not yet empty: $path");
    return updateNode(this);
  }

  @override
  WindowManagerNodeAbst updateFraction(double newFraction) => WindowManagerLeaf(id: id, fraction: newFraction);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WindowManagerLeaf && other.fraction == fraction && other.id == id;
  }

  @override
  int get hashCode => fraction.hashCode ^ id.hashCode;

  @override
  String toString() => 'WindowManagerLeaf(fraction: $fraction, id: $id)';
}

/// Row or Column inside the [WindowManagerTree].
/// Can contain [WindowManagerLeaf]s as well as further [WindowManagerTree]s.
///
/// The axis direction of this branch depends on the [WindowManagerTree.initialAxis] and the depth of this branch.
/// § Axis.horizontal => Row => Column => Row => ...
class WindowManagerBranch extends WindowManagerNodeAbst {
  @override
  final double fraction;

  /// The children contained within this branch.
  final List<WindowManagerNodeAbst> children;

  const WindowManagerBranch({
    required this.fraction,
    required this.children,
  });

  @override
  WindowManagerNodeAbst updatePath(WindowManagerTreePath path, NodeUpdater updateNode) {
    if (path.isEmpty) {
      return updateNode(this);
    }
    return WindowManagerBranch(
      fraction: fraction,
      children: [
        for (int i = 0; i < children.length; i++)
          if (i == path.first) ...[
            children[i].updatePath(path.skip(1).toList(), updateNode),
          ] else ...[
            children[i],
          ]
      ],
    );
  }

  WindowManagerNodeAbst extractPath(WindowManagerTreePath path) {
    final child = children[path.first];
    final remainder = path.skip(1).toList();

    if (child is WindowManagerLeaf) {
      assert(remainder.isEmpty);
      return child;
    } else if (child is WindowManagerBranch) {
      return child.extractPath(remainder);
    }
    throw "Unknown type ${child.runtimeType}";
  }

  @override
  WindowManagerNodeAbst updateFraction(double newFraction) =>
      WindowManagerBranch(children: children, fraction: newFraction);

  WindowManagerBranch updateChildFraction({required int index, required double newFraction}) {
    final child1 = children[index];
    final child2 = children[index + 1];

    final diff = child1.fraction - newFraction;
    final new2 = child2.fraction + diff;
    // round both to avoid precision issues
    final newRounded = cutPrecision(newFraction);
    final new2Rounded = cutPrecision(new2);

    final child1Updated = child1.updateFraction(newRounded);
    final child2Updated = child2.updateFraction(new2Rounded);

    return WindowManagerBranch(
      fraction: fraction,
      children: [
        for (int i = 0; i < children.length; i++)
          if (i == index) ...[
            child1Updated,
          ] else if (i == index + 1) ...[
            child2Updated,
          ] else ...[
            children[i],
          ]
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WindowManagerBranch && other.fraction == fraction && listEquals(other.children, children);
  }

  @override
  int get hashCode => fraction.hashCode ^ children.hashCode;

  @override
  String toString() => 'WindowManagerBranch(fraction: $fraction, children: $children)';
}
