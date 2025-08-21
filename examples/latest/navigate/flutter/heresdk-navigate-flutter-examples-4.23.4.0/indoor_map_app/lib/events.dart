import 'package:flutter/cupertino.dart';

class ListEventHandler with ChangeNotifier {
  ValueNotifier<List> updatedList = ValueNotifier<List>(["Venue Id"]);
}

ListEventHandler listEventHandler = new ListEventHandler();

class NameListEventHandler with ChangeNotifier {
  ValueNotifier<List<String>> updatedNameList = ValueNotifier<List<String>>(["Venue Name"]);
}

NameListEventHandler nameListEventHandler = new NameListEventHandler();

class VenueGeometryNameEventHandler with ChangeNotifier {
  ValueNotifier<List<String>> updatedVenueGeometry = ValueNotifier<List<String>>(["Geometry Item"]);
}

VenueGeometryNameEventHandler venueGeometryNameEventHandler = new VenueGeometryNameEventHandler();

class MapLoading with ChangeNotifier {
  ValueNotifier<bool> isMapLoading = ValueNotifier<bool>(false);
}

MapLoading mapLoading = new MapLoading();

class SpeceTapped with ChangeNotifier {
  ValueNotifier<bool> isSpaceTapped = ValueNotifier<bool>(false);
}

SpeceTapped spaceTapped = new SpeceTapped();

class TopologyLineTapped with ChangeNotifier {
  ValueNotifier<bool> isTopologyLineTapped = ValueNotifier<bool>(false);
}

TopologyLineTapped topologyLineTapped = new TopologyLineTapped();
