package com.here.multidisplays;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import androidx.appcompat.app.AppCompatActivity;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCircle;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

public class SecondaryActivity extends AppCompatActivity {

    private static final String TAG = SecondaryActivity.class.getSimpleName();
    private MapView mapView;

    // Handle messages coming from primary display.
    private final DataBroadcast dataBroadcast = new DataBroadcast() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent.getAction().equals(DataBroadcast.MESSAGE_FROM_PRIMARY_DISPLAY)) {
                double latitude = intent.getDoubleExtra("latitude", 0);
                double longitude = intent.getDoubleExtra("longitude", 0);
                Log.d(TAG, "Current center of secondary display: lat:" + latitude + ", lon: " + longitude);

                // Add circle to this map view's center.
                GeoCoordinates mapCenterGeoCoordinates = mapView.getCamera().getState().targetCoordinates;
                addMapCircle(mapCenterGeoCoordinates);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_second);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        registerReceiver(dataBroadcast, dataBroadcast.getFilter(DataBroadcast.MESSAGE_FROM_PRIMARY_DISPLAY));
        loadMapScene();
    }

    private void loadMapScene() {
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, mapError -> {
            if (mapError == null) {
                double distanceInMeters = 1000 * 5;
                MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                mapView.getCamera().lookAt(new GeoCoordinates(40.679857, -73.895075), mapMeasureZoom);
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
            }
        });
    }

    public void addButtonClicked(View view) {
        // Send message to primary display.
        GeoCoordinates mapCenterGeoCoordinates = mapView.getCamera().getState().targetCoordinates;
        dataBroadcast.sendMessageToPrimaryDisplay(this, mapCenterGeoCoordinates);
    }

    private void addMapCircle(GeoCoordinates geoCoordinates) {
        float radiusInMeters = 100;
        GeoCircle geoCircle = new GeoCircle(geoCoordinates, radiusInMeters);
        GeoPolygon geoPolygon = new GeoPolygon(geoCircle);
        Color fillColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f); // RGBA
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);
        mapView.getMapScene().addMapPolygon(mapPolygon);
    }

    @Override
    protected void onPause() {
        super.onPause();
        mapView.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        mapView.onResume();
    }

    @Override
    protected void onDestroy() {
        unregisterReceiver(dataBroadcast);
        mapView.onDestroy();

        super.onDestroy();
    }
}