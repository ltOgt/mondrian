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

      expect(expectedTreeAfterUpdate, equals(actualTreeAfterUpdate));
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
        rootAxis: MondrianAxis.vertical,
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

      // TODO this currently fails because the generated ids of the tab leafs obviously differ
      //  need to add encode + decode and compare encoded representations (which wont include the generated ids)
      expect(expectedTreeAfterUpdate, equals(actualTreeAfterUpdate));
    });
  });
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
