import 'package:flutter_test/flutter_test.dart';

import 'package:mondrian/mondrian.dart';

void main() {
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
