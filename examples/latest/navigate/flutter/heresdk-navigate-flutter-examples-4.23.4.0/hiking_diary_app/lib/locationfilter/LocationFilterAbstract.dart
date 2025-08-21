/*
 * Copyright (C) 2023-2025 HERE Europe B.V.
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

import 'package:here_sdk/core.dart';

/*
 * LocationFilterStrategy interface defines the structure for filtering locations based on a given criteria.
 * Adopting this interface allows for easy customization and implementation of different strategies for location
 * filtering algorithms without changing the core functionality of the hiking app.
 */
abstract class LocationFilterAbstract {
  bool checkIfLocationCanBeUsed(Location location);
}