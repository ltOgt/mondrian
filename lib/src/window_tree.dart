import 'package:flutter/foundation.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:mondrian/src/utils.dart';

/// The index for each child that must be passed to reach the destination node.
typedef WindowManagerTreePath = List<int>;

/// The tree of [WindowManagerNodeAbst]s specifying the partition of the window.
class WindowManagerTree {
  final WindowManagerNodeAbst rootNode;

  const WindowManagerTree({
    required this.rootNode,
  });

  WindowManagerTree updatePath(WindowManagerTreePath path, NodeUpdater updateNode) {
    if (rootNode is WindowManagerLeaf) {
      final n = (rootNode as WindowManagerLeaf);
      return WindowManagerTree(rootNode: n.updatePath(path, updateNode));
    } else if (rootNode is WindowManagerBranch) {
      final n = (rootNode as WindowManagerBranch);
      return WindowManagerTree(rootNode: n.updatePath(path, updateNode));
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WindowManagerTree && other.rootNode == rootNode;
  }

  @override
  int get hashCode => rootNode.hashCode;
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
}

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
}

/// Row or Column inside the [WindowManagerTree].
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
}
