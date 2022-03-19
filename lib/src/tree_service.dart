import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mondrian/mondrian.dart';
import 'package:mondrian/src/utils.dart';

class MondrianTreeManipulationService {
  /// Insert a [sourceLeaf] into the opposing axis as [targetLeaf],
  /// either before ([isBefore]) or after.
  ///
  /// This will create a new [MondrianTreeBranch] containing both leafs,
  /// each taking up half the space that [targetLeaf] took up before.
  static MondrianTreeBranch _addLeafToLeafAsNewBranch({
    required MondrianTreeLeaf targetLeaf,
    required MondrianTreeLeaf sourceLeaf,
    required bool isBefore,
  }) {
    final fractionOfNewBranch = targetLeaf.fraction;
    const fractionOfEachChild = 0.5;

    return MondrianTreeBranch(
      fraction: fractionOfNewBranch,
      children: [
        if (isBefore) ...[sourceLeaf.updateFraction(fractionOfEachChild)],
        targetLeaf.updateFraction(fractionOfEachChild),
        if (!isBefore) ...[sourceLeaf.updateFraction(fractionOfEachChild)],
      ],
    );
  }

  /// Insert a [sourceLeaf] into the same axis as a target [MondrianTreeLeaf].
  /// That leaf is identified by its [targetIndexInParent] inside its [targetParentBranch].
  ///
  /// This insertion can happen either before ([isBefore]) or after.
  ///
  /// This will return [targetParentBranch] with adjusted children as a new [MondrianTreeBranch] containing both leafs,
  /// each taking up half the space that the target leaf took up before.
  static MondrianTreeBranch _addLeafToBranch({
    required MondrianTreeBranch targetParentBranch,
    required int targetIndexInParent,
    required MondrianTreeLeaf sourceLeaf,
    required bool isBefore,
  }) {
    final parentsChildren = targetParentBranch.children;
    final targetNode = parentsChildren[targetIndexInParent];
    final newFractionOfTargetAndSourceInParent = cutPrecision(targetNode.fraction * 0.5);

    return targetParentBranch.copyWith(
      children: [
        for (int i = 0; i < parentsChildren.length; i++)
          if (i == targetIndexInParent) ...[
            if (isBefore) ...[sourceLeaf.updateFraction(newFractionOfTargetAndSourceInParent)],
            targetNode.updateFraction(newFractionOfTargetAndSourceInParent),
            if (!isBefore) ...[sourceLeaf.updateFraction(newFractionOfTargetAndSourceInParent)],
          ] else ...[
            parentsChildren[i],
          ]
      ],
    );
  }

  /// Insert a [sourceLeaf] into the target [MondrianTreeLeaf] as a new tab.
  ///
  /// This insertion will happen after the currently active [MondrianTreeTabLeaf.activeTabIndex].
  /// Iff the [targetLeaf] is not yet a [MondrianTreeTabLeaf],
  /// a new tab leaf will be created with [targetLeaf] comming first, and [sourceLeaf] second.
  ///
  /// The returned [MondrianTreeTabLeaf] will have its [MondrianTreeTabLeaf.activeTabIndex] point to [sourceLeaf].
  static MondrianTreeTabLeaf _addLeafToLeafAsTab({
    required MondrianTreeLeaf targetLeaf,
    required MondrianTreeLeaf sourceLeaf,
  }) {
    // if the source is also a tab leaf, we must extract its tabs and join them
    final sourceIds = (sourceLeaf is MondrianTreeTabLeaf) //
        ? sourceLeaf.tabs
        : [sourceLeaf.id];
    // if the source is also a tab leaf, we want to honor the active tab
    final sourceActiveTabOffset = (sourceLeaf is MondrianTreeTabLeaf) //
        ? sourceLeaf.activeTabIndex
        : 0;

    if (targetLeaf is! MondrianTreeTabLeaf) {
      return MondrianTreeTabLeaf(
        fraction: targetLeaf.fraction,
        activeTabIndex: 1 + sourceActiveTabOffset,
        tabs: [targetLeaf.id, ...sourceIds],
      );
    }

    return targetLeaf.copyWith(
      tabs: [
        ...targetLeaf.tabs.sublist(0, targetLeaf.activeTabIndex + 1),
        ...sourceIds,
        ...targetLeaf.tabs.sublist(targetLeaf.activeTabIndex + 1, targetLeaf.tabs.length),
      ],
      activeTabIndex: targetLeaf.activeTabIndex + 1 + sourceActiveTabOffset,
    );
  }

  /// If the root of the [MondrianTree] is a [MondrianTreeLeaf], we can add a new [sourceLeaf] to the [targetRoot].
  ///
  /// This can either be as a [MondrianTreeBranch] or into a shared [MondrianTreeTabLeaf].
  /// Depending on the [targetRootAxis] and the [targetSide], the [MondrianTree.rootAxis] might be inverted.
  static MondrianTree _addLeafToRoot({
    required MondrianTreeLeaf sourceLeaf,
    required MondrianTreeLeaf targetRoot,
    required MondrianAxis targetRootAxis,
    required MondrianLeafMoveTargetDropPosition targetSide,
  }) {
    if (targetSide.isCenter) {
      return MondrianTree(
        rootNode: _addLeafToLeafAsTab(
          targetLeaf: targetRoot,
          sourceLeaf: sourceLeaf,
        ),
        rootAxis: targetRootAxis,
      );
    } else {
      return MondrianTree(
        rootNode: _addLeafToLeafAsNewBranch(
          targetLeaf: targetRoot,
          sourceLeaf: sourceLeaf,
          isBefore: targetSide.isPositionBefore!,
        ),
        rootAxis: targetRootAxis == targetSide.asAxis //
            ? targetRootAxis
            : targetRootAxis.next,
      );
    }
  }

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

    // CREATE <

    final _sourceNodeOrTabGroup = _tree.extractPath(sourcePath) as MondrianTreeLeaf;
    final sourceNode = !isTabMoving //
        ? _sourceNodeOrTabGroup
        : MondrianTreeLeaf(id: (_sourceNodeOrTabGroup as MondrianTreeTabLeaf).tabs[tabIndexIfAny], fraction: 0);

    // DURING MOVE, IF THE ROOT NODE IS A TAB LEAF, THE TARGET PATH CAN BE EMPTY
    if (targetPath.isEmpty) {
      if (targetSide.isCenter) return _tree;

      final _rootNode = tree.rootNode as MondrianTreeTabLeaf;

      assert(
        _rootNode.tabs.length > 1,
        "Can not move tab below itself; ALSO: tabLeaf should not exist with only one tab",
      );
      final newActive = max(0, _rootNode.activeTabIndex - 1);

      // IF SO JUST RETURN A NEW BRANCH WITH THE TAB REMOVED
      final tabsWithoutMoved = [
        for (final tab in _rootNode.tabs)
          if (tab != sourceNode.id) tab
      ];
      final updatedRootLeaf = (tabsWithoutMoved.length > 1) //
          ? _rootNode.copyWith(
              fraction: .5,
              activeTabIndex: newActive,
              tabs: tabsWithoutMoved,
            )
          // Replace with leaf if no more than one tab would remain
          : MondrianTreeLeaf(
              id: _rootNode.tabs[0],
              fraction: .5,
            );

      return MondrianTree(
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            if (targetSide.isLeft || targetSide.isTop) ...[
              sourceNode.updateFraction(.5),
            ],
            updatedRootLeaf,
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

    bool skipRemovalForSourceInSameParentAsTarget = false;

    // 1) insert
    // TODO: when splitting a targets fraction with the newly added source, we still need to ensure that the fractions dont get too small
    // TODO: actually, checking for minumum size in mondrian does not make much sense, need to check for minimum fraction instead
    // TODO: depending on the min fraction, this also imposes a limit on how many children a branch can have

    // ============================================================================================================ <
    // TODO: only unhandled center drop case is if the resulting tabLeaf becomes the new root
    // ============================================================================================================ >

    // (1) INSERTION ===========================================================
    // (1-A) INTO CENTER -------------------------------------------------------
    if (targetSide.isCenter) {
      // x) into tab group
      _tree = _tree.updatePath(targetPathToParent, (parent) {
        (parent as MondrianTreeBranch);

        // Must be a leaf, since can only drop onto leafs (this includes the tab leaf)
        final targetLeaf = parent.children[targetChildIndex] as MondrianTreeLeaf;
        final newTarget = _addLeafToLeafAsTab(
          targetLeaf: targetLeaf,
          sourceLeaf: sourceNode,
        );

        final newChildren = [...parent.children];
        newChildren[targetChildIndex] = newTarget;

        return parent.copyWith(
          children: newChildren,
        );
      });
    }
    // (1-B) INTO SAME AXIS ----------------------------------------------------
    else if (targetSide.asAxis == targetAxis) {
      _tree = _tree.updatePath(targetPathToParent, (node) {
        final branch = node as MondrianTreeBranch;
        final children = branch.children;

        /// FIRST CHECK IF THE SOURCE AND THE TARGET ARE INSIDE THE SAME BRANCH ALREADY
        /// if so, we only need to change the order and were done
        /// we wont need to change fractions or remove it in the second step
        int sourceInTargetsParent = children.indexWhere((e) => (e is MondrianTreeLeaf && e.id == sourceNode.id));
        if (sourceInTargetsParent != -1) {
          // set this flag to skip the removal part later
          skipRemovalForSourceInSameParentAsTarget = true;

          // can also return directly without having to adjust the paths for the removal part
          // ... since we skip that
          return branch.copyWith(
            children: [
              for (int i = 0; i < children.length; i++)
                // skip the old position of the source
                if (i != sourceInTargetsParent)
                  if (i == targetChildIndex) ...[
                    // add source before or after the target
                    if (targetSide.isPositionBefore!) ...[
                      children[sourceInTargetsParent],
                      children[targetChildIndex],
                    ] else ...[
                      children[targetChildIndex],
                      children[sourceInTargetsParent],
                    ],
                  ] else ...[
                    // add all others normaly
                    children[i],
                  ]
            ],
          );
        }

        /// ADJUST THE PATHS TO WHAT THEY WILL BE AFTER MOVING.
        /// DONT NEED THESE VALUES FOR THE ADDING STEP ANYMORE,
        /// SINCE WE ALREADY HAVE ALL THE OBJECTS SECURED.
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
          // . source path here is the path to the tab group
          // . since source and target can be the same, we must check for ">=" instead of "="
          // _ § Moving tab from inside tab leaf [0,0] to the left of that same tab leaf at [0,0]
          if (sourcePath[targetPath.length - 1] >= targetPath.last && targetSide.isPositionBefore!) {
            // TODO!!!!!!!!!!
            sourcePath[targetPath.length - 1] += 1;
          }
        }

        return _addLeafToBranch(
          targetParentBranch: branch,
          targetIndexInParent: targetChildIndex,
          sourceLeaf: sourceNode,
          isBefore: targetSide.isPositionBefore!,
        );
      });
    }
    // (1-C) INTO OPPOSING AXIS ------------------------------------------------
    else {
      //    -- other axis
      //      => replace child with branch and insert child and source there (both .5 fraction)
      _tree = _tree.updatePath(targetPath, (node) {
        final leaf = node as MondrianTreeLeaf;

        bool isBefore = targetSide.isPositionBefore!;

        // When moving a tab out from the group into the new branch shared with the group,
        // We must adjust the paths
        if (isTabMoving && listEquals(targetPath, sourcePath)) {
          int added = isBefore ? 1 : 0;
          targetPath = [...targetPath, added];
          sourcePath = [...sourcePath, added];
        }

        return _addLeafToLeafAsNewBranch(
          targetLeaf: leaf,
          sourceLeaf: sourceNode,
          isBefore: isBefore,
        );
      });
    }

    // (2) REMOVAL =============================================================
    // TODO REFACTOR

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
    } else if (!skipRemovalForSourceInSameParentAsTarget) {
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

  static MondrianTree createLeaf({
    required MondrianTree tree,
    required MondrianTreePath targetPathToLeaf,
    required MondrianLeafMoveTargetDropPosition targetSide,
    required MondrianTreeLeafId newLeafId,
  }) {
    // actual fraction will be set in _add.. methods
    final sourceLeaf = MondrianTreeLeaf(id: newLeafId, fraction: -1);

    if (targetPathToLeaf.isEmpty) {
      assert(tree.rootNode is MondrianTreeLeaf);
      return _addLeafToRoot(
        sourceLeaf: sourceLeaf,
        targetRoot: tree.rootNode as MondrianTreeLeaf,
        targetRootAxis: tree.rootAxis,
        targetSide: targetSide,
      );
    }

    // can be empty if root is branch and target is a leaf in root branch
    final targetPathToParent = targetPathToLeaf.sublist(0, targetPathToLeaf.length - 1);
    final targetPathIndexInParent = targetPathToLeaf.last;
    return tree.updatePath(targetPathToParent, (parent) {
      (parent as MondrianTreeBranch);
      final targetLeaf = parent.children[targetPathIndexInParent] as MondrianTreeLeaf;

      if (targetSide.isCenter) {
        final newChildren = [...parent.children];
        newChildren[targetPathIndexInParent] = _addLeafToLeafAsTab(
          targetLeaf: targetLeaf,
          sourceLeaf: sourceLeaf,
        );
        return parent.copyWith(children: newChildren);
      }

      final isBefore = targetSide.isPositionBefore!;
      final targetAxis = targetPathToLeaf.length.isOdd ? tree.rootAxis : tree.rootAxis.next;
      final isSameAxis = targetAxis == targetSide.asAxis;
      if (isSameAxis) {
        return _addLeafToBranch(
          targetParentBranch: parent,
          targetIndexInParent: targetPathIndexInParent,
          sourceLeaf: sourceLeaf,
          isBefore: isBefore,
        );
      } else {
        final newChildren = [...parent.children];
        newChildren[targetPathIndexInParent] = _addLeafToLeafAsNewBranch(
          targetLeaf: targetLeaf,
          sourceLeaf: sourceLeaf,
          isBefore: isBefore,
        );
        return parent.copyWith(children: newChildren);
      }
    });
  }
}

class MondrianMarshalSvc {
  // =========================================================================== AXIS
  static String encAxis(MondrianAxis axis) {
    switch (axis) {
      case MondrianAxis.horizontal:
        return "horizontal";
      case MondrianAxis.vertical:
        return "vertical";
    }
  }

  static MondrianAxis decAxis(String s) {
    switch (s) {
      case "horizontal":
        return MondrianAxis.horizontal;
      case "vertical":
        return MondrianAxis.vertical;
      default:
        throw "No such value: $s";
    }
  }

  // =========================================================================== TREE
  static Map<String, Object> encTree(MondrianTree tree) {
    return {
      "rootAxis": tree.rootAxis.encode(),
      "rootNode": encNodeAbst(tree.rootNode),
    };
  }

  static MondrianTree decTree(Map m) {
    return MondrianTree(
      rootAxis: MondrianAxisX.decode(m["rootAxis"] as String),
      rootNode: decNodeAbst(m["rootNode"] as Map),
    );
  }

  // =========================================================================== NODE - ABST
  static Map<String, Object> encNodeAbst(MondrianNodeAbst node) {
    if (node is MondrianTreeBranch) {
      return {
        "type": "branch",
        "data": encBranch(node),
      };
    }
    if (node is MondrianTreeTabLeaf) {
      return {
        "type": "tabLeaf",
        "data": encTabLeaf(node),
      };
    }
    if (node is MondrianTreeLeaf) {
      return {
        "type": "leaf",
        "data": encLeaf(node),
      };
    }
    throw "Unknown type: ${node.runtimeType}";
  }

  static MondrianNodeAbst decNodeAbst(Map m) {
    final String type = m["type"];
    final Map data = m["data"];

    if (type == "branch") {
      return decBranch(data);
    }
    if (type == "tabLeaf") {
      return decTabLeaf(data);
    }
    if (type == "leaf") {
      return decLeaf(data);
    }
    throw "Unknown type: $type";
  }

  // =========================================================================== LEAF
  static Map<String, Object> encLeaf(MondrianTreeLeaf leaf) {
    return {
      "fraction": leaf.fraction.toString(),
      "id": leaf.id.value,
    };
  }

  static MondrianTreeLeaf decLeaf(Map m) {
    return MondrianTreeLeaf(
      fraction: double.parse(m["fraction"] as String),
      id: MondrianTreeLeafId(m["id"]),
    );
  }

  // =========================================================================== TAB LEAF
  static Map<String, Object> encTabLeaf(MondrianTreeTabLeaf tabLeaf) {
    return {
      "fraction": tabLeaf.fraction.toString(),
      "tabs": tabLeaf.tabs.map((e) => e.value).toList(),
      "activeTabIndex": tabLeaf.activeTabIndex.toString(),
    };
  }

  static MondrianTreeTabLeaf decTabLeaf(Map m) {
    return MondrianTreeTabLeaf(
      fraction: double.parse(m["fraction"] as String),
      tabs: (m["tabs"] as List<String>).map((e) => MondrianTreeLeafId(e)).toList(),
      activeTabIndex: int.parse(m["activeTabIndex"] as String),
    );
  }

  // =========================================================================== BRANCH
  static Map<String, Object> encBranch(MondrianTreeBranch branch) {
    return {
      "fraction": branch.fraction.toString(),
      "children": branch.children.map((node) => encNodeAbst(node)).toList(),
    };
  }

  static MondrianTreeBranch decBranch(Map m) {
    return MondrianTreeBranch(
      fraction: double.parse(m["fraction"] as String),
      children: (m["children"] as List<Map>).map((Map node) => decNodeAbst(node)).toList(),
    );
  }
}
