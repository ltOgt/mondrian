class TabbedWindow {}

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