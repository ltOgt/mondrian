import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mondrian/mondrian.dart';
import 'package:mondrian/src/utils.dart';

class MondrianTreeManipulationService {
  static MondrianTree moveLeaf({
    required MondrianTree tree,
    required MondrianTreePath sourcePath,
    required MondrianTreePath targetPath,
    required MondrianLeafMoveTargetDropPosition targetSide,
    // this is needed on tab move, since the sourcePath still points to the parent (the tab leaf)
    required int? tabIndexIfAny,
  }) {
    var _tree = tree;
    var _rootAxis = tree.rootAxis;

    final bool isTabMoving = (tabIndexIfAny != null);

    assert(
      sourcePath.isEmpty == targetPath.isEmpty,
      "Paths can only be empty if moving tabs out from the root tab leaf. In that case both must be empty, in every other case neither may be empty",
    );
    assert(
      sourcePath.isNotEmpty || isTabMoving,
      "Paths can only be empty if moving tabs out from the root tab leaf.",
    );

    final _sourceNodeOrTabGroup = _tree.extractPath(sourcePath) as MondrianTreeLeaf;
    final sourceNode = !isTabMoving //
        ? _sourceNodeOrTabGroup
        : MondrianTreeLeaf(id: (_sourceNodeOrTabGroup as MondrianTreeTabLeaf).tabs[tabIndexIfAny], fraction: 0);

    // CAN HAPPEN THAT ONLY A ROOT LEAF EXISTS
    if (targetPath.isEmpty) {
      if (targetSide.isCenter) return _tree;

      final _rootNode = tree.rootNode as MondrianTreeTabLeaf;

      assert(
        _rootNode.tabs.length > 1,
        "Can not move tab below itself; ALSO: tabLeaf should not exist with only one tab",
      );
      final newActive = max(0, _rootNode.activeTabIndex - 1);

      // IF SO JUST RETURN A NEW BRANCH
      return MondrianTree(
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            if (targetSide.isLeft || targetSide.isTop) ...[
              sourceNode.updateFraction(.5),
            ],
            _rootNode.copyWith(
              fraction: .5,
              activeTabIndex: newActive,
              tabs: [
                for (final tab in _rootNode.tabs)
                  if (tab != sourceNode.id) tab
              ],
            ),
            if (targetSide.isRight || targetSide.isBottom) ...[
              sourceNode.updateFraction(.5),
            ],
          ],
        ),
        rootAxis: _rootAxis == targetSide.asAxis //
            ? _rootAxis
            : _rootAxis.next,
      );
    }

    final sourcePathToParentBranch = sourcePath.sublist(0, sourcePath.length - 1);

    final targetPathToParent = targetPath.sublist(0, targetPath.length - 1);
    final targetChildIndex = targetPath.last;
    final targetAxis = targetPath.length.isOdd ? _rootAxis : _rootAxis.next;

    bool isReorderInSameParent = false;

    // 1) insert
    // TODO: when splitting a targets fraction with the newly added source, we still need to ensure that the fractions dont get too small
    // TODO: actually, checking for minumum size in mondrian does not make much sense, need to check for minimum fraction instead
    // TODO: depending on the min fraction, this also imposes a limit on how many children a branch can have

    // ============================================================================================================ <
    // TODO: only unhandled center drop case is if the resulting tabLeaf becomes the new root
    // ============================================================================================================ >

    // 1) insert
    if (targetSide.isCenter) {
      // x) into tab group
      _tree = _tree.updatePath(targetPathToParent, (parent) {
        (parent as MondrianTreeBranch);
        final children = parent.children;

        // Must be a leaf, since can only drop onto leafs (this includes the tab leaf)
        final target = children[targetChildIndex] as MondrianTreeLeaf;
        late final MondrianTreeTabLeaf newTarget;

        // if the source is also a tab leaf, we must extract its tabs and join them
        final sourceIds = (sourceNode is MondrianTreeTabLeaf) //
            ? sourceNode.tabs
            : [sourceNode.id];
        // if the source is also a tab leaf, we want to honor the active tab
        final sourceActiveTabOffset = (sourceNode is MondrianTreeTabLeaf) //
            ? sourceNode.activeTabIndex
            : 0;

        if (target is MondrianTreeTabLeaf) {
          // If the target is already tabbed leaf => add to tabs
          final newTabs = [
            for (int i = 0; i < target.tabs.length; i++) ...[
              if (i == target.activeTabIndex) ...[
                target.activeTab,
                ...sourceIds,
              ] else ...[
                target.tabs[i],
              ],
            ],
          ];

          // TODO, currently can only drop to the right of the active index, will need to implement resorting of tabs (compare vscode)
          newTarget = target.copyWith(
            tabs: newTabs,
            activeTabIndex: target.activeTabIndex + 1 + sourceActiveTabOffset,
          );
        } else {
          // If target is not already tabbed => replace target leaf with a tab leaf
          newTarget = MondrianTreeTabLeaf(
            fraction: target.fraction,
            tabs: [
              target.id,
              ...sourceIds,
            ],
            activeTabIndex: 1 + sourceActiveTabOffset,
          );
        }

        // TODO replace all of these with copyWith
        return MondrianTreeBranch(
          fraction: parent.fraction,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i == targetChildIndex) ...[
                newTarget,
              ] else ...[
                children[i],
              ]
            ]
          ],
        );
      });
    } else {
      //  a) _
      //    -- same axis
      bool bothHorizontal = (targetSide.isLeft || targetSide.isRight) && targetAxis.isHorizontal;
      bool bothVertical = (targetSide.isTop || targetSide.isBottom) && targetAxis.isVertical;
      bool bothSameAxis = bothHorizontal || bothVertical;
      if (bothSameAxis) {
        //      => insert into parent (Split fraction of previous child between prev and new)
        _tree = _tree.updatePath(targetPathToParent, (node) {
          final branch = node as MondrianTreeBranch;
          final children = <MondrianNodeAbst>[];

          // cant just skip, since in this case we want to keep the same sizes
          int sourceInTargetsParent =
              branch.children.indexWhere((e) => (e is MondrianTreeLeaf && e.id == sourceNode.id));
          if (sourceInTargetsParent != -1) {
            isReorderInSameParent = true;
          }

          for (int i = 0; i < branch.children.length; i++) {
            final targetChild = branch.children[i];

            // Skip if the sourceNode is already present in the targets parent (i.e. reorder inside of parent)
            // NOTE: this can never happen when moving a tab, since the leafId is not directly in the branch
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
          if (sourcePathToParentBranch.length > targetPathToParent.length) {
            final potentiallySharedParentPath = sourcePathToParentBranch.sublist(0, targetPathToParent.length);
            if (listEquals(potentiallySharedParentPath, targetPathToParent)) {
              // equal parent; iff sourcePath comes after target, needs to be incremented by one because of insertion before it
              if (sourcePath[targetPath.length - 1] > targetPath.last) {
                sourcePathToParentBranch[targetPath.length - 1] += 1;
                sourcePath[targetPath.length - 1] += 1;
              }
            }
          } else if (isTabMoving && (sourcePathToParentBranch.length == targetPathToParent.length)) {
            // SPECIAL CASE: when moving out from a tab, this can happen in the same level
            // _____________ still need to increment path since can move out of tab group to infront of tab group
            // source path here is the path to the tab group
            if (sourcePath[targetPath.length - 1] > targetPath.last) {
              sourcePath[targetPath.length - 1] += 1;
            }
          }

          return MondrianTreeBranch(
            fraction: branch.fraction,
            children: children,
          );
        });
      } else {
        //    -- other axis
        //      => replace child with branch and insert child and source there (both .5 fraction)
        _tree = _tree.updatePath(targetPath, (node) {
          final leaf = node as MondrianTreeLeaf;

          bool isBefore = (targetSide.isLeft || targetSide.isTop);

          // When moving a tab out from the group into the new branch shared with the group,
          // We must adjust the paths
          if (isTabMoving && listEquals(targetPath, sourcePath)) {
            int added = isBefore ? 1 : 0;
            targetPath = [...targetPath, added];
            sourcePath = [...sourcePath, added];
          }

          return MondrianTreeBranch(
            fraction: leaf.fraction,
            children: [
              if (isBefore) ...[
                sourceNode.updateFraction(0.5),
              ],
              leaf.updateFraction(0.5),
              if (!isBefore) ...[
                sourceNode.updateFraction(0.5),
              ],
            ],
          );
        });
      }
    }

    // true if actually is leaf, false if is not a leaf
    if (isTabMoving) {
      // will need to (1) remove from tab children
      _tree = _tree.updatePath(sourcePath, (tabLeaf) {
        tabLeaf as MondrianTreeTabLeaf;

        final tabsWithoutMoved = [
          for (int i = 0; i < tabLeaf.tabs.length; i++)
            if (i != tabIndexIfAny) tabLeaf.tabs[i]
        ];

        if (tabsWithoutMoved.length == 1) {
          // return last remaining child as new leaf
          return MondrianTreeLeaf(
            id: tabsWithoutMoved.first,
            fraction: tabLeaf.fraction,
          );
        }

        return tabLeaf.copyWith(
          tabs: tabsWithoutMoved,
          activeTabIndex: max(0, tabLeaf.activeTabIndex - 1),
        );
      });
      // (2) remove tab if that was the last child
    } else if (!isReorderInSameParent) {
      // 2) remove

      if (sourcePathToParentBranch.isEmpty) {
        _tree = _tree.updatePath(sourcePathToParentBranch, (root) {
          // Parent is root node
          (root as MondrianTreeBranch);
          assert(root.children.any((e) => e is MondrianTreeLeaf && e.id == sourceNode.id));

          // ------------------------------------------------------------------------------------------------
          // REMOVE SOURCE NODE + DISTRIBUTE ITS FRACTION AMONG REMAINING
          final removedFractionToDistribute = sourceNode.fraction / (root.children.length - 1);

          // Cant use this for now, see https://github.com/flutter/flutter/issues/100135
          // List<MondrianTreeNodeAbst> rootChildrenWithoutSourceNode = [
          //   for (final child in root.children) //
          //     if (false == (child is MondrianTreeLeaf && child.id == sourceNode.id)) //
          //       child.updateFraction(
          //         cutPrecision(child.fraction + removedFractionToDistribute),
          //       ),
          // ];
          List<MondrianNodeAbst> rootChildrenWithoutSourceNode = [];
          for (final child in root.children) {
            if (child is MondrianTreeLeaf && child.id == sourceNode.id) {
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
            return MondrianTreeBranch(
              fraction: root.fraction,
              children: rootChildrenWithoutSourceNode,
            );
          }

          // ------------------------------------------------------------------------------------------------
          // IF ROOT ONLY HAS A SINGLE CHILD, REPLACE ROOT WITH THAT CHILD
          final onlyChild = rootChildrenWithoutSourceNode.first;

          // Need to flip axis here to preserve orientation, since changing top level
          _rootAxis = _rootAxis.next;

          // IF THE ONLY CHILD IS A LEAF, USE ROOT FRACTION => DONE
          if (onlyChild is MondrianTreeLeaf) {
            // (can be a tab leaf too)
            return onlyChild.updateFraction(root.fraction);
          }

          // IF THE ONLY CHILD IS A BRANCH, USE ROOT FRACTION => DONE
          if (onlyChild is MondrianTreeBranch) {
            return MondrianTreeBranch(
              fraction: root.fraction,
              children: onlyChild.children,
            );
          }
          throw "Unknown node type: ${onlyChild.runtimeType}";
        });
      } else {
        final sourcePathToParentsParent = sourcePathToParentBranch.sublist(0, sourcePathToParentBranch.length - 1);
        final sourcePathToParentIndex = sourcePathToParentBranch.last;

        _tree = _tree.updatePath(sourcePathToParentsParent, (parentsParent) {
          (parentsParent as MondrianTreeBranch);
          final parent = parentsParent.children[sourcePathToParentIndex] as MondrianTreeBranch;
          assert(parent.children.any((e) => e is MondrianTreeLeaf && e.id == sourceNode.id));

          // ------------------------------------------------------------------------------------------------
          // REMOVE SOURCE NODE + DISTRIBUTE ITS FRACTION AMONG REMAINING
          final removedFractionToDistribute = sourceNode.fraction / (parent.children.length - 1);

          // Cant use this for now, see https://github.com/flutter/flutter/issues/100135
          // List<MondrianTreeNodeAbst> parentChildrenWithoutSourceNode = [
          //   for (final child in parent.children) //
          //     if (false == (child is MondrianTreeLeaf && child.id == sourceNode.id)) //
          //       child.updateFraction(
          //         cutPrecision(child.fraction + removedFractionToDistribute),
          //       ),
          // ];
          List<MondrianNodeAbst> parentChildrenWithoutSourceNode = [];
          for (final child in parent.children) {
            if (child is MondrianTreeLeaf && child.id == sourceNode.id) {
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
            final newParent = MondrianTreeBranch(
              fraction: parent.fraction,
              children: parentChildrenWithoutSourceNode,
            );

            final newParentInsideParentsParent = parentsParent.children;
            newParentInsideParentsParent[sourcePathToParentIndex] = newParent;

            // PARENTs PARENT (no change done here)
            return MondrianTreeBranch(
              fraction: parentsParent.fraction,
              children: newParentInsideParentsParent,
            );
          }

          // ------------------------------------------------------------------------------------------------
          // IF PARENT HAS A SINGLE CHILD => REPLACE PARENT WITH THAT CHILD
          final onlyChild = parentChildrenWithoutSourceNode.first;

          // IF THE ONLY CHILD IS A LEAF, USE PARENT FRACTION => DONE
          if (onlyChild is MondrianTreeLeaf) {
            // replace parent with only child
            final parentReplacement = onlyChild.updateFraction(
              parent.fraction,
            );

            final replacedParentInsideParentsParent = parentsParent.children;
            replacedParentInsideParentsParent[sourcePathToParentIndex] = parentReplacement;

            return MondrianTreeBranch(
              fraction: parentsParent.fraction,
              children: replacedParentInsideParentsParent,
            );
          }

          // IF THE ONLY CHILD IS A BRANCH, REPLACE PARENT WITH THE CHILDREN OF THAT BRANCH
          // § Root(A,Row(B,C)) with C above B => Root(A,Row(Col(B,C))); SHOULD BE Root(A, B, C)
          // _ (Root == ParentParent, Row = Parent, Col(B,C) = Child)
          if (onlyChild is MondrianTreeBranch) {
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
            return MondrianTreeBranch(
              fraction: parentsParent.fraction,
              children: childsChildrenInsteadOfParentInsideParentsParent,
            );
          }

          throw "Unknown node type: ${onlyChild.runtimeType}";
        });
      }
    }

    return MondrianTree(
      rootNode: _tree.rootNode,
      rootAxis: _rootAxis,
    );
  }

  static double _sumDistanceToOne(List<MondrianNodeAbst> list) =>
      (1.0 - list.fold<double>(0.0, (double acc, ele) => acc + ele.fraction)).abs();

  /// Search the entire tree recursively until [id] has been found and its path constructed.
  ///
  /// Returns null if the id is not found.
  ///
  /// This can thus also be used to check for id containement.
  static MondrianTreePathWithTabIndexIfAny? treePathFromId(MondrianTreeLeafId id, MondrianTree tree) {
    return _treePathFromId(id, tree.rootNode, []);
  }

  static MondrianTreePathWithTabIndexIfAny? _treePathFromId(
    MondrianTreeLeafId id,
    MondrianNodeAbst node,
    List<int> path,
  ) {
    if (node is MondrianTreeBranch) {
      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final result = _treePathFromId(id, child, [...path, i]);
        if (result != null) return result;
      }
      return null;
}
    if (node is MondrianTreeTabLeaf) {
      for (int i = 0; i < node.tabs.length; i++) {
        final tab = node.tabs[i];
        if (tab == id) {
          return MondrianTreePathWithTabIndexIfAny(
            path: path,
            tabIndexIfAny: i,
          );
        }
      }
      return null;
    }
    if (node is MondrianTreeLeaf) {
      return (node.id != id) //
          ? null
          : MondrianTreePathWithTabIndexIfAny(
              path: path,
              tabIndexIfAny: null,
            );
    }
    throw "Unknown type: ${node.runtimeType}";
  }
}