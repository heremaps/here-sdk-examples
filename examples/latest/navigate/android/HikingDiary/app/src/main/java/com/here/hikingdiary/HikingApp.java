/*
 * Copyright (C) 2023-2024 HERE Europe B.V.
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

package com.here.hikingdiary;

import android.app.Activity;
import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.util.Log;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;

import com.here.hikingdiary.locationfilter.DistanceAccuracyLocationFilter;
import com.here.hikingdiary.locationfilter.LocationFilterInterface;
import com.here.hikingdiary.positioning.HEREPositioningVisualizer;
import com.here.sdk.animation.Easing;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCoordinatesUpdate;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapPolyline.SolidRepresentation;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.navigation.GPXTrack;
import com.here.sdk.navigation.GPXTrackWriter;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.List;

public class HikingApp {
    public HEREBackgroundPositioningServiceProvider hereBackgroundPositioningServiceProvider;
    private MapView mapView;
    private Context context;
    private MapPolyline myPathMapPolyline;
    private boolean isHiking = false;
    private boolean isGPXTrackLoaded = false;
    private GPXTrackWriter gpxTrackWriter = new GPXTrackWriter();
    private GPXManager gpxManager;
    private HEREPositioningVisualizer positioningVisualizer;
    private OutdoorRasterLayer outdoorRasterLayer;
    private TextView messageTextView;
    private LocationFilterInterface locationFilter;
    private Activity activity;
    private Location currentLocation;

    private final LocationListener locationListener = location -> {
        currentLocation = location;
        onLocationUpdated(location);
    };

    public HikingApp(MapView mapView, Context context) {
        this.mapView = mapView;
        this.context = context;
        activity = (Activity) context;

        locationFilter = new DistanceAccuracyLocationFilter();
        gpxManager = new GPXManager("myGPXDocument.gpx", context);
        positioningVisualizer = new HEREPositioningVisualizer(mapView);
        outdoorRasterLayer = new OutdoorRasterLayer(mapView);

        hereBackgroundPositioningServiceProvider = new HEREBackgroundPositioningServiceProvider(activity, locationListener);
        animateCameraToCurrentLocation();
        setupMessageView();
        setMessage("** Hiking Diary **");
    }

    public void onStartHikingButtonClicked() {
        clearMap();
        isHiking = true;
        isGPXTrackLoaded = false;
        animateCameraToCurrentLocation();
        setMessage("Start Hike.");
        gpxTrackWriter = new GPXTrackWriter();
    }

    public void onStopHikingButtonClicked() {
        clearMap();
        if (isHiking && !isGPXTrackLoaded) {
            saveDiaryEntry();
        } else {
            setMessage("Stopped.");
        }
        isHiking = false;
    }

    public void enableOutdoorRasterLayer() {
        outdoorRasterLayer.enable();
    }

    public void disableOutdoorRasterLayer() {
        outdoorRasterLayer.disable();
    }

    public void onLocationUpdated(@NonNull Location location) {
        positioningVisualizer.updateLocationIndicator(location);
        if (isHiking) {
            positioningVisualizer.renderUnfilteredLocationSignals(location);
        }
        if (isHiking && locationFilter.checkIfLocationCanBeUsed(location)) {
            gpxTrackWriter.onLocationUpdated(location);
            MapPolyline mapPolyline = updateTravelledPath();
            if (mapPolyline != null) {
                int distanceTravelled = getLengthOfGeoPolylineInMeters(mapPolyline.getGeometry());
                setMessage("Hike Distance: " + distanceTravelled + " m");
            }
        }
    }

    private MapPolyline updateTravelledPath() {
        List<GeoCoordinates> geoCoordinatesList = gpxManager.getGeoCoordinatesList(gpxTrackWriter.getTrack());
        if (geoCoordinatesList.size() < 2) {
            return null;
        }
        GeoPolyline geoPolyline;
        try {
            geoPolyline = new GeoPolyline(geoCoordinatesList);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException(e);
        }
        if (myPathMapPolyline == null) {
            addMapPolyline(geoPolyline);
            return myPathMapPolyline;
        }
        myPathMapPolyline.setGeometry(geoPolyline);
        return myPathMapPolyline;
    }

    private int getLengthOfGeoPolylineInMeters(GeoPolyline geoPolyline) {
        int length = 0;

        for (int i = 1; i < geoPolyline.vertices.size(); i++) {
            length += (int) geoPolyline.vertices.get(i).distanceTo(geoPolyline.vertices.get(i-1));
        }
        return length;
    }

    private void addMapPolyline(GeoPolyline geoPolyline) {
        clearMap();
        try {
            float widthInPixels = 20;
            Color polylineColor = new Color(0, (float) 0.56, (float) 0.54, (float) 0.63);
            myPathMapPolyline = new MapPolyline(geoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    polylineColor,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }
        mapView.getMapScene().addMapPolyline(myPathMapPolyline);
    }

    private void clearMap() {
        if (myPathMapPolyline != null) {
            mapView.getMapScene().removeMapPolyline(myPathMapPolyline);
            myPathMapPolyline = null;
        }
        positioningVisualizer.clearMap();
    }

    private void saveDiaryEntry() {
        // Permanently store the trip on the device.
        boolean result = gpxManager.saveGPXTrack(gpxTrackWriter.getTrack());
        setMessage("Saved Hike: " + result + ".");
    }

    // Load the selected diary entry and show the polyline related to that hike.
    public void loadDiaryEntry(int index) {
        if (isHiking) {
            System.out.println("Stop hiking first.");
            return;
        }

        isGPXTrackLoaded = true;

        // Load the hiking trip.
        GPXTrack gpxTrack = gpxManager.getGPXTrack(index);
        if (gpxTrack == null) {
            return;
        }

        List<GeoCoordinates> diaryGeoCoordinatesList = gpxManager.getGeoCoordinatesList(gpxTrack);
        GeoPolyline diaryGeoPolyline;
        try {
            diaryGeoPolyline = new GeoPolyline(diaryGeoCoordinatesList);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException(e);
        }
        int distanceTravelled = getLengthOfGeoPolylineInMeters(diaryGeoPolyline);

        addMapPolyline(diaryGeoPolyline);
        animateCameraTo(diaryGeoCoordinatesList);

        setMessage("Diary Entry from: " + gpxTrack.getDescription() + "\n" +
                "Hike Distance: " + distanceTravelled + " m");
    }

    public void deleteDiaryEntry(int index) {
        boolean isSuccess = gpxManager.deleteGPXTrack(index);
        System.out.println("Deleted entry: " + isSuccess);
    }

    public List<String> getMenuEntryKeys() {
        List<String> entryKeys = new ArrayList<>();
        for (GPXTrack track : gpxManager.gpxDocument.getTracks()) {
            entryKeys.add(track.getName());
        }
        return entryKeys;
    }

    public List<String> getMenuEntryDescriptions() {
        List<String> entryDescriptions = new ArrayList<>();
        for (GPXTrack track : gpxManager.gpxDocument.getTracks()) {
            entryDescriptions.add("Hike done on: " + track.getDescription());
        }
        return entryDescriptions;
    }

    private void animateCameraToCurrentLocation() {
        if (currentLocation != null) {
            GeoCoordinatesUpdate geoCoordinatesUpdate = new GeoCoordinatesUpdate(currentLocation.coordinates);
            Duration durationInSeconds = Duration.ofSeconds(3);
            MapMeasure distanceInMeters = new MapMeasure(MapMeasure.Kind.DISTANCE, 500);
            MapCameraAnimation animation = MapCameraAnimationFactory.flyTo(geoCoordinatesUpdate, distanceInMeters,1, durationInSeconds);

            mapView.getCamera().startAnimation(animation);
        }
    }

    private void animateCameraTo(List<GeoCoordinates> geoCoordinateList) {
        // We want to show the polyline fitting in the map view with an additional padding of 50 pixels.
        Point2D origin = new Point2D(50.0, 50.0);
        Size2D sizeInPixels = new Size2D(mapView.getViewportSize().width - 100,
                mapView.getViewportSize().height - 100);
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        // Untilt and unrotate the map.
        double bearing = 0;
        double tilt = 0;
        GeoOrientationUpdate geoOrientationUpdate = new GeoOrientationUpdate(bearing, tilt);

        // For very short polylines we want to have at least a distance of 100 meters.
        MapMeasure minDistanceInMeters = new MapMeasure(MapMeasure.Kind.DISTANCE, 100);

        MapCameraUpdate mapCameraUpdate = MapCameraUpdateFactory.lookAt(geoCoordinateList,
                mapViewport,
                geoOrientationUpdate,
                minDistanceInMeters);

        // Create animation.
        Duration durationInSeconds = Duration.ofSeconds(3);
        MapCameraAnimation mapCameraAnimation = MapCameraAnimationFactory.createAnimation(mapCameraUpdate,
                durationInSeconds,
                new Easing(EasingFunction.IN_CUBIC));
        mapView.getCamera().startAnimation(mapCameraAnimation);
    }

    private void setupMessageView() {
        messageTextView = new TextView(context);
        messageTextView.setTextColor(android.graphics.Color.WHITE);
        messageTextView.setBackgroundColor(android.graphics.Color.rgb(0, 145, 145));
        messageTextView.setTextSize(14);
        messageTextView.setGravity(Gravity.CENTER);

        int width = (int) (mapView.getWidth() * 0.6);
        int height = (int) (mapView.getHeight() * 0.085);
        int x = (int) (mapView.getWidth() * 0.5 - width * 0.5);
        int y = (int) (mapView.getHeight() * 0.9 - height * 0.5);

        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(width, height);
        layoutParams.setMargins(x, y, 0, 0);
        messageTextView.setLayoutParams(layoutParams);

        // Set the corner radius for the TextView background.
        GradientDrawable background = new GradientDrawable();
        background.setColor(android.graphics.Color.rgb(0, 145, 145));
        background.setCornerRadius(12);
        messageTextView.setBackground(background);

        // Add the TextView to the mapView (assuming mapView is a FrameLayout or similar ViewGroup).
        mapView.addView(messageTextView);

        // Animate the appearance of the TextView.
        messageTextView.setAlpha(0);
        messageTextView.animate().alpha(1).setDuration(200).start();
    }

    public void setMessage(String message) {
        messageTextView.setText(message);
    }
}
