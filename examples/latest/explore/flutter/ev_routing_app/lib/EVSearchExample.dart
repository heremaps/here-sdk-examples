/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/search.dart';

// Example usage of HERE EVSearchEngine for querying detailed EV charging location information.
// Requires an additional EVCP3 license that is not included with a standard Navigate license.
class EVSearchExample {
  late EVSearchEngine? _evSearchEngine;

  EVSearchExample() {
    try {
      _evSearchEngine = EVSearchEngine();
    } on InstantiationException {
      print('EVSearchEngine instantiation failed');
      _evSearchEngine = null;
    }
  }

  EVSearchEngine? get evSearchEngine => _evSearchEngine;

  // This standalone EVCP3 lookup is useful only when the caller already has HERE Place IDs.
  // EVRoutingExample uses SearchEngine.setEVInterface() for generic EV enrichment and this
  // direct lookup when it needs feature-gated EVCP3 fields such as tariffs and EVSE details.
  void runSearchExample(List<String> placeIds) {
    runSearchExampleWithCallback(placeIds, null);
  }

  void runSearchExampleWithCallback(
    List<String> placeIds,
    void Function(EVSearchError? evSearchError, List<EVChargingLocation>? results)? callback,
  ) {
    if (_evSearchEngine == null || placeIds.isEmpty) {
      print('EVSearchEngine or placeIds is null/empty');
      return;
    }
    EVSearchOptions options = _createEVCP3DetailsOptions();
    _evSearchEngine!.setOptions(options);
    _evSearchEngine!.search(placeIds, (EVSearchError? evSearchError, List<EVChargingLocation>? results) {
      callback?.call(evSearchError, results);
      if (evSearchError != null && evSearchError != EVSearchError.noResultsFound) {
        print('EV search failed: ' + evSearchError.toString());
        return;
      }

      if (evSearchError == EVSearchError.noResultsFound) {
        print('EV search completed: No results found.');
      }

      if (results != null) {
        for (EVChargingLocation location in results) {
          printLocation(location);
        }
      }
    });
  }

  EVSearchOptions _createEVCP3DetailsOptions() {
    EVSearchOptions options = EVSearchOptions();
    options.additionalFeatures = [
      EVChargingLocationFeature.evses,
      EVChargingLocationFeature.tariffs,
      EVChargingLocationFeature.connectorGroups,
      EVChargingLocationFeature.emsps,
      EVChargingLocationFeature.locationInfo,
      EVChargingLocationFeature.truckRestrictions,
    ];
    return options;
  }

  void printLocation(EVChargingLocation location) {
    print('=== EV Charging Location ===');
    // Operator Information
    EVChargingOperator? operator = location.evChargingOperator;
    if (operator != null) {
      print('Operator: ' + operator.name);
    }
    for (EVSEInfo evse in location.evses) {
      print('EVSE ID: ' + (evse.id ?? ""));
      for (EVChargingConnector c in evse.connectors) {
        print(' - Connector: ' + c.id);
      }
    }
    final tariffs = location.tariffs;
    print(
      'Tariff count: ${tariffs.length} '
      '(requires tariffs plus evses or connectorGroups in EVSearchOptions)',
    );
    for (EVChargingTariff tariff in tariffs) {
      print('Tariff: ' + (tariff.name ?? ""));
    }
  }

}
