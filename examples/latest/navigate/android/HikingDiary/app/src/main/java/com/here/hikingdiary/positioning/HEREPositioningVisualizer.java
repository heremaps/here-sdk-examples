package com.here.hikingdiary.positioning;

import android.util.Log;

import com.here.sdk.core.Color;

import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.Location;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LocationIndicator;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;

import java.util.ArrayList;
import java.util.List;

// A class to visualize the incoming raw location signals on the map during a trip.
public class HEREPositioningVisualizer {
    private MapView mapView;
    private LocationIndicator locationIndicator = new LocationIndicator();
    private List<MapPolygon> mapCircles = new ArrayList<>();
    private MapPolyline mapPolyline;
    private List<GeoCoordinates> geoCoordinatesList = new ArrayList<>();
    private double accuracyRadiusThresholdInMeters = 10.0;

    public HEREPositioningVisualizer(MapView mapView) {
        this.mapView = mapView;
        setupMyLocationIndicator();
    }

    public void updateLocationIndicator(Location location) {
        locationIndicator.updateLocation(location);
    }

    // Renders the last n location signals and connects them with a polyline.
    // The accuracy of each location is indicated through a colored circle.
    public void renderUnfilteredLocationSignals(Location location) {
        Log.d("Received accuracy ", String.valueOf(location.horizontalAccuracyInMeters));

        // Black means that no accuracy information is available.
        Color fillColor = Color.valueOf(android.graphics.Color.BLACK);
        if (location.horizontalAccuracyInMeters != null) {
            double accuracy = location.horizontalAccuracyInMeters;
            if (accuracy < accuracyRadiusThresholdInMeters / 2) {
                // Green means that we have very good accuracy.
                fillColor = Color.valueOf(android.graphics.Color.GREEN);
            } else if (accuracy <= accuracyRadiusThresholdInMeters) {
                // Orange means that we have acceptable accuracy.
                fillColor = Color.valueOf(android.graphics.Color.rgb(255, 165, 0)); // Orange color
            } else {
                // Red means, the accuracy is quite bad, ie > 50 m.
                // The location will be ignored for our hiking diary.
                fillColor = Color.valueOf(android.graphics.Color.RED);
            }
        }

        addLocationCircle(location.coordinates, 1, fillColor);
        updateMapPolyline(location);
    }

    public void clearMap() {
        if (mapPolyline != null) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
            mapPolyline = null;
        }

        for (MapPolygon circle : mapCircles) {
            mapView.getMapScene().removeMapPolygon(circle);
        }

        geoCoordinatesList.clear();
    }

    private void setupMyLocationIndicator() {
        locationIndicator.setAccuracyVisualized(true);
        locationIndicator.setLocationIndicatorStyle(LocationIndicator.IndicatorStyle.PEDESTRIAN);
        mapView.addLifecycleListener(locationIndicator);
    }

    private void addLocationCircle(GeoCoordinates center, double radiusInMeters, Color fillColor) {
        GeoCircle geoCircle = new GeoCircle(center, radiusInMeters);
        GeoPolygon geoPolygon = new GeoPolygon(geoCircle);
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);
        mapView.getMapScene().addMapPolygon(mapPolygon);
        mapCircles.add(mapPolygon);

        if (mapCircles.size() > 300) {
            // Drawing too many items on the map view may slow down rendering, so we remove the oldest circle.
            mapView.getMapScene().removeMapPolygon(mapCircles.get(0));
            mapCircles.remove(0);
        }
    }

    private void updateMapPolyline(Location location) {
        geoCoordinatesList.add(location.coordinates);

        if (geoCoordinatesList.size() < 2) {
            return;
        }

        // We are sure that the number of vertices is greater than 1 (see above), so it will not crash.
        GeoPolyline geoPolyline;
        try {
            geoPolyline = new GeoPolyline(geoCoordinatesList);
        } catch (InstantiationErrorException e) {
            e.printStackTrace();
            return;
        }

        // Add polyline to the map, if the instance is null.
        if (mapPolyline == null) {
            addMapPolyline(geoPolyline);
            return;
        }

        // Update the polyline shape that connects the raw location signals.
        mapPolyline.setGeometry(geoPolyline);
    }

    private void addMapPolyline(GeoPolyline geoPolyline) {
        mapPolyline = new MapPolyline(geoPolyline,
                5, // widthInPixels
                Color.valueOf(android.graphics.Color.BLACK));
        mapView.getMapScene().addMapPolyline(mapPolyline);
    }

}
