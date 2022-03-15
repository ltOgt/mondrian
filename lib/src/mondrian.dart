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

extension WindowAxisFlutterX on MondrianAxis {
  Axis get asFlutterAxis {
    switch (this) {
      case MondrianAxis.horizontal:
        return Axis.horizontal;
      case MondrianAxis.vertical:
        return Axis.vertical;
    }
  }
}

class MondrianWidget extends StatefulWidget {
  const MondrianWidget({
    Key? key,
    required this.tree,
    required this.onMoveDone,
    required this.onResizeDone,
  }) : super(key: key);

  final MondrianTree tree;
  final void Function(MondrianTree tree) onResizeDone;
  final void Function(MondrianTree tree) onMoveDone;

  @override
  State<MondrianWidget> createState() => MondrianWidgetState();
}

class MondrianWidgetState<M extends MondrianWidget> extends State<M> {
  MondrianTreeLeafId? movingId;
  List<int>? lastMovingPath;

  @override
  Widget build(BuildContext context) {
    return _MondrianLayoutAndResize(
      tree: widget.tree,
      initialAxis: widget.tree.rootAxis.asFlutterAxis,
      onResize: (pathToParent, newFraction, index) {
        final updatedTree = widget.tree.updatePath(pathToParent, (node) {
          return (node as MondrianTreeBranch).updateChildFraction(
            index: index,
            newFraction: newFraction,
          );
        });
        widget.onResizeDone(updatedTree);
      },
      resolveLeafToWidget: resolveLeaf,
    );
  }

  // TODO might want to change Axis to MondrianAxis instead (can still convert to flutter axis as needed, just feels cleaner)
  Widget resolveLeaf(MondrianTreeLeaf leaf, MondrianTreePath leafPath, Axis leafAxis) {
    if (leaf is MondrianTreeTabLeaf) {
      final tabLeaf = leaf;
      return Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab header
          // TODO must be scrollable if to long
          SizedBox(
            height: 20,
            child: Row(
              children: [
                for (int i = 0; i < tabLeaf.tabs.length; i++) ...[
                  WindowMoveHandle(
                    dragIndicator: Container(
                      height: 100,
                      width: 100,
                      color: Colors.white.withAlpha(100),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        // TODO consider adding a new method for onTabSwitch or joining move and resize to onTreeChanged
                        widget.onMoveDone(
                          widget.tree.updatePath(leafPath, (_tabLeaf) {
                            _tabLeaf as MondrianTreeTabLeaf;
                            return _tabLeaf.copyWith(activeTabIndex: i);
                          }),
                        );
                      },
                      child: Container(
                        height: 20,
                        width: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueAccent),
                          color: (i == tabLeaf.activeTabIndex) ? Colors.grey : Colors.black,
                        ),
                        child: AutoSizeText(text: tabLeaf.tabs[i].value),
                      ),
                    ),
                    onMoveEnd: () {
                      movingId = null;
                      setState(() {});
                    },
                    onMoveStart: () {
                      movingId = tabLeaf.tabs[i];
                      lastMovingPath = [...leafPath, i]; // ADD TAB INDEX TO PATH
                      setState(() {});
                    },
                    onMoveUpdate: (d) {},
                  ),
                ],
                // Complete lead with all tabs
                Expanded(
                  child: WindowMoveHandle(
                    dragIndicator: Container(
                      height: 100,
                      width: 100,
                      color: Colors.white.withAlpha(100),
                    ),
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent),
                        color: Colors.black,
                      ),
                    ),
                    onMoveEnd: () {
                      movingId = null;
                      setState(() {});
                    },
                    onMoveStart: () {
                      movingId = tabLeaf.id;
                      lastMovingPath = [...leafPath]; // ADD TAB INDEX TO PATH
                      setState(() {});
                    },
                    onMoveUpdate: (d) {},
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: WindowMoveTarget(
              onDrop: (pos) {
                // TODO adjust source tab and potential destination tab
                // TODO also listen for pos == center
                // widget.onMoveDone(
                //   widget.tree.moveLeaf(
                //     sourcePath: lastMovingPath!,
                //     targetPath: leafPath,
                //     targetSide: pos,
                //   ),
                // );
              },
              isActive: movingId != null && movingId != leaf.id && !tabLeaf.tabs.contains(movingId),
              target: Container(
                color: Colors.red,
              ),
              child: Center(
                child: AutoSizeText(
                  text: tabLeaf.activeTab.value,
                ), // + " ${(tree.extractPath(path) as WindowManagerLeaf).fraction}"),
              ),
            ),
          ),
        ],
      );
    }

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
            movingId = leaf.id;
            lastMovingPath = leafPath;
            setState(() {});
          },
          onMoveUpdate: (d) {},
        ),
        Expanded(
          child: WindowMoveTarget(
            onDrop: (pos) {
              widget.onMoveDone(
                widget.tree.moveLeaf(
                  sourcePath: lastMovingPath!,
                  targetPath: leafPath,
                  targetSide: pos,
                ),
              );
            },
            isActive: movingId != null && movingId != leaf.id,
            target: Container(
              color: Colors.red,
            ),
            child: Center(
              child:
                  AutoSizeText(text: leaf.id.value), // + " ${(tree.extractPath(path) as WindowManagerLeaf).fraction}"),
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

typedef LeafResolver = Widget Function(MondrianTreeLeaf leafNode, MondrianTreePath path, Axis axis);

class _MondrianLayoutAndResize extends StatelessWidget {
  const _MondrianLayoutAndResize({
    Key? key,
    required this.tree,
    required this.onResize,
    required this.resolveLeafToWidget,
    required this.initialAxis,
  }) : super(key: key);

  final MondrianTree tree;

  /// Called when a the seperator between two nodes is used to resize the nodes next to it.
  /// The [pathToParent] points to the parent branch in which the children have been resized.
  /// The [index] points to the node before the seperator inside the list of children pointerd to by [pathToParent].
  /// The [newFraction] also points to the node before the seperator, the difference must be subtracted from the node after.
  final void Function(MondrianTreePath pathToParent, double newFraction, int index) onResize;

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
  static const _minNodeExtend = 40;

  const _MondrianNode({
    Key? key,
    required this.node,
    required this.axis,
    required this.onResize,
    required this.resolveLeafToWidget,
    required this.path,
  }) : super(key: key);

  final MondrianNodeAbst node;
  final Axis axis;

  /// See [_MondrianLayoutAndResize.onResize]
  final void Function(MondrianTreePath pathToParent, double newFraction, int index) onResize;

  /// See [_MondrianLayoutAndResize.resolveLeafToWidget]
  final LeafResolver resolveLeafToWidget;

  final MondrianTreePath path;

  static const double _dragWidth = 2;

  void onDragUpdate(DragUpdateDetails d, BoxConstraints bc, int index) {
    final delta = d.delta;

    final double deltaAxis = axis.isHorizontal ? delta.dx : delta.dy;
    final double maxExtendAxis = axis.isHorizontal ? bc.maxWidth : bc.maxHeight;

    /// xtnd = max * frac
    /// xtnd' = max * frac'
    /// frac' = xtnd' / max

    final double oldFraction = (node as MondrianTreeBranch).children[index].fraction;
    final double oldExtend = maxExtendAxis * oldFraction;
    final double newExtend = (oldExtend + deltaAxis);
    final double newFraction = newExtend / maxExtendAxis;

    // check minimum extend of this node and its neighbour
    if (newExtend < _minNodeExtend) return;
    // guaranteed to have a neighbour node, otherwise could not resize at this index
    final neighbourFraction = (node as MondrianTreeBranch).children[index + 1].fraction;
    final newNeighbourFraction = neighbourFraction + (oldFraction - newFraction);
    final newNeighbourExtend = maxExtendAxis * newNeighbourFraction;
    if (newNeighbourExtend < _minNodeExtend) return;

    onResize(path, newFraction, index);
  }

  @override
  Widget build(BuildContext context) {
    if (node is MondrianTreeLeaf) {
      // Either an actual leaf or a tab group
      return resolveLeafToWidget(node as MondrianTreeLeaf, path, axis.previous);
    }
    final nextAxis = axis.next;

    final children = (node as MondrianTreeBranch).children;
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
                //TODO: _______________________________________________________
                // might even consider using only integers instead of doubles
                // like e.g a step count of 100.000 would already equal the current 1.00000 precision
                // without any of the rounding issues
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
