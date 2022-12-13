import 'package:flutter/cupertino.dart';

class ListEventHandler with ChangeNotifier {
  ValueNotifier<List> updatedList = ValueNotifier<List>(["Venue Id"]);
}

ListEventHandler listEventHandler = new ListEventHandler();

class MapLoading with ChangeNotifier {
  ValueNotifier<bool> isMapLoading = ValueNotifier<bool>(false);
}

MapLoading mapLoading = new MapLoading();
