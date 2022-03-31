import 'package:flutter/material.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';
// ignore: implementation_imports
import 'package:mondrian/src/debug.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var baseExampleTree = base_tree;
  bool isBaseExample = false;

  var mondrianExampleTree = mondrian_tree;
  final mondrianExampleColors = <MondrianTreeLeafId, Color>{
    const MondrianTreeLeafId("Red 1"): Colors.red,
    const MondrianTreeLeafId("Blue 1"): Colors.blue,
    const MondrianTreeLeafId("White 1"): Colors.white,
    const MondrianTreeLeafId("Yellow 1"): Colors.yellow,
    const MondrianTreeLeafId("White 2"): Colors.white,
    const MondrianTreeLeafId("White 3"): Colors.white,
    const MondrianTreeLeafId("Yellow 2"): Colors.yellow,
    const MondrianTreeLeafId("Blue 2"): Colors.blue,
    const MondrianTreeLeafId("Yellow 3"): Colors.yellow,
    const MondrianTreeLeafId("White 4"): Colors.white,
    const MondrianTreeLeafId("Red 2"): Colors.red,
    const MondrianTreeLeafId("White 5"): Colors.white,
  };

  MondrianTree get effectiveTree => isBaseExample ? baseExampleTree : mondrianExampleTree;
  set effectiveTree(MondrianTree tree) => isBaseExample ? baseExampleTree = tree : mondrianExampleTree = tree;

  void toggleDebugPaint() {
    MondrianDebugSingleton.instance.toggleBranchDebugPainting();
    setState(() {});
  }

  bool isLeafMoving = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mondrian Example',
      theme: ThemeData.dark(),
      home: Scaffold(
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // TODO actually still need to check if its a tab leaf and whether only a tab is moved
            if (isLeafMoving && effectiveTree.rootNode is! MondrianTreeLeaf)
              Container(
                width: 50,
                height: 50,
                color: Colors.red,
                child: MondrianLeafMoveTarget(
                  isActive: true,
                  buildTargetPositionIndicators: (wrap) {
                    return wrap(
                      MondrianLeafMoveTargetDropPosition.center,
                      const Center(
                        child: Icon(Icons.delete),
                      ),
                    );
                  },
                  onDrop: (pos, sourceLeafPath) {
                    if (isBaseExample) {
                      baseExampleTree = baseExampleTree.deleteLeaf(
                        sourcePathToLeaf: sourceLeafPath.path,
                        tabIndexIfAny: sourceLeafPath.tabIndexIfAny,
                      );
                    } else {
                      mondrianExampleTree = mondrianExampleTree.deleteLeaf(
                        sourcePathToLeaf: sourceLeafPath.path,
                        tabIndexIfAny: sourceLeafPath.tabIndexIfAny,
                      );
                    }
                    setState(() {});
                  },
                  child: const Center(
                    child: Icon(Icons.delete),
                  ),
                ),
              ),
            FloatingActionButton(
              onPressed: toggleDebugPaint,
              child: const Icon(Icons.brush),
            ),
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  isBaseExample = !isBaseExample;
                });
              },
              child: const Icon(Icons.grid_3x3),
            ),
          ],
        ),
        body: MondrianWidget(
          tree: isBaseExample ? baseExampleTree : mondrianExampleTree,
          resizeDraggerWidth: isBaseExample ? 2 : 10.0,
          resizeDraggerColor: isBaseExample ? const Color(0xFFAAAAFF) : Colors.black,
          onUpdateTree: (tree, details) {
            setState(() {
              if (isBaseExample) {
                baseExampleTree = tree.applyUpdateDetails(details);
              } else {
                mondrianExampleTree = tree.applyUpdateDetails(details);
              }
            });
          },
          buildLeafBar: isBaseExample
              ? null
              : (leafPath, leafId) {
                  return Container(
                      color: Colors.black.withAlpha(5),
                      child: Center(
                        child: AutoSizeText(
                          text: leafId.value,
                        ),
                      ));
                },
          buildTargetDropIndicators: MondrianWidget.defaultBuildTargetDropIndicatorsGenerator(
            simpleDropTarget: isBaseExample //
                ? const DecoratedBox(decoration: BoxDecoration(color: Color(0xAAFFFFFF)))
                : const DecoratedBox(decoration: BoxDecoration(color: Color(0xAA000000))),
          ),
          buildLeaf: (leafPath, leafId) {
            if (isBaseExample) {
              return Center(
                child: AutoSizeText(
                  text: leafId.value,
                ),
              );
            } else {
              return Container(
                color: mondrianExampleColors[leafId],
              );
            }
          },
          onMoveLeafStart: (path) {
            setState(() {
              isLeafMoving = true;
            });
          },
          onMoveLeafEnd: (path) {
            setState(() {
              isLeafMoving = false;
            });
          },
        ),
      ),
    );
  }
}

final base_tree = MondrianTree(
  rootAxis: MondrianAxis.vertical,
  rootNode: MondrianTreeBranch(
    fraction: 1,
    children: [
      MondrianTreeBranch(
        fraction: .7,
        children: [
          MondrianTreeTabLeaf(
            fraction: .7,
            tabs: const [
              MondrianTreeLeafId("Tab Child 1"),
              MondrianTreeLeafId("Tab Child 2"),
              MondrianTreeLeafId("Tab Child 3"),
            ],
            activeTabIndex: 0,
          ),
          const MondrianTreeBranch(
            fraction: .3,
            children: [
              MondrianTreeLeaf(
                fraction: .5,
                id: MondrianTreeLeafId("Medium Top Right"),
              ),
              MondrianTreeLeaf(
                fraction: .5,
                id: MondrianTreeLeafId("Small Mid Right"),
              ),
            ],
          ),
        ],
      ),
      const MondrianTreeBranch(
        fraction: .3,
        children: [
          MondrianTreeLeaf(
            fraction: .3,
            id: MondrianTreeLeafId("Bottom Left"),
          ),
          MondrianTreeLeaf(
            fraction: .3,
            id: MondrianTreeLeafId("Bottom Mid"),
          ),
          MondrianTreeLeaf(
            fraction: .4,
            id: MondrianTreeLeafId("Bottom Right"),
          ),
        ],
      )
    ],
  ),
);

const mondrian_tree = MondrianTree(
  rootAxis: MondrianAxis.horizontal,
  rootNode: MondrianTreeBranch(
    fraction: 1,
    children: [
      // red blue
      MondrianTreeBranch(
        fraction: 1 / 6,
        children: [
          MondrianTreeLeaf(fraction: 2 / 3, id: MondrianTreeLeafId("Red 1")),
          MondrianTreeLeaf(fraction: 1 / 3, id: MondrianTreeLeafId("Blue 1")),
        ],
      ),
      // rest
      MondrianTreeBranch(
        fraction: 5 / 6,
        children: [
          // White Yellow
          MondrianTreeBranch(
            fraction: 1 / 4,
            children: [
              MondrianTreeLeaf(fraction: 2 / 3, id: MondrianTreeLeafId("White 1")),
              MondrianTreeLeaf(fraction: 1 / 3, id: MondrianTreeLeafId("Yellow 1")),
            ],
          ),
          // Rest
          MondrianTreeBranch(
            fraction: 3 / 4,
            children: [
              // YELLOW BLUE PPPARENT
              MondrianTreeBranch(
                fraction: 1 / 2,
                children: [
                  // YELLOW BLUE PPARENT
                  MondrianTreeBranch(
                    fraction: 4 / 7,
                    children: [
                      // WHITE
                      MondrianTreeLeaf(fraction: 2 / 5, id: MondrianTreeLeafId("White 3")),
                      // YELLOW BLUE PARENT
                      MondrianTreeBranch(
                        fraction: 3 / 5,
                        children: [
                          // YELLOW
                          MondrianTreeLeaf(fraction: 2 / 3, id: MondrianTreeLeafId("Yellow 2")),
                          // BLUE
                          MondrianTreeLeaf(fraction: 1 / 3, id: MondrianTreeLeafId("Blue 2")),
                        ],
                      ),
                    ],
                  ),
                  // WHITE
                  MondrianTreeLeaf(fraction: 3 / 7, id: MondrianTreeLeafId("White 2")),
                ],
              ),
              // RED YELLOW ANCESTOR
              MondrianTreeBranch(
                fraction: 1 / 2,
                children: [
                  // RED WITH REST
                  MondrianTreeBranch(
                    fraction: 4 / 5,
                    children: [
                      // RED WHITE
                      MondrianTreeBranch(
                        fraction: 3 / 4,
                        children: [
                          // RED
                          MondrianTreeLeaf(fraction: 3 / 7, id: MondrianTreeLeafId("Red 2")),
                          // WHITE
                          MondrianTreeLeaf(fraction: 4 / 7, id: MondrianTreeLeafId("White 5")),
                        ],
                      ),
                      // WHITE
                      MondrianTreeLeaf(fraction: 1 / 4, id: MondrianTreeLeafId("White 4")),
                    ],
                  ),
                  // YELLOW
                  MondrianTreeLeaf(fraction: 1 / 5, id: MondrianTreeLeafId("Yellow 3")),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);


/*


________________________________
                        |
                        |
                        |_______
                        |
________________________|_______
          |         |
__________|_________|___________


Column(
  0.70: Row(
    0.70: WINDOW
    0.30: Column(
      0.60: WINDOW
      0.40: WINDOW
    )
  )
  0.30: Row(
    0.30: WINDOW
    0.30: WINDOW
    0.40: WINDOW
  )
)
*/
