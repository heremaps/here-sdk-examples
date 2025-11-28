package com.here.sdk.units.mapruler;

import android.util.Log;
import android.widget.TextView;

import androidx.annotation.NonNull;

import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point2D;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraListener;
import com.here.sdk.mapview.MapView;

public class MapScaleUnit {

    private final MapView mapView;
    private final TextView scaleText;
    private static final String TAG = "MapScaleUnit";

    public MapScaleUnit(@NonNull MapView mapView, @NonNull TextView scaleText) {
        this.mapView = mapView;
        this.scaleText = scaleText;

        setupCameraListener();
    }

    private void setupCameraListener() {
        mapView.getCamera().addListener(new MapCameraListener() {
            @Override
            public void onMapCameraUpdated(@NonNull MapCamera.State state) {
                updateScale();
            }
        });
    }

    private void updateScale() {
        Point2D pxCenter = new Point2D(mapView.getWidth() / 2, mapView.getHeight() / 2);
        Point2D pxRight = new Point2D((mapView.getWidth() / 2) + 200, mapView.getHeight() / 2);

        GeoCoordinates geoCenter = mapView.viewToGeoCoordinates(pxCenter);
        GeoCoordinates geoRight = mapView.viewToGeoCoordinates(pxRight);

        if (geoCenter == null || geoRight == null) return;

        double meters = geoCenter.distanceTo(geoRight);
        String scaleStr = String.format("%.1f", meters) + " m";

        scaleText.setText(scaleStr);
        Log.d(TAG, scaleStr);
    }
}
