//TODO maybe good idea to have top level lookup of Map<LeafId, TreePath> that has to be updated on moves
// + quick resolve if needed (no search necessary)
// - need to keep consistent, and probably build once on start up (small negative though)
// + can quickly check for containment
// _ => before adding unchecked duplicates

//TODO what about duplicate IDs ...
// ! its perfectly legal to have multiple windows with the same file open...
// ? maybe can use above idea of top level lookup as workaround
// _ : have _
// _ _ e Map<LeafId-Public,List<LeafId-Internal>>
// _ _ _ § "MyLeaf" => ["MyLeaf-<timestamp1>", "MyLeaf-<timestamp-2>"]
// _ _ _ : one unique ID to represent the object, one unique id each to represent the window
// _ _ e Map<LeafId-Internal, TreePath>
// _ _ _ : unique mapping to a single path
// _ _ _ ! THIS WOULD NEED TO BE UPDATED
// _ _ e Map<LeafId-Internal, LeafId-Public>
// _ _ _ : resolve back from internal to public to get the actual widget representing the object
// ** skipping this for now while implementing tabs, will come back to this after that

// Decided to not implement tabs in the core of mondrian, but instead use a normal leaf and bolt tabs into it
// this keeps the complexity in the core of the movement stuff simpler
//
// the main idea is that a tab has a leaf id that is not given to the user to be resolved,
// while the tab leaf holds a list of further leafs that are not placed directly inside the tree, but are given to the user to resolve them to widgets
//
// . tried tabs as special state of branch or special state of leaf before, but that resulted in problems
// _ -- special branch
// _ _ S could have branches inside tabs (might be cool, but also unecessary and confusing)
// _ _ S would need ability to move next to group (alternative is the above "move into tab and create branch in tab")
// _ _ S would need ability to move entire group (might be cool, but out of scope for now, since complicates: breaks many assumptions inside the move code)
// _ _ S ...
// _ -- special leaf
// _ _ S had a few reasons, but forgot most of them now, point is, would also make things more complicated

// ignore: slash_for_doc_comments
/**
 tabs = {
   // this would be a leaf id that is never resolved to a widget by the user of mondrian, just so that the tab window can be handled by the leaf logic on move and resize
   // => + no need to treat the special case of tabs in core of mondrian
   <leaf_id_of_a_tabbed_window> : {
     activeIndex: 0,
     tabs: [
       // these are still leaf ids that can be resolved to widgets
       // this is so that they can easily be placed inside the tree once they are removed from the 
       <leaf_id_of_a_tabbed_widget___not_currently_mounted_as_leaf_directly_in_the_tree>,
       ...
     ],
   },
 }
 tree = {
   axis: <axis>,
   root: {
     type: branch,
     fraction: 1,
     children: [
       ... more branches and regular leafs
       {
        type: leaf,
        fraction: <fraction>,
        id: <leaf_id_of_a_tabbed_window>,
        // S ? how to distinguish between user resolved leafs and tab leafs
        // -- might use a similar approach as in brunnr: prefix id with "pub/<id>" / "tab/<id>" for serialization {{ and later also "internal/..."}}
        // _ . at runtime these could simply be of other subtypes:
        // _ _ e PublicLeafId <: LeafIdAbst
        // _ _ e TabLeafId <: LeafIdAbst
        // _ _ {{ e and later InternalLeafId <: LeafIdAbst }}
        // -- could simply do a check before resolving through user
        // _ : (tabs.contains(id)) ? resolveTab(id) : resolveToWidget(id)
       },
     ],
   }
 }
 */

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';

// TODO extend WindowManagerLeafIdInternal instead once implemented
class WindowManagerTabLeafId extends WindowManagerLeafId {
  const WindowManagerTabLeafId(String value) : super(value);
}

/// A container for [WindowManagerLeafId]s which can be placed as its own [WindowManagerLeaf] insides [WindowManagerTree]
class TabbedWindow {
  final WindowManagerTabLeafId id;
  final List<WindowManagerLeafId> tabs;
  final int activeTabIndex;

  WindowManagerLeafId get activeTab => tabs[activeTabIndex];

  const TabbedWindow({
    required this.id,
    required this.tabs,
    required this.activeTabIndex,
  });
}

class MondrianWithTabs extends MondrianMoveable {
  const MondrianWithTabs({
    Key? key,
    required WindowManagerTree tree,
    required void Function(WindowManagerTree tree) onResizeDone,
    required void Function(WindowManagerTree tree) onMoveDone,
    required this.onTabSwitch,
    required this.tabs,
  }) : super(
          key: key,
          tree: tree,
          onResizeDone: onResizeDone,
          onMoveDone: onMoveDone,
        );

  final void Function(TabbedWindow tabContainer) onTabSwitch;

  // TODO would be nice to expose a single tree that contains the tabs as well... would need to duplicate all regular tree objects and parse that combined tree into the internal non-tab tree as well as a internal tab map
  final Map<WindowManagerTabLeafId, TabbedWindow> tabs;

  @override
  State<MondrianWithTabs> createState() => _MondrianWithTabsState();
}

class _MondrianWithTabsState<M extends MondrianWithTabs> extends MondrianMoveableState<M> {
  @override
  Widget resolveLeaf(leafId, leafPath, leafAxis) {
    if (leafId is WindowManagerTabLeafId) {
      final tabWindow = widget.tabs[leafId]!;

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
                for (int i = 0; i < tabWindow.tabs.length; i++) ...[
                  WindowMoveHandle(
                    dragIndicator: Container(
                      height: 100,
                      width: 100,
                      color: Colors.white.withAlpha(100),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        widget.onTabSwitch(TabbedWindow(
                          id: tabWindow.id,
                          tabs: tabWindow.tabs,
                          activeTabIndex: i,
                        ));
                      },
                      child: Container(
                        height: 20,
                        width: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueAccent),
                          color: (i == tabWindow.activeTabIndex) ? Colors.grey : Colors.black,
                        ),
                        child: AutoSizeText(text: tabWindow.tabs[i].value),
                      ),
                    ),
                    onMoveEnd: () {
                      movingId = null;
                      setState(() {});
                    },
                    onMoveStart: () {
                      movingId = tabWindow.tabs[i];
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
                      movingId = tabWindow.id;
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
              isActive: movingId != null && movingId != leafId && !tabWindow.tabs.contains(movingId),
              target: Container(
                color: Colors.red,
              ),
              child: Center(
                child: AutoSizeText(
                  text: tabWindow.activeTab.value,
                ), // + " ${(tree.extractPath(path) as WindowManagerLeaf).fraction}"),
              ),
            ),
          ),
        ],
      );
    }
    return super.resolveLeaf(leafId, leafPath, leafAxis);
  }
}
