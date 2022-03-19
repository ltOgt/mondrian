import 'package:flutter_test/flutter_test.dart';

import 'package:mondrian/mondrian.dart';

void main() {
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
