/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import 'package:flutter/cupertino.dart';
import 'package:indoor_map_app/indoor_bottom_sheet_data_notifier.dart';
import 'package:indoor_map_app/indoor_events.dart';
import 'package:indoor_map_app/indoor_topology_info.dart';
import 'package:indoor_map_app/venue_data_provider_interface.dart';
import 'package:indoor_map_app/venue_error_data.dart';
import 'package:indoor_map_app/venue_tap_controller.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:here_sdk/venue.service.dart';
import 'package:here_sdk/venue.style.dart';

class VenueDataProvider extends ChangeNotifier implements VenueDataProviderInterface {
  VenueEngine? venueEngine;
  late final VenueMap venueMap;
  Venue? selectedVenue;
  bool isVenueLoading = false;
  bool venueLoadedOnMap = false;
  VenueErrorData? venueErrorData;

  // Inverted level index shown in the level switcher.
  int currSelectedLevelIndx = -1;
  List<VenueLevel>? levelList;
  int maxLevelIndex = -1;

  // Currently selected drawing index.
  int currSelectedDrawingIndx = -1;
  bool showVenueDrawingList = false;
  List<VenueDrawing>? venueDrawingList;

  // Geometry list shown in bottom sheet (names + addresses).
  List<String> geometryList = <String>[];
  List<String?> geometryInternalAddressList = <String?>[];
  bool isVenueListAvailable = false;
  bool isAuthenticationFailed = false;
  List<VenueGeometry> venueGeometryList = <VenueGeometry>[];

  // Tap controller reference.
  VenueTapController? venueTapController;

  // Topology state.
  bool isTopologyPresent = false;
  bool topologyVisibleOnVenue = false;
  IndoorTopologyInfo? topologyInfo;

  @override
  void dispose() {
    resetDataProviderParam();
    super.dispose();
  }

  void resetDataProviderParam() {
    selectedVenue = null;
    venueEngine = null;
    isVenueLoading = false;
    venueLoadedOnMap = false;
    venueErrorData = null;
    currSelectedLevelIndx = -1;
    currSelectedDrawingIndx = -1;
    showVenueDrawingList = false;
    levelList = null;
    maxLevelIndex = -1;
    venueDrawingList = null;
    isVenueListAvailable = false;
    isAuthenticationFailed = false;
    geometryList = <String>[];
    geometryInternalAddressList = <String?>[];
    venueGeometryList = <VenueGeometry>[];
    isTopologyPresent = false;
    topologyVisibleOnVenue = false;
    topologyInfo = null;
  }

  void setVenueEngine(VenueEngine engine) {
    venueEngine = engine;
    if (venueEngine == null) {
      debugPrint('VenueDataProvider: VenueEngine set is null');
    } else {
      debugPrint('VenueDataProvider: VenueEngine is set');
      venueMap = venueEngine!.venueMap;
    }
  }

  void setTapController(VenueTapController? tapController) {
    venueTapController = tapController;
  }

  void setCurrentSelectedLevelIndex(int currIndex) {
    if (currSelectedLevelIndx == currIndex) return;
    currSelectedLevelIndx = currIndex;
    notifyListeners();
  }

  void setCurrentSelectedDrawingIndex(int newIndex) {
    if (currSelectedDrawingIndx == newIndex) return;
    currSelectedDrawingIndx = newIndex;
    updateVenueLevelInfo();
    setMainLevel();
    notifyListeners();
  }

  void setVenueDrawingListVisibility(bool val) {
    if (showVenueDrawingList == val) return;
    showVenueDrawingList = val;
    notifyListeners();
  }

  void setMainLevel() {
    if (levelList == null) {
      debugPrint('VenueDataProvider: VenueLevel list is empty.');
      handleVenueLoadingFailure(VenueErrorCode.notFound);
      return;
    }
    for (int i = 0; i < levelList!.length; i++) {
      if (levelList![i].isIsMainLevel) {
        currSelectedLevelIndx = i;
      }
    }
  }

  void updateVenueLevelInfo() {
    if (venueEngine?.venueMap.selectedVenue != null) {
      levelList = venueEngine!.venueMap.selectedVenue!.selectedDrawing.levels.reversed.toList();
      maxLevelIndex = levelList!.length - 1;
    }
  }

  String getDrawingName(VenueDrawing drawing) {
    final Property? property = drawing.properties['name'];
    return property?.asString ?? '';
  }

  void setSelectedDrawing() {
    if (venueDrawingList == null) {
      handleVenueLoadingFailure(VenueErrorCode.notFound);
      return;
    }
    for (int i = 0; i < (venueDrawingList?.length ?? 0); i++) {
      if (venueDrawingList![i].isIsRoot) {
        currSelectedDrawingIndx = i;
      }
    }
  }

  void updateVenueDrawingInfo() {
    if (venueEngine?.venueMap.selectedVenue != null) {
      venueDrawingList = venueEngine!.venueMap.selectedVenue!.venueModel.drawings;
    }
  }

  void loadVenueEvent(String venueId) {
    if (venueEngine == null || venueId.isEmpty) {
      debugPrint('VenueDataProvider: venueEngine is null or venueId empty: $venueId');
      venueErrorData = VenueErrorData(errorType: VenueErrorType.venueLoadingFailure, errorMessage: 'Venue ID is empty');
      return;
    }
    debugPrint('VenueDataProvider: loadVenueEvent called with Id: $venueId');
    isVenueLoading = true;
    notifyListeners();
    venueEngine!.venueMap.selectVenueAsyncWithErrorsStr(venueId, handleVenueLoadingFailure);
  }

  void handleVenueLoadingFailure(VenueErrorCode? errorCode) {
    debugPrint('VenueDataProvider: handleVenueLoadingFailure with code: $errorCode');
    final String errorMsg;
    switch (errorCode) {
      case VenueErrorCode.noNetwork:
        errorMsg = 'The device has no internet connectivity';
        break;
      case VenueErrorCode.noMetaDataFound:
        errorMsg = 'Meta data not present in platform collection catalog';
        break;
      case VenueErrorCode.hrnMissing:
        errorMsg = 'HRN not provided. Please insert HRN';
        break;
      case VenueErrorCode.hrnMismatch:
        errorMsg = 'HRN does not match with auth key & secret';
        break;
      case VenueErrorCode.noDefaultCollection:
        errorMsg = 'Default collection missing from platform collection catalog';
        break;
      case VenueErrorCode.mapIdNotFound:
        errorMsg = 'Map ID is not part of the default collection';
        break;
      case VenueErrorCode.mapDataIncorrect:
        errorMsg = 'Map data in collection is wrong';
        break;
      case VenueErrorCode.noMapInCollection:
        errorMsg = 'Map not found in collection';
        break;
      case VenueErrorCode.badRequest:
        errorMsg = 'Bad request';
        break;
      case VenueErrorCode.tokenInvalid:
        errorMsg = 'Token invalid';
        break;
      case VenueErrorCode.notFound:
        errorMsg = 'Venue not found';
        break;
      case VenueErrorCode.internalServerError:
        errorMsg = 'Internal server error';
        break;
      case VenueErrorCode.serviceUnavailable:
        errorMsg = 'Service is not available. Please try again later';
        break;
      case VenueErrorCode.payloadTooLarge:
        errorMsg = 'Payload too large to load';
        break;
      default:
        errorMsg = 'Unknown error encountered';
    }
    debugPrint('VenueDataProvider: venue loading error: $errorMsg');
    isVenueLoading = false;
    venueErrorData = VenueErrorData(
      errorType: VenueErrorType.venueLoadingFailure,
      errorMessage: 'Venue loading failed: $errorMsg',
      venueLoadingErrorCode: errorCode,
    );
    notifyListeners();
  }

  void removeVenueFromMap() {
    if (venueEngine?.venueMap.selectedVenue != null) {
      final Venue v = venueEngine!.venueMap.selectedVenue!;
      venueEngine!.venueMap.removeVenue(v);
    }
    selectedVenue = null;
    venueLoadedOnMap = false;
    levelList = null;
    maxLevelIndex = -1;
    currSelectedLevelIndx = -1;
    showVenueDrawingList = false;
    currSelectedDrawingIndx = -1;
    venueDrawingList = null;
    geometryList = <String>[];
    geometryInternalAddressList = <String>[];
    venueGeometryList = <VenueGeometry>[];
    IndoorBottomSheetDataNotifier.showVenueList(
      venueNameList: filteredVenueNameList.updatedNameList.value,
      venueIdList: filteredVenueIdList.updatedIdList.value,
    );
    isTopologyPresent = false;
    topologyVisibleOnVenue = false;
    topologyInfo = null;
    notifyListeners();
  }

  void resetVenueErrorDataParam() {
    venueErrorData = null;
    notifyListeners();
  }

  void updateGeometryListInfo() {
    geometryList = <String>[];
    geometryInternalAddressList = <String?>[];
    venueGeometryList = <VenueGeometry>[];
    final VenueModel? venueModel = venueEngine?.venueMap.selectedVenue?.venueModel;
    if (venueModel == null) return;
    final List<VenueGeometry> allGeometries = venueModel.geometries;
    venueGeometryList = allGeometries;
    for (final VenueGeometry geometry in allGeometries) {
      String geometryName = geometry.name.isNotEmpty ? geometry.name : geometry.identifier;
      geometryName += ', ${geometry.level.name}';
      final String? internalAddress = geometry.internalAddress != null
          ? 'Address: ${geometry.internalAddress!.address}'
          : null;
      geometryList.add(geometryName);
      geometryInternalAddressList.add(internalAddress);
    }
    IndoorBottomSheetDataNotifier.showGeometryList(
      geometryList: geometryList,
      internalAddressList: geometryInternalAddressList,
    );
    notifyListeners();
  }

  void filterGeometryListInfo(String query) {
    geometryList.clear();
    geometryInternalAddressList.clear();
    venueGeometryList.clear();
    final VenueModel? venueModel = venueMap.selectedVenue?.venueModel;
    if (venueModel == null) return;

    final List<int> indexList = <int>[];
    final List<VenueGeometry> allGeometries = venueModel.geometries;
    venueGeometryList = allGeometries;
    int indx = 0;
    for (final VenueGeometry geometry in allGeometries) {
      String geometryName = geometry.name.isNotEmpty ? geometry.name : geometry.identifier;
      geometryName += ', ${geometry.level.name}';
      final String? internalAddress = geometry.internalAddress != null
          ? 'Address: ${geometry.internalAddress!.address}'
          : null;
      geometryList.add(geometryName);
      geometryInternalAddressList.add(internalAddress);
      if (geometryName.toLowerCase().contains(query)) {
        indexList.add(indx);
      }
      indx++;
    }

    venueGeometryList = indexList.map((int i) => venueGeometryList[i]).toList();
    geometryList = indexList.map((int i) => geometryList[i]).toList();
    geometryInternalAddressList = indexList.map((int i) => geometryInternalAddressList[i]).toList();

    IndoorBottomSheetDataNotifier.showGeometryList(
      geometryList: geometryList,
      internalAddressList: geometryInternalAddressList,
    );
    notifyListeners();
  }

  void setTopologyVisibilityOnVenue(bool val) {
    if (val == topologyVisibleOnVenue) return;
    topologyVisibleOnVenue = val;
    notifyListeners();
  }

  void updateLevelAndDrawingSwitcherUIFromSdk() {
    final int drawingIndx = venueDrawingList!.indexWhere(
      (VenueDrawing d) => d.identifier == venueEngine?.venueMap.selectedVenue?.selectedDrawing.identifier,
    );
    if (drawingIndx != -1) currSelectedDrawingIndx = drawingIndx;

    final int levelIndx = levelList!.indexWhere(
      (VenueLevel l) => l.identifier == venueEngine?.venueMap.selectedVenue?.selectedLevel.identifier,
    );
    if (levelIndx != -1) currSelectedLevelIndx = levelIndx;
  }

  // ---------------------------------------------------------------------------
  // VenueDataProviderInterface implementation
  // ---------------------------------------------------------------------------

  @override
  void onGetVenueCompleted(String venueIdentifier, VenueModel? venueModel, bool online, VenueStyle? venueStyle) {
    debugPrint('VenueDataProvider: onGetVenueCompleted');
    isVenueLoading = false;
    venueLoadedOnMap = true;
    selectedVenue = venueEngine?.venueMap.selectedVenue;
    updateVenueDrawingInfo();
    setSelectedDrawing();
    updateVenueLevelInfo();
    setMainLevel();
    updateGeometryListInfo();
    isTopologyPresent = venueModel?.topologies.isNotEmpty ?? false;
    topologyVisibleOnVenue = selectedVenue?.isTopologyVisible ?? false;
    notifyListeners();
  }

  @override
  void onSelectedVenueChanged(Venue? deselectedVenue, Venue? selectedVenue) {
    debugPrint('VenueDataProvider: onSelectedVenueChanged');
    isVenueLoading = false;
    this.selectedVenue = selectedVenue;
    if (!venueLoadedOnMap) {
      updateVenueDrawingInfo();
      updateVenueLevelInfo();
      updateGeometryListInfo();
      venueLoadedOnMap = true;
      updateLevelAndDrawingSwitcherUIFromSdk();
      isTopologyPresent = selectedVenue?.venueModel.topologies.isNotEmpty ?? false;
      topologyVisibleOnVenue = selectedVenue?.isTopologyVisible ?? false;
    }
    notifyListeners();
  }

  @override
  void onVenueServiceInitializationFailure(VenueServiceInitStatus result) {
    debugPrint('VenueDataProvider: onVenueServiceInitializationFailure');
    venueErrorData = VenueErrorData(errorType: VenueErrorType.venueServiceInitFailure);
    notifyListeners();
  }

  @override
  void onVenueInfoListLoadWithError(VenueErrorCode? venueLoadError, String? errorMsg) {
    debugPrint('VenueDataProvider: onVenueInfoListLoadWithError');
    venueErrorData = VenueErrorData(
      errorType: VenueErrorType.venueInfoListLoadFailure,
      errorMessage: errorMsg,
      venueLoadingErrorCode: venueLoadError,
    );
    notifyListeners();
  }

  @override
  void onVenueInfoListLoadSuccess() {
    isVenueListAvailable = true;
    IndoorBottomSheetDataNotifier.showVenueList(
      venueNameList: filteredVenueNameList.updatedNameList.value,
      venueIdList: filteredVenueIdList.updatedIdList.value,
    );
    notifyListeners();
  }

  @override
  void showTappedGeometryInfo(VenueGeometry geometry) {
    geometryList = <String>[];
    geometryInternalAddressList = <String?>[];
    venueGeometryList = <VenueGeometry>[];
    String geometryName = geometry.name.isNotEmpty ? geometry.name : geometry.identifier;
    geometryName += ', ${geometry.level.name}';
    final String? internalAddress = geometry.internalAddress != null
        ? 'Address: ${geometry.internalAddress!.address}'
        : null;
    geometryList.add(geometryName);
    geometryInternalAddressList.add(internalAddress);
    venueGeometryList = <VenueGeometry>[geometry];
    IndoorBottomSheetDataNotifier.showGeometryList(
      geometryList: geometryList,
      internalAddressList: geometryInternalAddressList,
      isSingleGeometryItem: true,
    );
    notifyListeners();
  }

  @override
  void onDeselectGeometryFromTapController() {
    if (venueEngine?.venueMap.selectedVenue != null) {
      updateGeometryListInfo();
    }
  }

  @override
  void onLevelChangeAfterGeometrySelection(int newLevelIndex) {
    setCurrentSelectedLevelIndex(newLevelIndex);
  }

  @override
  void onDrawingChangeAfterGeometrySelection(int newDrawingIndex) {
    setCurrentSelectedDrawingIndex(newDrawingIndex);
  }

  @override
  void showTappedTopologyInfo(IndoorTopologyInfo info) {
    topologyInfo = info;
    notifyListeners();
  }

  @override
  void onDeselectTopologyFromTapController() {
    topologyInfo = null;
    notifyListeners();
  }

  @override
  void showTopologyButtonOnMap(bool val) {
    isTopologyPresent = val;
    final Venue? v = venueMap.selectedVenue;
    if (v == null) return;
    if (!val && topologyVisibleOnVenue) {
      v.isTopologyVisible = false;
      venueTapController?.deselectTopology();
      topologyVisibleOnVenue = false;
    }
    notifyListeners();
  }

  @override
  void setVenueErrorData(VenueErrorData? errorData) {
    venueErrorData = errorData;
    notifyListeners();
  }
}
