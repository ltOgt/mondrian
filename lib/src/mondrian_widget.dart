import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';
import 'package:mondrian/src/debug.dart';

// TODO consider adding the actual nodes as well, i think they should be available to the caller of the callback anyways => no need for extra lookup

// TODO need to add "can move" flag; either into the tree, via a callback or via a set of ids

// TODO need to disable move targets iff too small already

// TODO need to enable scrolling if too little space for all widgets to fit with their min width

/// {@template TabBuilder}
/// Builds the tab indicator inside tab bar for the [tabIndex] of the [MondrianTreeTabLeaf] under [tabLeafPath].
///
/// The tab will be draggable on the widget returned by this function.
///
/// Does NOT build the content of the leaf itself.
/// {@endtemplate}
typedef TabIndicatorBuilder = Widget Function(
  MondrianTreePath tabLeafPath,
  int tabIndex,
);

/// {@template TabBarBuilder}
/// Builds the tab bar background belonging to the [MondrianTreeTabLeaf] under [tabLeafPath].
///
/// The entire tab container will be draggable on the widget returned by this function.
/// {@endtemplate}
typedef TabBarBuilder = Widget Function(
  MondrianTreePath tabLeafPath,
);

/// {@template MoveDragIndicatorBuilder}
/// Build the indicator shown when dragging the [MondrianTreeLeaf] under [leafPath].
/// If the leaf is a [MondrianTreeTabLeaf], the [tabIndex] will be set as well.
/// {@endtemplate}
typedef MoveDragIndicatorBuilder = Widget Function(
  MondrianTreePath leafPath,
  int? tabIndex,
);

/// {@template LeafBuilder}
/// Build the actual content of the [MondrianTreeLeaf] under [leafPath].
/// If the leaf is a [MondrianTreeTabLeaf], the [tabIndex] will be set as well.
/// {@endtemplate}
typedef LeafBuilder = Widget Function(
  MondrianTreePath leafPath,
  int? tabIndex,
);

/// {@template LeafBarBuilder}
/// Builds the bar belonging to the [MondrianTreeLeaf] under [leafPath].
///
/// The leaf will be draggable on the widget returned by this function.
/// {@endtemplate}
typedef LeafBarBuilder = Widget Function(
  MondrianTreePath leafPath,
);

// ============================================================================= WIDGET - MONDRIAN PUBLIC API

/// Mondrian Window Manager.
///
/// Turns [MondrianTree] into a re-sizable and re-orderable [Widget]s that are
/// arranged via nested [Column]s and [Row]s.
class MondrianWidget extends StatefulWidget {
  const MondrianWidget({
    Key? key,
    required this.tree,
    required this.onUpdateTree,
    required this.buildLeaf,
    this.buildLeafBar,
    this.leafBarHeight = 20,
    this.buildTabIndicator,
    this.buildTabBar,
    this.tabBarHeight = 20,
    this.tabBarMinOverhangWidth = 100,
    this.tabIndicatorWidth = 100,
    this.buildMoveDragIndicator,
    this.resizeDraggerColor = const Color(0xFFAAAAFF),
    this.resizeDraggerWidth = 2,
    // TODO think about how to expose move targets, but maybe only visually changable, not position and size
  }) : super(key: key);

  // =========================================================================== FIELDS

  /// {@template mondrian-tree-param}
  /// The tree defining the current window layout.
  ///
  /// Contains [MondrianTreeLeafId] at its leafs.
  /// These ids can be used to resolve to widgets.
  /// See [buildTabIndicator], [buildTabBar], [buildMoveDragIndicator], [buildLeaf].
  ///
  /// Changes will be exposed to the parent via [onUpdateTree].
  /// {@endtemplate}
  final MondrianTree tree;

  /// Callback for when the [tree] was changed by the user.
  ///
  /// This can be caused by
  /// - resizing of two neighbouring windows (leafs/branches)
  /// - moving of a leaf
  /// - changing focus inside a tab leaf
  final void Function(MondrianTree tree) onUpdateTree;

  /// {@macro LeafBuilder}
  final LeafBuilder buildLeaf;

  /// {@macro LeafBarBuilder}
  final LeafBarBuilder? buildLeafBar;

  /// The height imposed on [buildLeafBar].
  final double leafBarHeight;

  /// {@macro TabBuilder}
  ///
  /// For the actual content belonging to the active tab see [buildLeaf].
  final TabIndicatorBuilder? buildTabIndicator;

  /// {@macro TabBarBuilder}
  final TabBarBuilder? buildTabBar;

  /// The height imposed on [buildTabBar].
  final double tabBarHeight;

  /// The minimum size of the visibible area of [buildTabBar] after the last [buildTabIndicator].
  ///
  /// If the [MondrianTreeTabLeaf] is wider than the space taken up by all its tabs, the overhang will fill the remaining area.
  ///
  /// If the tab is narrower than the space taken up by all its tabs, the bar becomes scrollable, and the overhand takes up [tabBarMinOverhangWidth].
  ///
  /// This is needed since the entire tab container can be moved via this overhang.
  final double tabBarMinOverhangWidth;

  /// The width imposed on [buildTabIndicator].
  final double tabIndicatorWidth;

  /// {@macro MoveDragIndicatorBuilder}
  final MoveDragIndicatorBuilder? buildMoveDragIndicator;

  final Color resizeDraggerColor;
  final double resizeDraggerWidth;

  @override
  State<MondrianWidget> createState() => _MondrianWidgetState();
}

class _MondrianWidgetState extends State<MondrianWidget> {
  // =========================================================================== STATE
  /// The leaf that is currently beeing moved.
  /// Can also be a tab leaf.
  ///
  /// Reset back to null once the moveDragIndicator is dropped.
  /// Needed to disable the drop targets for the leaf that is moved.
  /// Note that the drop target is not disabled for tab leafs.
  MondrianTreeLeafId? _movingLeaf;

  /// The path of the [_movingLeaf].
  ///
  /// Kepts around after the moveDragIndicator has been dropped again and [_movingLeaf] has been reset to `null`.
  ///
  /// This is needed to initiate the data-move inside the tree on the drop target.
  /// Will be reset after the data-move has been initiated.
  MondrianTreePath? _lastMovingPath;

  /// Like [_lastMovingPath] but as an addition for tabs.
  int? _lastMovingTabIndex;

  // =========================================================================== RESIZE
  void _onResize(
    MondrianTreePath pathToParent,
    double newFraction,
    int index,
  ) {
    widget.onUpdateTree(widget.tree.updatePath(pathToParent, (node) {
      return (node as MondrianTreeBranch).updateChildFraction(
        index: index,
        newFraction: newFraction,
      );
    }));
  }

  // =========================================================================== BUILD

  @override
  Widget build(BuildContext context) {
    return _MondrianLayoutAndResize(
      tree: widget.tree,
      onResize: _onResize,
      resolveLeafToWidget: _resolveLeafToWidget,
      resizeDraggerColor: widget.resizeDraggerColor,
      resizeDraggerWidth: widget.resizeDraggerWidth,
    );
  }

  void _onMoveStart(MondrianTreeLeafId leafId, MondrianTreePath leafPath, int? tabIndex) {
    _movingLeaf = leafId;
    _lastMovingPath = leafPath;
    _lastMovingTabIndex = tabIndex;
    setState(() {});
  }

  void _onMoveEnd() {
    _movingLeaf = null;
    setState(() {});
  }

  void _onDrop(
    MondrianMoveTargetDropPosition targetDropPosition,
    MondrianTreePath targetLeafPath,
  ) {
    widget.onUpdateTree(
      widget.tree.moveLeaf(
        targetPath: targetLeafPath,
        targetSide: targetDropPosition,
        sourcePath: _lastMovingPath!,
        tabIndexIfAny: _lastMovingTabIndex,
      ),
    );
  }

  // =========================================================================== RESOLVE LEAF
  Widget _resolveLeafToWidget(
    MondrianTreeLeaf leafNode,
    MondrianTreePath leafPath,
    MondrianAxis axis,
  ) {
    /// TAB LEAF
    if (leafNode is MondrianTreeTabLeaf) {
      final tabLeaf = leafNode;

      return Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab header
          LayoutBuilder(builder: (context, constraints) {
            return SizedBox(
              height: widget.tabBarHeight,
              width: constraints.maxWidth,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // TABS ----------------------------------------------------
                    for (int i = 0; i < tabLeaf.tabs.length; i++) ...[
                      WindowMoveHandle(
                        dragIndicator: widget.buildMoveDragIndicator?.call(leafPath, i) ?? _defaultMoveDragIndicator,
                        child: GestureDetector(
                          onTap: () => _setActiveTab(leafPath, i),
                          child: widget.buildTabIndicator?.call(leafPath, i) ??
                              _buildDefaultTabIndicator(
                                tabLeaf.tabs[i],
                                (i == tabLeaf.activeTabIndex),
                              ),
                        ),
                        onMoveEnd: _onMoveEnd,
                        onMoveStart: () {
                          _onMoveStart(leafNode.tabs[i], leafPath, i);
                          _setActiveTab(leafPath, i);
                        },
                        onMoveUpdate: (_) {},
                      ),
                    ],
                    // TAB OVERHANG --------------------------------------------
                    WindowMoveHandle(
                      dragIndicator: widget.buildMoveDragIndicator?.call(leafPath, null) ?? _defaultMoveDragIndicator,
                      child: SizedBox(
                        width: max(
                          constraints.maxWidth - (tabLeaf.tabs.length * widget.tabIndicatorWidth),
                          widget.tabBarMinOverhangWidth,
                        ),
                        child: widget.buildTabBar?.call(leafPath) ?? _buildDefaultTabOverhang(),
                      ),
                      onMoveEnd: _onMoveEnd,
                      onMoveStart: () {
                        _onMoveStart(leafNode.id, leafPath, null);
                      },
                      onMoveUpdate: (_) {},
                    ),
                  ],
                ),
              ),
            );
          }),
          // ACTUAL WIDGET -----------------------------------------------------
          Expanded(
            child: WindowMoveTarget(
              onDrop: (pos) => _onDrop(pos, leafPath),
              isActive: _movingLeaf != null && _movingLeaf != leafNode.id,
              // TODO figure out a way to expose drop target
              target: Container(
                color: const Color(0xFFFF2222),
              ),
              child: widget.buildLeaf(leafPath, leafNode.activeTabIndex),
            ),
          ),
        ],
      );
    }

    /// NON TAB LEAF
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.leafBarHeight,
          child: WindowMoveHandle(
            dragIndicator: widget.buildMoveDragIndicator?.call(leafPath, null) ?? _defaultMoveDragIndicator,
            child: widget.buildLeafBar?.call(leafPath) ?? _buildDefaultLeafBar(leafNode.id),
            onMoveEnd: _onMoveEnd,
            onMoveStart: () => _onMoveStart(leafNode.id, leafPath, null),
            onMoveUpdate: (_) {},
          ),
        ),
        // ACTUAL WIDGET -----------------------------------------------------
        Expanded(
          child: WindowMoveTarget(
            onDrop: (pos) => _onDrop(pos, leafPath),
            isActive: _movingLeaf != null && _movingLeaf != leafNode.id,
            // TODO figure out a way to expose drop target
            target: Container(
              color: const Color(0xFFFF2222),
            ),
            child: widget.buildLeaf(leafPath, null),
          ),
        ),
      ],
    );
  }

  void _setActiveTab(MondrianTreePath leafPath, int i) {
    return widget.onUpdateTree(
      widget.tree.updatePath(leafPath, (_tabLeaf) {
        _tabLeaf as MondrianTreeTabLeaf;
        return _tabLeaf.copyWith(activeTabIndex: i);
      }),
    );
  }

  // =========================================================================== RESOLVE HELPERS
  static const Widget _defaultMoveDragIndicator = SizedBox(
    height: 100,
    width: 100,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0x88FFFFFF),
      ),
    ),
  );

  Widget _buildDefaultTabIndicator(MondrianTreeLeafId id, bool isActive) => Container(
        height: widget.tabBarHeight,
        width: widget.tabBarMinOverhangWidth, // use the same width
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFFFFF)),
          color: isActive ? const Color(0xFF666666) : const Color(0xFF000000),
        ),
        child: AutoSizeText(text: id.value),
      );

  Widget _buildDefaultTabOverhang() => Container(
        height: widget.tabBarHeight,
        width: widget.tabBarMinOverhangWidth, // use the same width
        color: const Color(0xFF000000),
      );

  Widget _buildDefaultLeafBar(MondrianTreeLeafId id) => Container(
        height: widget.leafBarHeight,
        color: const Color(0xFF000000),
        child: AutoSizeText(text: id.value),
      );
}

/// ============================================================================
/// ============================================================================
/// ============================================================================
/// ============================================================================
/// ============================================================================
/// ============================================================================
///
///
///
/// LAYOUT + RESIZE
///
///
///
/// ============================================================================
/// ============================================================================
/// ============================================================================
/// ============================================================================
/// ============================================================================
/// ============================================================================

/// ============================================================================ TYPEDEF

/// {@template _LeafResolver}
/// Builds the actual widget represented by the [leafNode] under [leafPath].
/// The parents [axis] is also returned, since it is needed to contextualize potential drops of other leafs onto this one.
/// {@endtemplate}
typedef _LeafResolver = Widget Function(
  MondrianTreeLeaf leafNode,
  MondrianTreePath leafPath,
  MondrianAxis axis,
);

/// {@template _LeafResizeCallback}
/// Called when a the seperator between two nodes is used to resize the nodes next to it.
///
/// - The [pathToParent] points to the parent branch in which the children have been resized.
/// - The [index] points to the node before the seperator inside the list of children pointerd to by [pathToParent].
/// - The [newFraction] also points to the node before the seperator, the difference must be subtracted from the node after.
/// {@endtemplate}
typedef _LeafResizeCallback = void Function(
  MondrianTreePath pathToParent,
  double newFraction,
  int index,
);

/// ============================================================================ WIDGET - TREE ENTRY

/// Entry point to convert the [MondrianTree] into [Column]s and [Row]s.
class _MondrianLayoutAndResize extends StatelessWidget {
  const _MondrianLayoutAndResize({
    Key? key,
    required this.tree,
    required this.onResize,
    required this.resolveLeafToWidget,
    required this.resizeDraggerColor,
    required this.resizeDraggerWidth,
  }) : super(key: key);

  // =========================================================================== FIELDS

  /// {@macro mondrian-tree-param}
  final MondrianTree tree;

  /// {@macro _LeafResizeCallback}
  final _LeafResizeCallback onResize;

  /// Resolve leafs to the widgets representing them.
  final _LeafResolver resolveLeafToWidget;

  /// The width of the resize drag seperators
  final double resizeDraggerWidth;

  /// The color of the resize drag seperators
  final Color resizeDraggerColor;

  // =========================================================================== BUILD

  @override
  Widget build(BuildContext context) {
    return _MondrianNode(
      node: tree.rootNode,
      axis: tree.rootAxis,
      onResize: onResize,
      resolveLeafToWidget: resolveLeafToWidget,
      path: const [],
      resizeDraggerColor: resizeDraggerColor,
      resizeDraggerWidth: resizeDraggerWidth,
    );
  }
}

/// ============================================================================ WIDGET - TREE NODE

/// Manages the conversion of
/// - [MondrianTreeBranch]es into [Column]s and [Row]s.
/// - [MondrianTreeLeaf]s into user defined [Widget]s.
///
/// Also handles resizing via seperators between the children of branches.
class _MondrianNode extends StatelessWidget {
  // TODO: minimum node size can be broken by application window resize
  // § entire window is resized to be smaller
  //   => effective size for same fraction will be reduced
  //     => nodes already at minimum will get smaller than minimum
  // ! VSCODE solves this issue by just enabeling scrolling
  // ° instead of just using flex, using layoutbuilder and manually setting sizes could work, that way scrollable could also be used
  static const _minNodeExtend = 40;

  const _MondrianNode({
    Key? key,
    required this.node,
    required this.axis,
    required this.onResize,
    required this.resolveLeafToWidget,
    required this.path,
    required this.resizeDraggerColor,
    required this.resizeDraggerWidth,
  }) : super(key: key);

  // =========================================================================== FIELDS

  /// The current node of the tree beeing build.
  /// Can either be a leaf or a branch.
  final MondrianNodeAbst node;

  /// The axis of the parent branch.
  /// Determines whether the next branch will layout its children as [Row] or [Column].
  final MondrianAxis axis;

  /// {@macro _LeafResizeCallback}
  final _LeafResizeCallback onResize;

  /// {@macro _LeafResolver}
  final _LeafResolver resolveLeafToWidget;

  /// The path in the tree that lead to this node.
  /// Constructed as the widget-tree for the mondrian-tree is build recursively.
  final MondrianTreePath path;

  /// The width of the resize drag seperators
  final double resizeDraggerWidth;

  /// The color of the resize drag seperators
  final Color resizeDraggerColor;

  // =========================================================================== RESIZE

  // TODO: resizing with double can result in precision errors
  // might even consider using only integers instead of doubles
  // like e.g a step count of 100.000 would already equal the current 1.00000 precision
  // without any of the rounding issues
  // also note how flex requires int anyways, so there we already do exactly this
  void resizeOnSeperatorDrag(DragUpdateDetails d, BoxConstraints bc, int index) {
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

  // TODO: resize hit area should be larger than the visual area
  // might want to insert an overlay here to increase hit area on hover without having to visually increase the border
  // this is how vscode does it too
  Widget _buildResizeSeperator(int i, BoxConstraints constraints) => MouseRegion(
        cursor: axis.isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          onVerticalDragUpdate: axis.isVertical ? (d) => resizeOnSeperatorDrag(d, constraints, i) : null,
          onHorizontalDragUpdate: axis.isHorizontal ? (d) => resizeOnSeperatorDrag(d, constraints, i) : null,
          child: Container(
            color: resizeDraggerColor,
            width: axis.isHorizontal ? resizeDraggerWidth : null,
            height: axis.isVertical ? resizeDraggerWidth : null,
          ),
        ),
      );

  // =========================================================================== BUILD
  @override
  Widget build(BuildContext context) {
    /// : BUILD A USER CONTROLLED WIDGET IF WE REACH A LEAF
    if (node is MondrianTreeLeaf) {
      /// . Either an actual leaf or a tab group
      return resolveLeafToWidget(node as MondrianTreeLeaf, path, axis.previous);
    }

    /// : OTHERWISE BUILD A ROW OR COLUMN FOR THE BRANCH & RECURSE ON ALL CHILDREN
    final nextAxis = axis.next;

    final children = (node as MondrianTreeBranch).children;
    final childrenLength = children.length;
    final lastIndex = childrenLength - 1;

    return MondrianBranchDebugOverlay(
      path: path,
      child: LayoutBuilder(
        builder: (context, constraints) => RowOrColumn(
          axis: axis.asFlutterAxis,
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
                  resizeDraggerColor: resizeDraggerColor,
                  resizeDraggerWidth: resizeDraggerWidth,
                ),
              ),
              if (i != lastIndex) ...[
                _buildResizeSeperator(i, constraints),
              ],
            ]
          ],
        ),
      ),
    );
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
