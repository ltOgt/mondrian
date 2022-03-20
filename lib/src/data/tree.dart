import 'package:flutter/foundation.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';

import 'package:mondrian/mondrian.dart';
import 'package:mondrian/src/utils.dart';

// ============================================================================= TYPEDEF

typedef NodeUpdater = MondrianTreeNodeAbst Function(MondrianTreeNodeAbst node);

// ============================================================================= TREE

/// The tree of [MondrianTreeNodeAbst]s specifying the partition of the window.
class MondrianTree {
  final MondrianTreeNodeAbst rootNode;
  final MondrianAxis rootAxis;

  const MondrianTree({
    required this.rootNode,
    required this.rootAxis,
  });

  MondrianTreePathWithTabIndexIfAny? pathFromId(MondrianTreeLeafId id) =>
      MondrianTreeManipulationService.treePathFromId(id, this);

  MondrianTree updatePath(MondrianTreePath path, NodeUpdater updateNode) {
    if (rootNode is MondrianTreeLeaf) {
      final n = (rootNode as MondrianTreeLeaf);
      return MondrianTree(
        rootNode: n.updatePath(path, updateNode),
        rootAxis: rootAxis,
      );
    } else if (rootNode is MondrianTreeBranch) {
      final n = (rootNode as MondrianTreeBranch);
      return MondrianTree(
        rootNode: n.updatePath(path, updateNode),
        rootAxis: rootAxis,
      );
    }
    throw "Unknown type ${rootNode.runtimeType}";
  }

  MondrianTreeNodeAbst extractPath(MondrianTreePath path) {
    if (rootNode is MondrianTreeLeaf) {
      assert(path.isEmpty);
      return rootNode;
    } else if (rootNode is MondrianTreeBranch) {
      return (rootNode as MondrianTreeBranch).extractPath(path);
    }
    throw "Unknown type ${rootNode.runtimeType}";
  }

  MondrianTree moveLeaf({
    required MondrianTreePath sourcePath,
    required MondrianTreePath targetPath,
    required MondrianLeafMoveTargetDropPosition targetSide,
    // this is needed on tab move, since the sourcePath still points to the parent (the tab leaf)
    required int? tabIndexIfAny,
  }) =>
      MondrianTreeManipulationService.moveLeaf(
        tree: this,
        sourcePath: sourcePath,
        targetPath: targetPath,
        targetSide: targetSide,
        tabIndexIfAny: tabIndexIfAny,
      );

  /// Create a new leaf next-to or inside an existing leaf
  MondrianTree createLeaf({
    required MondrianTreePath targetPathToLeaf,
    required MondrianLeafMoveTargetDropPosition targetSide,
    required MondrianTreeLeafId newLeafId,
  }) =>
      MondrianTreeManipulationService.createLeaf(
        tree: this,
        targetPathToLeaf: targetPathToLeaf,
        targetSide: targetSide,
        newLeafId: newLeafId,
      );

  MondrianTree deleteLeaf({
    required MondrianTreePath sourcePathToLeaf,
    // needed on deletion of tabs, since sourcePath still points to the parent (the tab leaf)
    required int? tabIndexIfAny,
  }) =>
      MondrianTreeManipulationService.deleteLeaf(
        tree: this,
        sourcePathToLeaf: sourcePathToLeaf,
        tabIndexIfAny: tabIndexIfAny,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MondrianTree && other.rootNode == rootNode && other.rootAxis == rootAxis;
  }

  @override
  int get hashCode => rootNode.hashCode ^ rootAxis.hashCode;

  @override
  String toString() => 'MondrianTree(rootNode: $rootNode, rootAxis: $rootAxis)';

  Map<String, Object> encode() => MondrianMarshalSvc.encTree(this);
  static MondrianTree decode(Map m) => MondrianMarshalSvc.decTree(m);
}

// ============================================================================= ABSTRACT BASE NODE

/// A part of the [MondrianTree], either a [MondrianTreeBranch] or a [MondrianTreeLeaf].
abstract class MondrianTreeNodeAbst {
  /// The fraction of the parent slice taken up by this slice
  double get fraction;

  const MondrianTreeNodeAbst();

  MondrianTreeNodeAbst updatePath(MondrianTreePath path, NodeUpdater updateNode);

  MondrianTreeNodeAbst updateFraction(double newFraction);
}

/// Id to identify a [MondrianTreeLeaf]
class MondrianTreeLeafId {
  final String value;
  const MondrianTreeLeafId(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MondrianTreeLeafId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MondrianTreeLeafId(value: $value)';
}

// ============================================================================= NODE - TREE LEAF

/// Leaf in the tree, represents a single widget.
///
/// Can be placed inside [MondrianTreeBranch].
class MondrianTreeLeaf extends MondrianTreeNodeAbst {
  @override
  final double fraction;

  /// The id representing this leaf.
  /// Used by [_MondrianLayoutAndResize._resolveLeafToWidget] to resolve the widget representing this leaf.
  final MondrianTreeLeafId id;

  const MondrianTreeLeaf({
    required this.id,
    required this.fraction,
  });

  @override
  MondrianTreeNodeAbst updatePath(MondrianTreePath path, NodeUpdater updateNode) {
    assert(path.isEmpty, "Arrived at leaf, but path is not yet empty: $path");
    return updateNode(this);
  }

  @override
  MondrianTreeNodeAbst updateFraction(double newFraction) => MondrianTreeLeaf(id: id, fraction: newFraction);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MondrianTreeLeaf && other.fraction == fraction && other.id == id;
  }

  @override
  int get hashCode => fraction.hashCode ^ id.hashCode;

  @override
  String toString() => 'MondrianTreeLeaf(fraction: $fraction, id: $id)';
}

// ============================================================================= NODE - TREE LEAF - TAB LEAF

// TODO extend WindowManagerLeafIdInternal instead once implemented
class MondrianTreeTabLeafId extends MondrianTreeLeafId {
  const MondrianTreeTabLeafId(String value) : super(value);
}

/// Leaf in the tree, represents a collection of [MondrianTreeLeafId]s.
///
/// Instead of being placed directly in the [MondrianTree],
/// these leaf ids are instead placed inside tabs inside this [MondrianTreeTabLeaf].
///
/// Can be placed inside [MondrianTreeBranch].
class MondrianTreeTabLeaf extends MondrianTreeLeaf {
  final int activeTabIndex;
  final List<MondrianTreeLeafId> tabs;

  MondrianTreeLeafId get activeTab => tabs[activeTabIndex];

  const MondrianTreeTabLeaf._({
    required MondrianTreeLeafId id,
    required double fraction,
    required this.tabs,
    required this.activeTabIndex,
  }) : super(id: id, fraction: fraction);

  static final CircleIdGen _idGen = CircleIdGen();

  factory MondrianTreeTabLeaf({
    required double fraction,
    required List<MondrianTreeLeafId> tabs,
    required int activeTabIndex,
  }) =>
      MondrianTreeTabLeaf._(
        // Instead of exposing a "real" leaf id, a transient generated leaf id is used
        // This is needed for moving the entire tab container, but is not of interest to the user of this package.
        id: MondrianTreeTabLeafId(_idGen.next.value),
        fraction: fraction,
        tabs: tabs,
        activeTabIndex: activeTabIndex,
      );

  @override
  MondrianTreeNodeAbst updateFraction(double newFraction) {
    return MondrianTreeTabLeaf._(
      id: id,
      fraction: newFraction,
      tabs: tabs,
      activeTabIndex: activeTabIndex,
    );
  }

  MondrianTreeTabLeaf copyWith({
    double? fraction,
    List<MondrianTreeLeafId>? tabs,
    int? activeTabIndex,
  }) =>
      MondrianTreeTabLeaf._(
        id: id,
        fraction: fraction ?? this.fraction,
        tabs: tabs ?? this.tabs,
        activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      );
}

// ============================================================================= NODE - TREE BRANCH

/// Row or Column inside the [MondrianTree].
/// Can contain [MondrianTreeLeaf]s as well as further [MondrianTree]s.
///
/// The axis direction of this branch depends on the [MondrianTree.initialAxis] and the depth of this branch.
/// § Axis.horizontal => Row => Column => Row => ...
class MondrianTreeBranch extends MondrianTreeNodeAbst {
  @override
  final double fraction;

  /// The children contained within this branch.
  final List<MondrianTreeNodeAbst> children;

  const MondrianTreeBranch({
    required this.fraction,
    required this.children,
  });

  @override
  MondrianTreeNodeAbst updatePath(MondrianTreePath path, NodeUpdater updateNode) {
    if (path.isEmpty) {
      return updateNode(this);
    }
    return MondrianTreeBranch(
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

  MondrianTreeNodeAbst extractPath(MondrianTreePath path) {
    final child = children[path.first];
    final remainder = path.skip(1).toList();

    if (child is MondrianTreeLeaf) {
      assert(remainder.isEmpty);
      return child;
    } else if (child is MondrianTreeBranch) {
      return child.extractPath(remainder);
    }
    throw "Unknown type ${child.runtimeType}";
  }

  @override
  MondrianTreeNodeAbst updateFraction(double newFraction) =>
      MondrianTreeBranch(children: children, fraction: newFraction);

  MondrianTreeBranch updateChildFraction({required int index, required double newFraction}) {
    final child1 = children[index];
    final child2 = children[index + 1];

    final diff = child1.fraction - newFraction;
    final new2 = child2.fraction + diff;
    // round both to avoid precision issues
    final newRounded = cutPrecision(newFraction);
    final new2Rounded = cutPrecision(new2);

    final child1Updated = child1.updateFraction(newRounded);
    final child2Updated = child2.updateFraction(new2Rounded);

    return MondrianTreeBranch(
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

    return other is MondrianTreeBranch && other.fraction == fraction && listEquals(other.children, children);
  }

  @override
  int get hashCode => fraction.hashCode ^ children.hashCode;

  @override
  String toString() => 'MondrianTreeBranch(fraction: $fraction, children: $children)';

  MondrianTreeBranch copyWith({
    double? fraction,
    List<MondrianTreeNodeAbst>? children,
  }) {
    return MondrianTreeBranch(
      fraction: fraction ?? this.fraction,
      children: children ?? this.children,
    );
  }
}
