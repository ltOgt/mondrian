import 'package:mondrian/src/tree_service.dart';

enum MondrianAxis {
  horizontal,
  vertical,
}

extension MondrianAxisX on MondrianAxis {
  MondrianAxis get previous => MondrianAxis.values[(index - 1) % MondrianAxis.values.length];
  MondrianAxis get next => MondrianAxis.values[(index + 1) % MondrianAxis.values.length];

  bool get isHorizontal => MondrianAxis.horizontal == this;
  bool get isVertical => MondrianAxis.vertical == this;

  String encode() => MondrianMarshalSvc.encAxis(this);
  static MondrianAxis decode(String s) => MondrianMarshalSvc.decAxis(s);
}
