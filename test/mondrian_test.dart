import 'package:flutter_test/flutter_test.dart';

import 'package:mondrian/mondrian.dart';

void main() {
  test('Update Tree', () {
    const initialTree = MondrianTree(
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
