import 'package:flutter/material.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';

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

typedef LeafResolver = Widget Function(WindowManagerLeafId);

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
  /// The [path] points to the node before the seperator.
  /// The [newFraction] also points to the node before the seperator, the difference must be subtracted from the node after.
  final void Function(WindowManagerTreePath path, double newFraction) onResize;

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
  final void Function(WindowManagerTreePath path, double newFraction) onResize;

  /// See [MondrianWM.resolveLeafToWidget]
  final LeafResolver resolveLeafToWidget;

  final WindowManagerTreePath path;

  void onDragUpdate(DragUpdateDetails d, BoxConstraints bc, int index) {
    final double deltaAxis = axis.isHorizontal ? d.delta.dx : d.delta.dy;
    final double maxExtendAxis = axis.isHorizontal ? bc.maxWidth : bc.maxHeight;
    print("drag update");
  }

  static const double _dragWidth = 2;

  @override
  Widget build(BuildContext context) {
    if (node is WindowManagerLeaf) {
      return resolveLeafToWidget((node as WindowManagerLeaf).id);
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
              width: axis.isHorizontal ? _dragWidth : null,
              height: axis.isVertical ? _dragWidth : null,
            ),
          ),
        );

    return LayoutBuilder(
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
    );
  }
}

extension _AxisX on Axis {
  bool get isHorizontal => this == Axis.horizontal;
  bool get isVertical => this == Axis.vertical;

  Axis get next {
    switch (this) {
      case Axis.horizontal:
        return Axis.vertical;
      case Axis.vertical:
        return Axis.horizontal;
    }
  }
}
