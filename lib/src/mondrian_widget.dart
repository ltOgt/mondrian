import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';
import 'package:mondrian/src/debug.dart';

// TODO need to add "can move" flag; either into the tree, via a callback or via a set of ids

// TODO need to disable move targets iff too small already

// TODO need to enable scrolling if too little space for all widgets to fit with their min width

// TODO still need to add the experiments/tabbed_window.dart thoughts about multiple leafs for the same id
//  currently, using the same id twice will remove one on drop next to the other (as it should), but sets the fraction to zero for some reason.
//  instead of adding additional concepts on top, we might just want to treat this as a bug and allow multiple same ids?

// TODO consider adding "bool canMoveContent" by which the content would be wrapped with a move handle; this could be toggled on and off from user

// TODO still need to implement reordering of tabs
//  ~ wrap tab with target that exposes + intercepts only "left/right"
//  ~ active if tabs.contains(movingLeaf) && movingLeaf != thisTab

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
  MondrianTreeLeafId tabId,
  bool isActive,
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
  MondrianTreePathWithTabIndexIfAny leafPath,
  MondrianTreeLeafId leafNodeId,
);

/// {@template LeafBarBuilder}
/// Builds the bar belonging to the [MondrianTreeLeaf] under [leafPath].
///
/// The leaf will be draggable on the widget returned by this function.
/// {@endtemplate}
typedef LeafBarBuilder = Widget Function(
  MondrianTreePath leafPath,
  MondrianTreeLeafId leafId,
);

/// {@template DropTargetMetaDataWrapper}
/// Used inside [DropTargetWidgetBuilder] to wrap a user supplied widget with the internally required metadata.
/// {@endtemplate}
typedef DropTargetMetaDataWrapper = Widget Function(
  MondrianLeafMoveTargetDropPosition position,
  Widget child,
);

/// {@template DropTargetWidgetBuilder}
/// Builder for the overlay used to drop moving leafs onto other leaf targets.
///
/// - [wrap]:
///   {@macro DropTargetMetaDataWrapper}
/// {@endtemplate}
typedef DropTargetWidgetBuilder = Widget Function(DropTargetMetaDataWrapper wrap);

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
    this.buildTargetDropIndicators,
    this.onMoveLeafStart,
    this.onMoveLeafUpdate,
    this.onMoveLeafEnd,
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

  /// Callback for when the [tree] was requested to be changed by the user.
  /// The same current [tree] will be exposed via [oldTree] inside the callback.
  ///
  /// This widget `DOES NOT` actually update [tree], opting to instead give full controll to the caller.
  /// See [MondrianTree.applyUpdateDetails]
  ///
  /// Depending on the kind of the update, different [TreeUpdateDetailsAbst] are returned:
  /// - moving of a leaf
  ///   - see [TreeUpdateDetailsMove]
  /// - resizing of two neighbouring nodes (leafs/branches)
  ///   - see [TreeUpdateDetailsResize]
  /// - changing focus inside a tab leaf
  ///   - see [TreeUpdateDetailsTabFocus]
  final void Function(MondrianTree oldTree, TreeUpdateDetailsAbst updateDetails) onUpdateTree;

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

  /// {@macro DropTargetWidgetBuilder}
  ///
  /// Also see [MondrianWidget.defaultBuildTargetDropIndicatorsGenerator] for simple adjustment of the default indicator overlay
  final DropTargetWidgetBuilder? buildTargetDropIndicators;

  final void Function(MondrianTreePathWithTabIndexIfAny leafPath)? onMoveLeafStart;
  final void Function(MondrianTreePathWithTabIndexIfAny leafPath, DragUpdateDetails dragUpdateDetails)?
      onMoveLeafUpdate;
  final void Function(MondrianTreePathWithTabIndexIfAny leafPath)? onMoveLeafEnd;

  @override
  State<MondrianWidget> createState() => _MondrianWidgetState();

  /// Execute this function with an optional [simpleDropTarget] to generate the default [buildTargetDropIndicators].
  static DropTargetWidgetBuilder defaultBuildTargetDropIndicatorsGenerator({Widget? simpleDropTarget}) {
    const Widget defaultSimpleDropTarget = DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xAAFFFFFF),
      ),
    );

    Widget _defaultBuildTargetDropIndicators(DropTargetMetaDataWrapper wrap) {
      const _targetLarge = 30.0;
      const _targetSmall = 20.0;
      const _targetGap = SizedBox.square(dimension: 5.0);

      final Widget _targetIndicator = simpleDropTarget ?? defaultSimpleDropTarget;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TOP
            wrap(
              MondrianLeafMoveTargetDropPosition.top,
              SizedBox(
                width: _targetLarge,
                height: _targetSmall,
                child: _targetIndicator,
              ),
            ),
            _targetGap,
            // LEFT CENTER RIGHT
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LEFT
                wrap(
                  MondrianLeafMoveTargetDropPosition.left,
                  SizedBox(
                    width: _targetSmall,
                    height: _targetLarge,
                    child: _targetIndicator,
                  ),
                ),
                _targetGap,
                // CENTER
                wrap(
                  MondrianLeafMoveTargetDropPosition.center,
                  SizedBox(
                    width: _targetLarge,
                    height: _targetLarge,
                    child: _targetIndicator,
                  ),
                ),
                _targetGap,
                // RIGHT
                wrap(
                  MondrianLeafMoveTargetDropPosition.right,
                  SizedBox(
                    width: _targetSmall,
                    height: _targetLarge,
                    child: _targetIndicator,
                  ),
                ),
              ],
            ),
            _targetGap,
            // BOTTOM
            wrap(
              MondrianLeafMoveTargetDropPosition.bottom,
              SizedBox(
                width: _targetLarge,
                height: _targetSmall,
                child: _targetIndicator,
              ),
            ),
          ],
        ),
      );
    }

    return _defaultBuildTargetDropIndicators;
  }
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

  // =========================================================================== RESIZE

  // =========================================================================== BUILD

  @override
  Widget build(BuildContext context) {
    return _MondrianLayoutAndResize(
      tree: widget.tree,
      onResize: (resizeDetails) => widget.onUpdateTree(widget.tree, resizeDetails),
      resolveLeafToWidget: _resolveLeafToWidget,
      resizeDraggerColor: widget.resizeDraggerColor,
      resizeDraggerWidth: widget.resizeDraggerWidth,
    );
  }

  void _onMoveStart(MondrianTreeLeafId leafId, MondrianTreePath leafPath, int? tabIndex) {
    _movingLeaf = leafId;
    setState(() {});
  }

  void _onMoveEnd() {
    _movingLeaf = null;
    setState(() {});
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
                      MondrianLeafMoveHandle(
                        leafPathOfMoving: MondrianTreePathWithTabIndexIfAny(
                          path: leafPath,
                          tabIndexIfAny: i,
                        ),
                        dragIndicator: widget.buildMoveDragIndicator?.call(leafPath, i) ?? _defaultMoveDragIndicator,
                        child: GestureDetector(
                          onTap: () {
                            if (i != tabLeaf.activeTabIndex) {
                              widget.onUpdateTree(
                                widget.tree,
                                TreeUpdateDetailsTabFocus(pathToTabLeaf: leafPath, newActiveIndex: i),
                              );
                            }
                          },
                          child: widget.buildTabIndicator?.call(
                                leafPath, // path to tab group
                                i, // tab index
                                tabLeaf.tabs[i], // tab id
                                i == tabLeaf.activeTabIndex, // isActive
                              ) ??
                              _buildDefaultTabIndicator(
                                tabLeaf.tabs[i],
                                (i == tabLeaf.activeTabIndex),
                              ),
                        ),
                        onMoveStart: () {
                          widget.onMoveLeafStart?.call(MondrianTreePathWithTabIndexIfAny(
                            path: leafPath,
                            tabIndexIfAny: i,
                          ));
                          _onMoveStart(leafNode.tabs[i], leafPath, i);
                          if (i != tabLeaf.activeTabIndex) {
                            widget.onUpdateTree(
                              widget.tree,
                              TreeUpdateDetailsTabFocus(pathToTabLeaf: leafPath, newActiveIndex: i),
                            );
                          }
                        },
                        onMoveUpdate: (d) {
                          widget.onMoveLeafUpdate?.call(
                              MondrianTreePathWithTabIndexIfAny(
                                path: leafPath,
                                tabIndexIfAny: i,
                              ),
                              d);
                        },
                        onMoveEnd: () {
                          widget.onMoveLeafEnd?.call(MondrianTreePathWithTabIndexIfAny(
                            path: leafPath,
                            tabIndexIfAny: i,
                          ));
                          _onMoveEnd();
                        },
                      ),
                    ],
                    // TAB OVERHANG --------------------------------------------
                    MondrianLeafMoveHandle(
                      leafPathOfMoving: MondrianTreePathWithTabIndexIfAny(
                        path: leafPath,
                        tabIndexIfAny: null,
                      ),
                      dragIndicator: widget.buildMoveDragIndicator?.call(leafPath, null) ?? _defaultMoveDragIndicator,
                      child: SizedBox(
                        width: max(
                          constraints.maxWidth - (tabLeaf.tabs.length * widget.tabIndicatorWidth),
                          widget.tabBarMinOverhangWidth,
                        ),
                        child: widget.buildTabBar?.call(leafPath) ?? _buildDefaultTabOverhang(),
                      ),
                      onMoveStart: () {
                        widget.onMoveLeafStart?.call(
                          MondrianTreePathWithTabIndexIfAny(
                            path: leafPath,
                            tabIndexIfAny: null,
                          ),
                        );
                        _onMoveStart(leafNode.id, leafPath, null);
                      },
                      onMoveUpdate: (d) {
                        widget.onMoveLeafUpdate?.call(
                          MondrianTreePathWithTabIndexIfAny(
                            path: leafPath,
                            tabIndexIfAny: null,
                          ),
                          d,
                        );
                      },
                      onMoveEnd: () {
                        widget.onMoveLeafEnd?.call(
                          MondrianTreePathWithTabIndexIfAny(
                            path: leafPath,
                            tabIndexIfAny: null,
                          ),
                        );
                        _onMoveEnd();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          // ACTUAL WIDGET -----------------------------------------------------
          Expanded(
            child: MondrianLeafMoveTarget(
              onDrop: (pos, sourceLeafPath) => widget.onUpdateTree(
                widget.tree,
                TreeUpdateDetailsMove(
                  targetLeafPath: leafPath,
                  targetDropPosition: pos,
                  sourceLeafPath: sourceLeafPath,
                ),
              ),
              isActive: _movingLeaf != null && _movingLeaf != leafNode.id,
              buildTargetPositionIndicators:
                  widget.buildTargetDropIndicators ?? MondrianWidget.defaultBuildTargetDropIndicatorsGenerator(),
              child: widget.buildLeaf(
                MondrianTreePathWithTabIndexIfAny(path: leafPath, tabIndexIfAny: leafNode.activeTabIndex),
                leafNode.activeTab,
              ),
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
          child: MondrianLeafMoveHandle(
            leafPathOfMoving: MondrianTreePathWithTabIndexIfAny(
              path: leafPath,
              tabIndexIfAny: null,
            ),
            dragIndicator: widget.buildMoveDragIndicator?.call(leafPath, null) ?? _defaultMoveDragIndicator,
            child: widget.buildLeafBar?.call(leafPath, leafNode.id) ?? _buildDefaultLeafBar(leafNode.id),
            onMoveStart: () {
              widget.onMoveLeafStart?.call(
                MondrianTreePathWithTabIndexIfAny(
                  path: leafPath,
                  tabIndexIfAny: null,
                ),
              );
              _onMoveStart(leafNode.id, leafPath, null);
            },
            onMoveUpdate: (d) {
              widget.onMoveLeafUpdate?.call(
                MondrianTreePathWithTabIndexIfAny(
                  path: leafPath,
                  tabIndexIfAny: null,
                ),
                d,
              );
            },
            onMoveEnd: () {
              widget.onMoveLeafEnd?.call(
                MondrianTreePathWithTabIndexIfAny(
                  path: leafPath,
                  tabIndexIfAny: null,
                ),
              );
              _onMoveEnd();
            },
          ),
        ),
        // ACTUAL WIDGET -----------------------------------------------------
        Expanded(
          child: MondrianLeafMoveTarget(
            onDrop: (pos, sourceLeafPath) => widget.onUpdateTree(
              widget.tree,
              TreeUpdateDetailsMove(
                targetLeafPath: leafPath,
                targetDropPosition: pos,
                sourceLeafPath: sourceLeafPath,
              ),
            ),
            isActive: _movingLeaf != null && _movingLeaf != leafNode.id,
            buildTargetPositionIndicators:
                widget.buildTargetDropIndicators ?? MondrianWidget.defaultBuildTargetDropIndicatorsGenerator(),
            child: widget.buildLeaf(
              MondrianTreePathWithTabIndexIfAny(
                path: leafPath,
                tabIndexIfAny: null,
              ),
              leafNode.id,
            ),
          ),
        ),
      ],
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
/// Callback for when the resize seperator between two nodes is dragged by the user to perform a resize.
/// {@endtemplate}
typedef _LeafResizeCallback = void Function(TreeUpdateDetailsResize resizeDetails);

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
  // ?? entire window is resized to be smaller
  //   => effective size for same fraction will be reduced
  //     => nodes already at minimum will get smaller than minimum
  // ! VSCODE solves this issue by just enabeling scrolling
  // ?? instead of just using flex, using layoutbuilder and manually setting sizes could work, that way scrollable could also be used
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
  final MondrianTreeNodeAbst node;

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

    onResize(TreeUpdateDetailsResize(
      pathToParent: path,
      newFraction: newFraction,
      nodeIndexInParent: index,
    ));
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
