import 'package:flutter/foundation.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';
import 'package:mondrian/src/utils.dart';

enum MondrianAxis {
  horizontal,
  vertical,
}

extension WindowAxisX on MondrianAxis {
  MondrianAxis get previous => MondrianAxis.values[(index - 1) % MondrianAxis.values.length];
  MondrianAxis get next => MondrianAxis.values[(index + 1) % MondrianAxis.values.length];

  bool get isHorizontal => MondrianAxis.horizontal == this;
  bool get isVertical => MondrianAxis.vertical == this;
}

/// The index for each child that must be passed to reach the destination node.
typedef MondrianTreePath = List<int>;

/// Container for [MondrianTreePath] with the extension of [tabIndexIfAny] which is non null if the path points to a tab inside a tab leaf
// TODO consider using this object in other callbacks (e.g. for move)
class MondrianTreePathWithTabIndexIfAny {
  final MondrianTreePath path;
  final int? tabIndexIfAny;

  MondrianTreePathWithTabIndexIfAny({
    required this.path,
    required this.tabIndexIfAny,
  });
}

/// The tree of [MondrianNodeAbst]s specifying the partition of the window.
class MondrianTree {
  final MondrianNodeAbst rootNode;
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

  MondrianNodeAbst extractPath(MondrianTreePath path) {
    if (rootNode is MondrianTreeLeaf) {
      assert(path.isEmpty);
      return rootNode;
    } else if (rootNode is MondrianTreeBranch) {
      return (rootNode as MondrianTreeBranch).extractPath(path);
    }
    throw "Unknown type ${rootNode.runtimeType}";
  }

  // TODO consider adding a method "leafPathFromId(WindowLeafId)" that searches the tree recursively, while building a path and returning it on match

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MondrianTree && other.rootNode == rootNode;
  }

  @override
  int get hashCode => rootNode.hashCode;

  @override
  String toString() => 'MondrianTreeTree(rootNode: $rootNode)';
}

typedef NodeUpdater = MondrianNodeAbst Function(MondrianNodeAbst node);

/// A part of the [MondrianTree], either a [MondrianTreeBranch] or a [MondrianTreeLeaf].
abstract class MondrianNodeAbst {
  /// The fraction of the parent slice taken up by this slice
  double get fraction;

  const MondrianNodeAbst();

  MondrianNodeAbst updatePath(MondrianTreePath path, NodeUpdater updateNode);

  MondrianNodeAbst updateFraction(double newFraction);
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

/// Lead in the tree, represents a single widget.
///
/// Can be placed inside [MondrianTreeBranch].
class MondrianTreeLeaf extends MondrianNodeAbst {
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
  MondrianNodeAbst updatePath(MondrianTreePath path, NodeUpdater updateNode) {
    assert(path.isEmpty, "Arrived at leaf, but path is not yet empty: $path");
    return updateNode(this);
  }

  @override
  MondrianNodeAbst updateFraction(double newFraction) => MondrianTreeLeaf(id: id, fraction: newFraction);

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
        id: MondrianTreeTabLeafId(_idGen.next.value),
        fraction: fraction,
        tabs: tabs,
        activeTabIndex: activeTabIndex,
      );

  @override
  MondrianNodeAbst updateFraction(double newFraction) {
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

// TODO extend WindowManagerLeafIdInternal instead once implemented
class MondrianTreeTabLeafId extends MondrianTreeLeafId {
  const MondrianTreeTabLeafId(String value) : super(value);
}

/// Row or Column inside the [MondrianTree].
/// Can contain [MondrianTreeLeaf]s as well as further [MondrianTree]s.
///
/// The axis direction of this branch depends on the [MondrianTree.initialAxis] and the depth of this branch.
/// § Axis.horizontal => Row => Column => Row => ...
class MondrianTreeBranch extends MondrianNodeAbst {
  @override
  final double fraction;

  /// The children contained within this branch.
  final List<MondrianNodeAbst> children;

  const MondrianTreeBranch({
    required this.fraction,
    required this.children,
  });

  @override
  MondrianNodeAbst updatePath(MondrianTreePath path, NodeUpdater updateNode) {
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

  MondrianNodeAbst extractPath(MondrianTreePath path) {
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
  MondrianNodeAbst updateFraction(double newFraction) => MondrianTreeBranch(children: children, fraction: newFraction);

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
}
