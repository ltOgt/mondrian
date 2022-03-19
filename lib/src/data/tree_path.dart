/// The index for each child that must be passed to reach the destination node.
typedef MondrianTreePath = List<int>;

/// Container for [MondrianTreePath] with the extension of [tabIndexIfAny] which is non null if the path points to a tab inside a tab leaf
// TODO consider using this object in other callbacks (e.g. for move)
class MondrianTreePathWithTabIndexIfAny {
  final MondrianTreePath path;
  final int? tabIndexIfAny;

  MondrianTreePathWithTabIndexIfAny({
    required this.path,
    required this.tabIndexIfAny,
  });
}
