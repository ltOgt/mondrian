import 'package:flutter_test/flutter_test.dart';

import 'package:mondrian/mondrian.dart';

void main() {
  group("Encode Decode", () {
    test("Tree without tabs", () {
      const tree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .7,
              children: [
                MondrianTreeLeaf(fraction: .7, id: MondrianTreeLeafId("Big top left")),
                MondrianTreeBranch(
                  fraction: .3,
                  children: [
                    MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Medium Top Right")),
                    MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Small Mid Right")),
                  ],
                ),
              ],
            ),
            MondrianTreeBranch(
              fraction: .3,
              children: [
                MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Left")),
                MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Mid")),
                MondrianTreeLeaf(fraction: .4, id: MondrianTreeLeafId("Bottom Right")),
              ],
            )
          ],
        ),
      );

      // Note that doubles are encoded as strings, this is by design (since i like to use SmallRead, which encodes everything as Strings)
      final Map expectedEncoded = {
        "rootAxis": "vertical",
        "rootNode": {
          "type": "branch",
          "data": {
            "fraction": "1.0",
            "children": [
              {
                "type": "branch",
                "data": {
                  "fraction": "0.7",
                  "children": [
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.7", "id": "Big top left"}
                    },
                    {
                      "type": "branch",
                      "data": {
                        "fraction": "0.3",
                        "children": [
                          {
                            "type": "leaf",
                            "data": {"fraction": "0.6", "id": "Medium Top Right"}
                          },
                          {
                            "type": "leaf",
                            "data": {"fraction": "0.6", "id": "Small Mid Right"}
                          }
                        ]
                      }
                    }
                  ]
                }
              },
              {
                "type": "branch",
                "data": {
                  "fraction": "0.3",
                  "children": [
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.3", "id": "Bottom Left"}
                    },
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.3", "id": "Bottom Mid"}
                    },
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.4", "id": "Bottom Right"}
                    }
                  ]
                }
              }
            ]
          }
        },
      };

      final encoded = tree.encode();

      expect(encoded, equals(expectedEncoded));

      final decoded = MondrianTree.decode(encoded);

      expect(decoded, equals(tree));
    });

    test("Tree with tabs", () {
      // NOTE: because of transient ids, we can only compare the representation
      // ____  the tree wont be exactly equal after encode=>decode since the transient ids will differ

      final tree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            const MondrianTreeBranch(
              fraction: .7,
              children: [
                MondrianTreeLeaf(fraction: .7, id: MondrianTreeLeafId("Big top left")),
                MondrianTreeBranch(
                  fraction: .3,
                  children: [
                    MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Medium Top Right")),
                    MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Small Mid Right")),
                  ],
                ),
              ],
            ),
            MondrianTreeBranch(
              fraction: .3,
              children: [
                const MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Left")),
                const MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Mid")),
                MondrianTreeTabLeaf(
                  fraction: .4,
                  activeTabIndex: 0,
                  tabs: [
                    const MondrianTreeLeafId("Tab 1"),
                    const MondrianTreeLeafId("Tab 2"),
                  ],
                ),
              ],
            )
          ],
        ),
      );

      // Note that doubles are encoded as strings, this is by design (since i like to use SmallRead, which encodes everything as Strings)
      final Map expectedEncoded = {
        "rootAxis": "vertical",
        "rootNode": {
          "type": "branch",
          "data": {
            "fraction": "1.0",
            "children": [
              {
                "type": "branch",
                "data": {
                  "fraction": "0.7",
                  "children": [
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.7", "id": "Big top left"}
                    },
                    {
                      "type": "branch",
                      "data": {
                        "fraction": "0.3",
                        "children": [
                          {
                            "type": "leaf",
                            "data": {"fraction": "0.6", "id": "Medium Top Right"}
                          },
                          {
                            "type": "leaf",
                            "data": {"fraction": "0.6", "id": "Small Mid Right"}
                          }
                        ]
                      }
                    }
                  ]
                }
              },
              {
                "type": "branch",
                "data": {
                  "fraction": "0.3",
                  "children": [
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.3", "id": "Bottom Left"}
                    },
                    {
                      "type": "leaf",
                      "data": {"fraction": "0.3", "id": "Bottom Mid"}
                    },
                    {
                      "type": "tabLeaf",
                      "data": {
                        "fraction": "0.4",
                        "activeTabIndex": "0",
                        "tabs": ["Tab 1", "Tab 2"]
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
      };

      final encoded = tree.encode();

      expect(encoded, equals(expectedEncoded));
    });

    test("Decode Encode Tab", () {
      final tab = MondrianTreeTabLeaf(
        fraction: .4,
        activeTabIndex: 0,
        tabs: [
          const MondrianTreeLeafId("Tab 1"),
          const MondrianTreeLeafId("Tab 2"),
        ],
      );

      final tabEncoded = MondrianMarshalSvc.encTabLeaf(tab);
      final tabDecoded = MondrianMarshalSvc.decTabLeaf(tabEncoded);

      expect(tab.fraction, equals(tabDecoded.fraction));
      expect(tab.activeTabIndex, equals(tabDecoded.activeTabIndex));
      expect(tab.tabs, equals(tabDecoded.tabs));
      expect(tab.id != tabDecoded.id, isTrue);
    });
  });

  group("Path from Id", () {
    const wantedId = MondrianTreeLeafId("Leaf 5");
    const nonExistentId = MondrianTreeLeafId("Leaf Doe Not Exist");
    const wantedTabId = MondrianTreeLeafId("Tab Id 2");

    final tree = MondrianTree(
      rootAxis: MondrianAxis.vertical,
      rootNode: MondrianTreeBranch(
        fraction: 1,
        children: [
          const MondrianTreeLeaf(fraction: .1, id: MondrianTreeLeafId("Leaf 0")),
          const MondrianTreeBranch(
            fraction: .4,
            children: [
              MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 1")),
              MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 2")),
            ],
          ),
          MondrianTreeBranch(
            fraction: .5,
            children: [
              const MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 3")),
              MondrianTreeBranch(
                fraction: .5,
                children: [
                  const MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 4")),
                  const MondrianTreeLeaf(fraction: .3, id: wantedId),
                  MondrianTreeTabLeaf(
                    fraction: .2,
                    tabs: [
                      const MondrianTreeLeafId("Tab Id 1"),
                      wantedTabId,
                    ],
                    activeTabIndex: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    test("Extract Leaf", () {
      final wantedPath = tree.pathFromId(wantedId);

      expect(wantedPath, isNotNull);
      wantedPath!;
      expect(wantedPath.path, equals([2, 1, 1]));
      expect(wantedPath.tabIndexIfAny, isNull);
    });
    test("Extract Null for non existant", () {
      final nonPath = tree.pathFromId(nonExistentId);
      expect(nonPath, isNull);
    });
    test("Extract Tab", () {
      final wantedTabPath = tree.pathFromId(wantedTabId);

      expect(wantedTabPath, isNotNull);
      wantedTabPath!;
      expect(wantedTabPath.path, equals([2, 1, 2]));
      expect(wantedTabPath.tabIndexIfAny, equals(1));
    });
  });

  // TODO need more test cases for
  // - move tab out of tab leaf into higher branch
  // - move tab out of tab leaf into same branch
  // - move tab out of tab leaf that is root
  // - probably more
  // ( these have been tested interactively, but should have automatic tests for these cases )
  group("Move Leaf", () {
    test("Axis switch on root move on other axis", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 1")),
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 2")),
          ],
        ),
      );

      const expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 2")),
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 1")),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1],
        targetPath: [0],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.left,
      );

      expect(actualTreeAfterUpdate, equals(expectedTreeAfterUpdate));
    });

    test("root change on merge to tab group", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 1")),
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Leaf 2")),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      final expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 1,
          tabs: const [
            MondrianTreeLeafId("Leaf 1"),
            MondrianTreeLeafId("Leaf 2"),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1],
        targetPath: [0],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.center,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("tab group into tab group", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeTabLeaf(
              fraction: .5,
              activeTabIndex: 1,
              tabs: const [
                MondrianTreeLeafId("Tab A-1"),
                MondrianTreeLeafId("Tab A-2"),
                MondrianTreeLeafId("Tab A-3"),
              ],
            ),
            MondrianTreeTabLeaf(
              fraction: .5,
              activeTabIndex: 1,
              tabs: const [
                MondrianTreeLeafId("Tab B-1"),
                MondrianTreeLeafId("Tab B-2"),
                MondrianTreeLeafId("Tab B-3"),
              ],
            ),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      final expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 3,
          tabs: const [
            MondrianTreeLeafId("Tab A-1"),
            MondrianTreeLeafId("Tab A-2"),
            MondrianTreeLeafId("Tab B-1"),
            MondrianTreeLeafId("Tab B-2"),
            MondrianTreeLeafId("Tab B-3"),
            MondrianTreeLeafId("Tab A-3"),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1],
        targetPath: [0],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.center,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("leaf into leaf to form tab group", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Tab A-1")),
            MondrianTreeLeaf(fraction: .5, id: MondrianTreeLeafId("Tab A-2")),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      final expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 1,
          tabs: const [
            MondrianTreeLeafId("Tab A-1"),
            MondrianTreeLeafId("Tab A-2"),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1],
        targetPath: [0],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.center,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("tab before its tabgroup in same branch", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeTabLeaf(
              fraction: .5,
              activeTabIndex: 1,
              tabs: const [
                MondrianTreeLeafId("Tab A-1"),
                MondrianTreeLeafId("Tab A-2"),
                MondrianTreeLeafId("Tab A-3"),
              ],
            ),
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      final expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Tab A-2"), fraction: .25),
            MondrianTreeTabLeaf(
              fraction: .25,
              activeTabIndex: 0,
              tabs: const [
                MondrianTreeLeafId("Tab A-1"),
                MondrianTreeLeafId("Tab A-3"),
              ],
            ),
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [0],
        targetPath: [0],
        tabIndexIfAny: 1,
        targetSide: MondrianLeafMoveTargetDropPosition.left,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("tab after its tabgroup in same branch", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeTabLeaf(
              fraction: .5,
              activeTabIndex: 1,
              tabs: const [
                MondrianTreeLeafId("Tab A-1"),
                MondrianTreeLeafId("Tab A-2"),
                MondrianTreeLeafId("Tab A-3"),
              ],
            ),
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      final expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeTabLeaf(
              fraction: .25,
              activeTabIndex: 0,
              tabs: const [
                MondrianTreeLeafId("Tab A-1"),
                MondrianTreeLeafId("Tab A-3"),
              ],
            ),
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Tab A-2"), fraction: .25),
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [0],
        targetPath: [0],
        tabIndexIfAny: 1,
        targetSide: MondrianLeafMoveTargetDropPosition.right,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("tab before its tabgroup in same branch with no remaining tabs causes tab group to dissolve", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeTabLeaf(
              fraction: .5,
              activeTabIndex: 1,
              tabs: const [
                MondrianTreeLeafId("Tab A-1"),
                MondrianTreeLeafId("Tab A-2"),
              ],
            ),
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      const expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Tab A-2"), fraction: .25),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Tab A-1"), fraction: .25),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [0],
        targetPath: [0],
        tabIndexIfAny: 1,
        targetSide: MondrianLeafMoveTargetDropPosition.left,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("leaf from other branch into branch of other leaf", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .7,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
              ],
            ),
            MondrianTreeBranch(
              fraction: .3,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 3"), fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 4"), fraction: .5),
              ],
            ),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      const expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .7,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 3"), fraction: .25),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .25),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
              ],
            ),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 4"), fraction: .3),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1, 0],
        targetPath: [0, 0],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.left,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("source from branch-a into target in branch-b to create new branch-c inside branch-b ", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .7,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
              ],
            ),
            MondrianTreeBranch(
              fraction: .3,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 3"), fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 4"), fraction: .5),
              ],
            ),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      const expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .7,
              children: [
                MondrianTreeBranch(
                  fraction: .5,
                  children: [
                    MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 3"), fraction: .5),
                    MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
                  ],
                ),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
              ],
            ),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 4"), fraction: .3),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1, 0],
        targetPath: [0, 0],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.top,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("ROOT - tab before its tabgroup in same branch with no remaining tabs causes tab group to dissolve", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 0,
          tabs: [
            const MondrianTreeLeafId("Tab A-1"),
            const MondrianTreeLeafId("Tab A-2"),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      const expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Tab A-2"), fraction: .5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Tab A-1"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [],
        targetPath: [],
        tabIndexIfAny: 1,
        targetSide: MondrianLeafMoveTargetDropPosition.left,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });

    test("moving leaf out of 2-group dissolves 2-group and merges last member with parent", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .6,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 1 Child 1"), fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 1 Child 2"), fraction: .5),
              ],
            ),
            MondrianTreeBranch(
              fraction: .4,
              children: [
                MondrianTreeBranch(
                  fraction: .7,
                  children: [
                    MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 2-1 Child 1"), fraction: .5),
                    MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 2-1 Child 2"), fraction: .5),
                  ],
                ),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 2 Child 2"), fraction: .3),
              ],
            ),
          ],
        ),
      );

      // TabLeaf can not be const because of internal generated id
      const expectedTreeAfterUpdate = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeBranch(
              fraction: .6,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 1 Child 1"), fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 1 Child 2"), fraction: .25),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 2-1 Child 2"), fraction: .25),
              ],
            ),
            MondrianTreeBranch(
              fraction: .4,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 2-1 Child 1"), fraction: .7),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Branch 2 Child 2"), fraction: .3),
              ],
            ),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.moveLeaf(
        sourcePath: [1, 0, 1],
        targetPath: [0, 1],
        tabIndexIfAny: null,
        targetSide: MondrianLeafMoveTargetDropPosition.right,
      );

      // need to compare encoded versions because the transient generated ids of the tab leafs obviously differ
      expect(actualTreeAfterUpdate.encode(), equals(expectedTreeAfterUpdate.encode()));
    });
  });

  group("Create Leaf", () {
    test("Next to leaf in same axis => add to parent branch", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
            MondrianTreeLeaf(id: newLeafId, fraction: .25),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .25),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.left,
        newLeafId: newLeafId,
        targetPathToLeaf: [1],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });
    test("Next to leaf in other axis => create new 2-branch in parent branch", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
            MondrianTreeBranch(
              fraction: .5,
              children: [
                MondrianTreeLeaf(id: newLeafId, fraction: .5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: .5),
              ],
            ),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.top,
        newLeafId: newLeafId,
        targetPathToLeaf: [1],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Next to root leaf in same axis => create root branch and add both", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeLeaf(
          id: MondrianTreeLeafId("Leaf 1"),
          fraction: 1,
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: newLeafId, fraction: .5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.left,
        newLeafId: newLeafId,
        targetPathToLeaf: [],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Next to root leaf in other axis => create root branch and add both & flip root axis", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeLeaf(
          id: MondrianTreeLeafId("Leaf 1"),
          fraction: 1,
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: newLeafId, fraction: .5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.top,
        newLeafId: newLeafId,
        targetPathToLeaf: [],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Inside tab group of existing tab group => add after activeIndex and increment index", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 0,
          tabs: [
            const MondrianTreeLeafId("Tab A-1"),
            const MondrianTreeLeafId("Tab A-2"),
          ],
        ),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 1,
          tabs: [
            const MondrianTreeLeafId("Tab A-1"),
            newLeafId,
            const MondrianTreeLeafId("Tab A-2"),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.center,
        newLeafId: newLeafId,
        targetPathToLeaf: [],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Inside tab group of leaf => turn leaf into tab group with target and source", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: 0.5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 2"), fraction: 0.5),
          ],
        ),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Leaf 1"), fraction: 0.5),
            MondrianTreeTabLeaf(
              fraction: .5,
              activeTabIndex: 1,
              tabs: [
                const MondrianTreeLeafId("Leaf 2"),
                newLeafId,
              ],
            ),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.center,
        newLeafId: newLeafId,
        targetPathToLeaf: [1],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("ROOT - Inside tab group of root leaf => turn leaf into tab group with target and source", () {
      const newLeafId = MondrianTreeLeafId("NEW ID");

      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeLeaf(
          id: MondrianTreeLeafId("ROOT LEAF"),
          fraction: 1,
        ),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 1,
          tabs: [
            const MondrianTreeLeafId("ROOT LEAF"),
            newLeafId,
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.createLeaf(
        targetSide: MondrianLeafMoveTargetDropPosition.center,
        newLeafId: newLeafId,
        targetPathToLeaf: [],
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });
  });

  group("Remove Leaf", () {
    test("Removing active tab from tab group decreases active tab if not zero", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(fraction: 1, children: [
          const MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
          MondrianTreeTabLeaf(
            fraction: .5,
            activeTabIndex: 1,
            tabs: [
              const MondrianTreeLeafId("Tab 1"),
              const MondrianTreeLeafId("Tab 2"),
              const MondrianTreeLeafId("Tab 3"),
            ],
          )
        ]),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(fraction: 1, children: [
          const MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
          MondrianTreeTabLeaf(
            fraction: .5,
            activeTabIndex: 0,
            tabs: [
              const MondrianTreeLeafId("Tab 1"),
              const MondrianTreeLeafId("Tab 3"),
            ],
          )
        ]),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [1],
        tabIndexIfAny: 1,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Removing active tab <zero> from tab group keeps active at zero", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(fraction: 1, children: [
          const MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
          MondrianTreeTabLeaf(
            fraction: .5,
            activeTabIndex: 0,
            tabs: [
              const MondrianTreeLeafId("Tab 1"),
              const MondrianTreeLeafId("Tab 2"),
              const MondrianTreeLeafId("Tab 3"),
            ],
          )
        ]),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(fraction: 1, children: [
          const MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
          MondrianTreeTabLeaf(
            fraction: .5,
            activeTabIndex: 0,
            tabs: [
              const MondrianTreeLeafId("Tab 2"),
              const MondrianTreeLeafId("Tab 3"),
            ],
          )
        ]),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [1],
        tabIndexIfAny: 0,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("ROOT - Removing active tab from tab group decreases active tab if not zero", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 1,
          tabs: [
            const MondrianTreeLeafId("Tab 1"),
            const MondrianTreeLeafId("Tab 2"),
            const MondrianTreeLeafId("Tab 3"),
          ],
        ),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 0,
          tabs: [
            const MondrianTreeLeafId("Tab 1"),
            const MondrianTreeLeafId("Tab 3"),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [],
        tabIndexIfAny: 1,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("ROOT - Removing active tab <zero> from tab group keeps active at zero", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 0,
          tabs: [
            const MondrianTreeLeafId("Tab 1"),
            const MondrianTreeLeafId("Tab 2"),
            const MondrianTreeLeafId("Tab 3"),
          ],
        ),
      );

      final expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 0,
          tabs: [
            const MondrianTreeLeafId("Tab 2"),
            const MondrianTreeLeafId("Tab 3"),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [],
        tabIndexIfAny: 0,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Removing second-last tab from tab group moves last tab into parent with tab-groups fraction", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            const MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
            MondrianTreeTabLeaf(
              fraction: .8,
              activeTabIndex: 0,
              tabs: [
                const MondrianTreeLeafId("Tab 1"),
                const MondrianTreeLeafId("Tab 2"),
              ],
            ),
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Tab 1"), fraction: .8),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [1],
        tabIndexIfAny: 1,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Removing child from branch adds its fraction to the remaining members", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 2"), fraction: .2),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 3"), fraction: .6),
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .5),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 2"), fraction: .5),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [2],
        tabIndexIfAny: null,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("Removing second-last child from branch moves last child into parent with branches fraction", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
            MondrianTreeBranch(
              fraction: .8,
              children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Child 2"), fraction: .4),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Child 3"), fraction: .6),
              ],
            )
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 1"), fraction: .2),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 3"), fraction: .8),
          ],
        ),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [1, 0],
        tabIndexIfAny: null,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("ROOT - Removing second-last child from root-branch sets last child as root and flips root orientation", () {
      const initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeBranch(
          fraction: 1,
          children: [
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 2"), fraction: .4),
            MondrianTreeLeaf(id: MondrianTreeLeafId("Child 3"), fraction: .6),
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.vertical,
        rootNode: MondrianTreeLeaf(id: MondrianTreeLeafId("Child 3"), fraction: 1),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [0],
        tabIndexIfAny: null,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });

    test("ROOT - Removing second-last tab from tab group moves last tab into parent with tab-groups fraction", () {
      final initialTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeTabLeaf(
          fraction: 1,
          activeTabIndex: 0,
          tabs: [
            const MondrianTreeLeafId("Tab 1"),
            const MondrianTreeLeafId("Tab 2"),
          ],
        ),
      );

      const expectedTree = MondrianTree(
        rootAxis: MondrianAxis.horizontal,
        rootNode: MondrianTreeLeaf(
          id: MondrianTreeLeafId("Tab 1"),
          fraction: 1,
        ),
      );

      final actualTreeAfterUpdate = initialTree.deleteLeaf(
        sourcePathToLeaf: [],
        tabIndexIfAny: 1,
      );

      expect(actualTreeAfterUpdate.encode(), equals(expectedTree.encode()));
    });
  });

  // TODO refactor, this is pretty much just a "resize" test from start of development
  test('Update Tree', () {
    const initialTree = MondrianTree(
      rootAxis: MondrianAxis.vertical,
      rootNode: MondrianTreeBranch(
        fraction: 1,
        children: [
          MondrianTreeBranch(
            fraction: .7,
            children: [
              MondrianTreeLeaf(fraction: .7, id: MondrianTreeLeafId("Big top left")),
              MondrianTreeBranch(
                fraction: .3,
                children: [
                  MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Medium Top Right")),
                  MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Small Mid Right")),
                ],
              ),
            ],
          ),
          MondrianTreeBranch(
            fraction: .3,
            children: [
              MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Left")),
              MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Mid")),
              MondrianTreeLeaf(fraction: .4, id: MondrianTreeLeafId("Bottom Right")),
            ],
          )
        ],
      ),
    );

    const expectedTreeAfterUpdate = MondrianTree(
      rootAxis: MondrianAxis.vertical,
      rootNode: MondrianTreeBranch(
        fraction: 1,
        children: [
          MondrianTreeBranch(
            fraction: .7,
            children: [
              MondrianTreeLeaf(fraction: .7, id: MondrianTreeLeafId("Big top left")),
              MondrianTreeBranch(
                fraction: .3,
                children: [
                  MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Medium Top Right")),
                  MondrianTreeLeaf(fraction: .6, id: MondrianTreeLeafId("Small Mid Right")),
                ],
              ),
            ],
          ),
          MondrianTreeBranch(
            fraction: .3,
            children: [
              MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Left")),
              MondrianTreeLeaf(fraction: .3, id: MondrianTreeLeafId("Bottom Mid")),
              // ============================================================================== THIS IS NEW <
              MondrianTreeBranch(fraction: .4, children: [
                MondrianTreeLeaf(id: MondrianTreeLeafId("Bottom Right"), fraction: 0.5),
                MondrianTreeLeaf(id: MondrianTreeLeafId("Bottom Right"), fraction: 0.5)
              ]),
              // ============================================================================== THIS IS NEW >
            ],
          )
        ],
      ),
    );

    final actualTreeAfterUpdate = initialTree.updatePath(
        [1, 2],
        (node) => MondrianTreeBranch(fraction: node.fraction, children: [
              MondrianTreeLeaf(id: (node as MondrianTreeLeaf).id, fraction: .5),
              MondrianTreeLeaf(id: (node as MondrianTreeLeaf).id, fraction: .5)
            ]));

    expect(expectedTreeAfterUpdate, equals(actualTreeAfterUpdate));
  });
}
