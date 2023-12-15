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

package com.here.camerakeyframetracks;

import android.util.Log;

import com.here.sdk.animation.Easing;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapView;
import com.here.sdk.routing.Route;
import com.here.time.Duration;

public class RouteAnimationExample {

    private final MapView mapView;
    private final RouteCalculator routeCalculator;

    public RouteAnimationExample(MapView mapView) {
        this.mapView = mapView;

        // Creates a fixed route for testing purposes.
        routeCalculator = new RouteCalculator(mapView);
        routeCalculator.createRoute();
    }

    public void stopRouteAnimation() {
        mapView.getCamera().cancelAnimations();
    }

    public void animateToRoute() {
        if (RouteCalculator.testRoute == null) {
            Log.e("RouteAnimationExample", "Error: No route for testing ...");
            return;
        }

        animateToRoute(RouteCalculator.testRoute);
    }

    private void animateToRoute(Route route) {
        // The animation should result in an untilted and unrotated map.
        double bearing = 0;
        double tilt = 0;
        // We want to show the route fitting in the map view with an additional padding of 50 pixels
        Point2D origin = new Point2D(50, 50);
        Size2D sizeInPixels = new Size2D(mapView.getWidth() - 100, mapView.getHeight() - 100);
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        // Animate to the route within a duration of 3 seconds.
        MapCameraUpdate update = MapCameraUpdateFactory.lookAt(
                route.getBoundingBox(),
                new GeoOrientationUpdate(bearing, tilt),
                mapViewport);
        MapCameraAnimation animation =
                MapCameraAnimationFactory.createAnimation(update, Duration.ofMillis(3000), new Easing(EasingFunction.IN_CUBIC));
        mapView.getCamera().startAnimation(animation);
    }
}
