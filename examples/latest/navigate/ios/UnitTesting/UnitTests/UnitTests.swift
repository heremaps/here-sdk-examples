/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import XCTest
import heresdk
@testable import UnitTesting

class UnitTests: XCTestCase {

    var mapView: MapView!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        mapView = MapView()
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }

    // This test verifies that the Angle class converts a radian value to degrees.
    func testAngle() throws {
        // Disclaimer: This test does not show a REAL unit test (although the test will get green).
        // It just shows examples of how the HERE SDK can be accessed in a unit test scenario.
        
        // Static creation of angle object.
        let angle = Angle.fromRadians(angle: 0.174533)
        
        let angleInDegrees = angle.degrees
        // Round the test angle to 1 significant decimal.
        let roundedAngleInDegrees = round(angleInDegrees)

        let expectedAngleInDegrees: Double = 10
        XCTAssertEqual(roundedAngleInDegrees, expectedAngleInDegrees, "This is a message for a failed test.")
    }

    func testMapCamera() throws {
        // Disclaimer: This test does not show a REAL unit test (although the test will get green).
        // It just shows examples of how the HERE SDK can be accessed in a unit test scenario.
        
        let orientationAtTarget = GeoOrientation(bearing: 0, tilt: 0)
        let geoOrientationUpdate = GeoOrientationUpdate(orientationAtTarget)
        
         // Update map camera state.
        mapView.camera.setOrientationAtTarget(geoOrientationUpdate)

        let targetCoordinates = GeoCoordinates(latitude: 52.530932, longitude: 13.384915, altitude: 0)
        let expectedMapCameraState = MapCamera.State(targetCoordinates: targetCoordinates,
                                                     orientationAtTarget: orientationAtTarget,
                                                     distanceToTargetInMeters: 5000, zoomLevel: 1000)
        
        // This shows that map camera state is updated as expected.
        XCTAssertEqual(mapView.camera.state.orientationAtTarget, expectedMapCameraState.orientationAtTarget)
    }
}
