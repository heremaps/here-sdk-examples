/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

package com.here;

import static junit.framework.TestCase.assertEquals;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoMoreInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.withSettings;

import com.here.sdk.core.Angle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.core.GeoOrientation;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapView;
import com.here.time.Duration;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.junit.MockitoJUnitRunner;

@RunWith(MockitoJUnitRunner.class)
public class TestBasicTypes {

    @Test
    public void testNonStaticMethod() {
        // Disclaimer: This test does not show a REAL unit test (although the test will get green).
        // It just shows examples of how the HERE SDK can be accessed in a unit test scenario.

        Angle angleMock = mock(Angle.class);

        when(angleMock.getDegrees()).thenReturn(10.0);

        assertEquals(10.0, angleMock.getDegrees());
        verify(angleMock, times(1)).getDegrees();
        verifyNoMoreInteractions(angleMock);
    }

    @Test
    public void testStaticMethod() {
        // Disclaimer: This test does not show a REAL unit test (although the test will get green).
        // It just shows examples of how the HERE SDK can be accessed in a unit test scenario.

        Angle angleMock = mock(Angle.class);
        when(angleMock.getDegrees()).thenReturn(10.0);

        // Each HERE SDK class with static methods contains helper code to make mocking easier.
        // Add heresdk-xxx.jar to access these additional mock helper instances.
        Angle.StaticMockHelperInstance = mock(Angle.StaticMockHelper.class);
        when(Angle.StaticMockHelperInstance.fromRadians(anyDouble())).thenReturn(angleMock);

        // Test static creation of Angle class. Static HERE SDK classes require a StaticMockHelperInstance.
        assertEquals(10.0, Angle.fromRadians(0.174533).getDegrees(), 0.1);

        verify(Angle.StaticMockHelperInstance, times(1)).fromRadians(anyDouble());
        verify(angleMock, times(1)).getDegrees();
        verifyNoMoreInteractions(Angle.StaticMockHelperInstance);
        verifyNoMoreInteractions(angleMock);
    }

    @Test
    public void testMapView() {
        // Disclaimer: This test does not show a REAL unit test (although the test will get green).
        // It just shows examples of how the HERE SDK can be accessed in a unit test scenario.

        GeoCoordinates targetCoordinates = mock(GeoCoordinates.class);
        GeoOrientation orientationAtTarget = mock(GeoOrientation.class);
        double distanceInMeters = 5000.0;
        double zoomLevel = 1000.0;

        double bowFactor = 1;
        Duration duration = mock(Duration.class);
        GeoCoordinatesUpdate geoCoordinatesUpdate = mock(GeoCoordinatesUpdate.class);

        MapView mapView = mock(MapView.class);
        // When a mock is declared as lenient, then none of its stubbings will be checked for 'unnecessary stubbing'.
        MapCamera mapCamera = mock(MapCamera.class, withSettings().lenient());
        MapCamera.State state = new MapCamera.State(targetCoordinates, orientationAtTarget, distanceInMeters, zoomLevel);

        MapCameraAnimation mapCameraAnimation = mock(MapCameraAnimation.class);
        MapCameraAnimationFactory.StaticMockHelperInstance = mock(MapCameraAnimationFactory.StaticMockHelper.class);

        when(mapView.getWidth()).thenReturn(100);
        when(mapView.getHeight()).thenReturn(100);
        when(mapCamera.getState()).thenReturn(state);
        when(MapCameraAnimationFactory.StaticMockHelperInstance.flyTo(geoCoordinatesUpdate, bowFactor, duration)).thenReturn(mapCameraAnimation);

        // This verifies that the HERE SDK's MapView can be mocked as expected.
        assertEquals(100, mapView.getWidth());
        assertEquals(100, mapView.getHeight());

        // This verifies that the HERE SDK's MapCamera can be mocked as expected.
        assertEquals(state, mapCamera.getState());
        assertEquals(mapCameraAnimation, MapCameraAnimationFactory.StaticMockHelperInstance.flyTo(geoCoordinatesUpdate, bowFactor, duration));
        verify(mapView, times(1)).getWidth();
        verify(mapView, times(1)).getHeight();
        verify(mapCamera, times(1)).getState();
    }
}
