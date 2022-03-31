import 'package:collection/collection.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    final listEquals = const DeepCollectionEquality().equals;

    return other is MondrianTreePathWithTabIndexIfAny &&
        listEquals(other.path, path) &&
        other.tabIndexIfAny == tabIndexIfAny;
  }

  @override
  int get hashCode {
    final listHash = const DeepCollectionEquality().hash;

    return listHash(path) ^ tabIndexIfAny.hashCode;
  }
}
