import 'package:flutter/material.dart';
import 'package:ltogt_utils_flutter/ltogt_utils_flutter.dart';
import 'package:mondrian/mondrian.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var tree = k_tree;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mondrian Example',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MondrianWM(
          tree: tree,
          initialAxis: Axis.vertical,
          onResize: (pathToParent, newFraction, index) {
            tree = tree.updatePath(pathToParent, (node) {
              final branch = node as WindowManagerBranch;
              final child1 = branch.children[index];
              final child2 = branch.children[index + 1];

              final diff = child1.fraction - newFraction;
              final child1Updated = child1.updateFraction(newFraction);
              final child2Updated = child2.updateFraction(child2.fraction + diff);

              print("newFraction: $newFraction; c1.old: ${child1.fraction}, c1.new: ${child1Updated.fraction}");

              return WindowManagerBranch(
                fraction: branch.fraction,
                children: [
                  for (int i = 0; i < branch.children.length; i++)
                    if (i == index) ...[
                      child1Updated,
                    ] else if (i == index + 1) ...[
                      child2Updated,
                    ] else ...[
                      branch.children[i],
                    ]
                ],
              );
            });
            setState(() {});
          },
          resolveLeafToWidget: (id) => WindowExample(id.value),
        ),
      ),
    );
  }
}

const k_tree = WindowManagerTree(
  rootNode: WindowManagerBranch(
    fraction: 1,
    children: [
      WindowManagerBranch(
        fraction: .7,
        children: [
          WindowManagerLeaf(
            fraction: .7,
            id: WindowManagerLeafId("Big top left"),
          ),
          WindowManagerBranch(
            fraction: .3,
            children: [
              WindowManagerLeaf(
                fraction: .6,
                id: WindowManagerLeafId("Medium Top Right"),
              ),
              WindowManagerLeaf(
                fraction: .6,
                id: WindowManagerLeafId("Small Mid Right"),
              ),
            ],
          ),
        ],
      ),
      WindowManagerBranch(
        fraction: .3,
        children: [
          WindowManagerLeaf(
            fraction: .3,
            id: WindowManagerLeafId("Bottom Left"),
          ),
          WindowManagerLeaf(
            fraction: .3,
            id: WindowManagerLeafId("Bottom Mid"),
          ),
          WindowManagerLeaf(
            fraction: .4,
            id: WindowManagerLeafId("Bottom Right"),
          ),
        ],
      )
    ],
  ),
);

class WindowExample extends StatelessWidget {
  const WindowExample(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      // decoration: BoxDecoration(
      //   border: Border.all(color: Colors.blueAccent),
      // ),
      child: Center(
        child: AutoSizeText(text: text),
      ),
    );
  }
}

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
