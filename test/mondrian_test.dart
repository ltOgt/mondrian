import 'package:flutter_test/flutter_test.dart';

import 'package:mondrian/mondrian.dart';

void main() {
  test('Update Tree', () {
    const initialTree = WindowManagerTree(
      rootNode: WindowManagerBranch(
        fraction: 1,
        children: [
          WindowManagerBranch(
            fraction: .7,
            children: [
              WindowManagerLeaf(fraction: .7, id: WindowManagerLeafId("Big top left")),
              WindowManagerBranch(
                fraction: .3,
                children: [
                  WindowManagerLeaf(fraction: .6, id: WindowManagerLeafId("Medium Top Right")),
                  WindowManagerLeaf(fraction: .6, id: WindowManagerLeafId("Small Mid Right")),
                ],
              ),
            ],
          ),
          WindowManagerBranch(
            fraction: .3,
            children: [
              WindowManagerLeaf(fraction: .3, id: WindowManagerLeafId("Bottom Left")),
              WindowManagerLeaf(fraction: .3, id: WindowManagerLeafId("Bottom Mid")),
              WindowManagerLeaf(fraction: .4, id: WindowManagerLeafId("Bottom Right")),
            ],
          )
        ],
      ),
    );

    const expectedTreeAfterUpdate = WindowManagerTree(
      rootNode: WindowManagerBranch(
        fraction: 1,
        children: [
          WindowManagerBranch(
            fraction: .7,
            children: [
              WindowManagerLeaf(fraction: .7, id: WindowManagerLeafId("Big top left")),
              WindowManagerBranch(
                fraction: .3,
                children: [
                  WindowManagerLeaf(fraction: .6, id: WindowManagerLeafId("Medium Top Right")),
                  WindowManagerLeaf(fraction: .6, id: WindowManagerLeafId("Small Mid Right")),
                ],
              ),
            ],
          ),
          WindowManagerBranch(
            fraction: .3,
            children: [
              WindowManagerLeaf(fraction: .3, id: WindowManagerLeafId("Bottom Left")),
              WindowManagerLeaf(fraction: .3, id: WindowManagerLeafId("Bottom Mid")),
              // ============================================================================== THIS IS NEW <
              WindowManagerBranch(fraction: .4, children: [
                WindowManagerLeaf(id: WindowManagerLeafId("Bottom Right"), fraction: 0.5),
                WindowManagerLeaf(id: WindowManagerLeafId("Bottom Right"), fraction: 0.5)
              ]),
              // ============================================================================== THIS IS NEW >
            ],
          )
        ],
      ),
    );

    final actualTreeAfterUpdate = initialTree.updatePath(
        [1, 2],
        (node) => WindowManagerBranch(fraction: node.fraction, children: [
              WindowManagerLeaf(id: (node as WindowManagerLeaf).id, fraction: .5),
              WindowManagerLeaf(id: (node as WindowManagerLeaf).id, fraction: .5)
            ]));

    expect(expectedTreeAfterUpdate, equals(actualTreeAfterUpdate));
  });
}
