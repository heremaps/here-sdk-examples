/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

package com.here.sdk.examples.venues;

import android.content.Context;
import android.content.DialogInterface;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.ToggleButton;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.bottomsheet.BottomSheetBehavior;
import com.google.android.material.bottomsheet.BottomSheetDialog;
import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.engine.SDKNativeEngine;
import com.here.sdk.core.engine.SDKOptions;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.examples.venues.PermissionsRequestor.ResultListener;
import com.here.sdk.gestures.TapListener;
import com.here.sdk.mapview.MapFeatures;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.venue.VenueEngine;
import com.here.sdk.venue.control.Venue;
import com.here.sdk.venue.control.VenueErrorCode;
import com.here.sdk.venue.control.VenueMap;
import com.here.sdk.venue.control.VenueSelectionListener;
import com.here.sdk.venue.data.VenueGeometry;
import com.here.sdk.venue.data.VenueGeometryFilterType;
import com.here.sdk.venue.data.VenueInfo;
import com.here.sdk.venue.data.VenueModel;
import com.here.sdk.venue.service.VenueListener;
import com.here.sdk.venue.service.VenueService;
import com.here.sdk.venue.service.VenueServiceInitStatus;
import com.here.sdk.venue.service.VenueServiceListener;
import com.here.sdk.venue.style.VenueStyle;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = MainActivity.class.getSimpleName();
    private PermissionsRequestor permissionsRequestor;
    private MapView mapView;
    private VenueEngine venueEngine;
    private DrawingSwitcher drawingSwitcher;
    private LevelSwitcher levelSwitcher;
    private VenueTapController venueTapController;
    private Integer[] venueInfoListItems;
    private int selectedVenueId;

    private RecyclerView recyclerView;
    private LinearLayout bottomSheet;
    private BottomSheetBehavior sheetBehavior;
    private EditText venue_search;
    private List<VenueInfo> venueInfo = new ArrayList<>();
    private List<VenueGeometry> geometryList;
    private Boolean mapLoadDone = false;
    private ImageButton drawingButton;
    private ListView drawingList;
    private LinearLayout header;
    private ImageButton backButton;
    private ImageView cancle_text;
    private TextView venueName;
    private ProgressBar progressBar, progressBarBottom;
    private ToggleButton topologyButton;

    // Set value for hrn with your platform catalog HRN value if you wan    t to load non default collection.
    private String HRN = "YOUR_CATALOG_HRN";

    //Label text preference as per user choice
    private final List<String> labelPref = Arrays.asList("OCCUPANT_NAMES", "SPACE_NAME", "INTERNAL_ADDRESS");

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK();

        setContentView(R.layout.activity_main);

        // Get a MapView instance from the layout.
        mapView = findViewById(R.id.map_view);
        mapView.onCreate(savedInstanceState);

        // Get UI elements for selection venue by id.
        progressBar = findViewById(R.id.progress_bar);
        progressBarBottom = findViewById(R.id.progress_bar_bottom);
        drawingButton = findViewById(R.id.drawing_switcher_button);
        drawingList = findViewById(R.id.drawingList);
        drawingSwitcher = new DrawingSwitcher(this, drawingButton, drawingList);

        // Get drawing and level UI switchers.
        levelSwitcher = findViewById(R.id.level_switcher);

        handleAndroidPermissions();

        recyclerView = findViewById(R.id.VenueListView);
        bottomSheet = findViewById(R.id.bottomSheet);
        sheetBehavior = BottomSheetBehavior.from(bottomSheet);
        venue_search = findViewById(R.id.SearchBar);
        cancle_text = findViewById(R.id.cancleText);
        cancle_text.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                venue_search.setText("");
                cancle_text.setVisibility(View.GONE);
            }
        });
        venue_search.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence charSequence, int i, int i1, int i2) {

            }

            @Override
            public void onTextChanged(CharSequence c, int i, int i1, int i2) {
                if(sheetBehavior.getState() != BottomSheetBehavior.STATE_EXPANDED)
                    sheetBehavior.setState(BottomSheetBehavior.STATE_EXPANDED);
                cancle_text.setVisibility(View.VISIBLE);
                String s = c != null? c.toString() : "";
                s = s.trim();
                if(s.isEmpty()) {
                    cancle_text.setVisibility(View.GONE);
                }
                if(mapLoadDone == false)
                    filterVenues(s);
                else
                    filterSpaces(s);
            }

            @Override
            public void afterTextChanged(Editable editable) {

            }
        });
        header = findViewById(R.id.header);
        backButton = findViewById(R.id.backButton);
        venueName = findViewById(R.id.VenueName);
        header.setVisibility(View.GONE);
        backButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if(mapLoadDone) {
                    removeVenue();
                }
            }
        });
        recyclerView.setVisibility(View.GONE);
        progressBarBottom.setVisibility(View.VISIBLE);
        topologyButton = findViewById(R.id.topologyButton);
        topologyButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                    if (topologyButton.isChecked()) {
                        venueEngine.getVenueMap().getSelectedVenue().setTopologyVisible(true);
                    } else {
                        venueEngine.getVenueMap().getSelectedVenue().setTopologyVisible(false);
                    }
            }
        });
    }

    private void filterSpaces(String s) {
        recyclerView.setAdapter(null);
        List<VenueGeometry> list = new ArrayList<>();
        Log.d(TAG, "Geometries size: " + geometryList.size());
        for(VenueGeometry geometry : geometryList) {
            if(geometry.getName().toLowerCase().contains(s.toLowerCase()) || geometry.getLevel().getName().toLowerCase().contains(s.toLowerCase())
            || (geometry.getInternalAddress() != null ? geometry.getInternalAddress().getAddress() : "").toLowerCase().contains(s.toLowerCase())) {
                list.add(geometry);
            }
        }
        if(!list.isEmpty()) {
            recyclerView.setAdapter(new SpaceAdapter(getApplicationContext(), list, this));
        }
    }

    private void filterVenues(String s) {
        recyclerView.setAdapter(null);
        List<VenueInfo> list = new ArrayList<>();
        for (VenueInfo venue : venueInfo) {
            if(venue.getVenueName().toLowerCase().contains(s.toLowerCase()) || (Integer.toString(venue.getVenueId())).contains(s)) {
                list.add(venue);
            }
        }
        if(!list.isEmpty()) {
            recyclerView.setAdapter(new VenueAdapter(getApplicationContext(), list, this));
        }
    }

    private void initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        String accessKeyID = "VENUE_ACCESS_KEY_ID";
        String accessKeySecret = "VENUE_ACCESS_KEY_SECRET";
        SDKOptions options = new SDKOptions(accessKeyID, accessKeySecret);
        try {
            Context context = this;
            SDKNativeEngine.makeSharedInstance(context, options);
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of HERE SDK failed: " + e.error.name());
        }
    }

    private void handleAndroidPermissions() {
        permissionsRequestor = new PermissionsRequestor(this);
        permissionsRequestor.request(new ResultListener(){

            @Override
            public void permissionsGranted() {
                loadMapScene();
            }

            @Override
            public void permissionsDenied() {
                Log.e(TAG, "Permissions denied by user.");
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
    }

    private void loadMapScene() {
        // Load a scene from the HERE SDK to render the map with a map scheme.
        mapView.getMapScene().loadScene(MapScheme.NORMAL_DAY, mapError -> {
            if (mapError == null) {
                setWatermark(1800);
                double distanceInMeters = 1000 * 10;
                MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                mapView.getCamera().lookAt(
                        new GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

                // Hide the extruded building layer, so that it does not overlap with the venues.
                List<String> mapFeatures = new ArrayList<>();
                mapFeatures.add(MapFeatures.EXTRUDED_BUILDINGS);
                mapView.getMapScene().disableFeatures(mapFeatures);

                // Create a venue engine object. Once the initialization is done, a callback
                // will be called.
                try {
                    venueEngine = new VenueEngine(this ::onVenueEngineInitCompleted);
                } catch (InstantiationErrorException e) {
                    Log.e(TAG, "SDK Engine instantiation failed");
                    e.printStackTrace();
                }
            } else {
                Log.d(TAG, "Loading map failed: mapError: " + mapError.name());
            }
        });
    }

    AdapterView.OnItemSelectedListener onVenueInfoListSelectedListener =
            new AdapterView.OnItemSelectedListener() {
                @Override
                public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                    selectedVenueId = (int) parent.getItemAtPosition(position);
                }

                @Override
                public void onNothingSelected(AdapterView<?> parent) {
                    Log.e(TAG, "Nothing Selected");
                }
            };

    private void onVenueEngineInitCompleted() {
        // Get VenueService and VenueMap objects.
        VenueService service = venueEngine.getVenueService();
        VenueMap venueMap = venueEngine.getVenueMap();

        // Add needed listeners.
        service.add(serviceListener);
        service.add(venueListener);
        venueMap.add(venueSelectionListener);

        // Create a venue tap controller and connect VenueMap to it.
        venueTapController = new VenueTapController(venueEngine, mapView, this, sheetBehavior, recyclerView);
        venueTapController.setVenueMap(venueMap);

        // Set a tap listener.
        mapView.getGestures().setTapListener(tapListener);

        // Connect VenueMap to switchers, to control selected drawing and level in the UI.
        drawingSwitcher.setVenueMap(venueMap);
        levelSwitcher.setVenueMap(venueMap);

        // Start VenueEngine. Once authentication is done, the authentication callback
        // will be triggered. Afterwards, VenueEngine will start VenueService. Once VenueService
        // is initialized, VenueServiceListener.onInitializationCompleted method will be called.
        venueEngine.start((authenticationError, authenticationData) -> {
            if (authenticationError != null) {
                Log.e(TAG, "Failed to authenticate, reason: " + authenticationError.value);
            }
        });

        if ((HRN != "") && (HRN != "YOUR_CATALOG_HRN")) {
            // Set platform catalog HRN
            service.setHrn(HRN);
        }

        // Set label text preference
        service.setLabeltextPreference(labelPref);
        service.loadTopologies();
    }

    // Listener for the VenueService event.
    private final VenueServiceListener serviceListener = new VenueServiceListener() {
        @Override
        public void onInitializationCompleted(@NonNull VenueServiceInitStatus result) {
            if (result == VenueServiceInitStatus.ONLINE_SUCCESS) {
                try{
                    venueInfo = venueEngine.getVenueMap().getVenueInfoList(MainActivity.this::onVenueLoadError);
                    recyclerView.setLayoutManager(new LinearLayoutManager(MainActivity.this));
                    recyclerView.setAdapter(new VenueAdapter(MainActivity.this, venueInfo, MainActivity.this));
                    recyclerView.setVisibility(View.VISIBLE);
                    progressBarBottom.setVisibility(View.GONE);
                }
                catch (Exception e) {
                    Log.d(TAG, e.toString());
                }

                // Enable button for venue selection. From this moment the venue loading
                // is available.
            } else {
                Log.e(TAG, "Failed to initialize venue service.");
            }
        }

        @Override
        public void onVenueServiceStopped() {}
    };

    // Listener for the venue loading event.
    private final VenueListener venueListener = new VenueListener() {
        @Override
        public void onGetVenueCompleted(int venueId, @Nullable VenueModel venueModel, boolean b, @Nullable VenueStyle venueStyle) {
            progressBar.setVisibility(View.GONE);
            if (venueModel == null) {
                Log.e(TAG, "Failed to load the venue: " + venueId);
            } else {
                mapLoadDone = true;
                mapView.getCamera().zoomTo(18);
                setWatermark(1600);
                geometryList = venueModel.getGeometriesByName();
                venueTapController.setGeometries(geometryList);
                recyclerView.setAdapter(new SpaceAdapter(getApplicationContext(), geometryList, MainActivity.this));
                venue_search.setHint("Search for Spaces");
                String venue_name = "";
                for(VenueInfo venue : venueInfo) {
                    if(venue.getVenueId() == venueId)
                        venue_name = venue.getVenueName();
                }
                venueName.setText(venue_name);
                header.setVisibility(View.VISIBLE);
            }
        }
    };

    // Listener for the venue selection event.
    private final VenueSelectionListener venueSelectionListener =
            (deselectedVenue, selectedVenue) -> {
                if (selectedVenue != null) {
                    // Move camera to the selected venue.
                    GeoCoordinates venueCenter = selectedVenue.getVenueModel().getCenter();
                    double distanceInMeters = 500;
                    MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
                    mapView.getCamera().lookAt(
                            new GeoCoordinates(venueCenter.latitude, venueCenter.longitude),
                            mapMeasureZoom);
                    setWatermark(1600);

                    // Venue selection is done, enable back the button for the venue selection
                    // to be able to select another venue.
                    progressBar.setVisibility(View.GONE);
                    mapLoadDone = true;
                    header.setVisibility(View.VISIBLE);
                    if(!selectedVenue.getVenueModel().getTopologies().isEmpty())
                        topologyButton.setVisibility(View.VISIBLE);
                    else
                        topologyButton.setVisibility((View.GONE));
                }
            };

    public void onVenueLoadError(VenueErrorCode venueLoadError) {
        String errorMsg;
        switch (venueLoadError) {
            case NO_NETWORK:
                errorMsg = "The device has no internet connectivity";
                break;
            case NO_META_DATA_FOUND:
                errorMsg = "Meta data not present in platform collection catalog";
                break;
            case HRN_MISSING:
                errorMsg = "HRN not provided. Please insert HRN";
                break;
            case HRN_MISMATCH:
                errorMsg = "HRN does not match with Auth key & secret";
                break;
            case NO_DEFAULT_COLLECTION:
                errorMsg = "Default collection missing from platform collection catalog";
                break;
            case MAP_ID_NOT_FOUND:
                errorMsg = "Map ID requested is not part of the default collection";
                break;
            case MAP_DATA_INCORRECT:
                errorMsg = "Map data in collection is wrong";
                break;
            case INTERNAL_SERVER_ERROR:
                errorMsg = "Internal Server Error";
                break;
            case SERVICE_UNAVAILABLE:
                errorMsg = "Requested service is not available currently. Please try after some time";
                break;
            case NO_MAP_IN_COLLECTION:
                errorMsg = "No maps available in the collection";
                break;
            default:
                errorMsg = "Unknown Error encountered";
        }

        AlertHandler alert = new AlertHandler(this, errorMsg);
        alert.getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        alert.getWindow().setGravity(Gravity.TOP);
        alert.show();
    }

    void setWatermark(int off)
    {
        Anchor2D anchor = new Anchor2D(0,0);
        Point2D offset = new Point2D(0, off);
        mapView.setWatermarkLocation(anchor, offset);
    }

    // Hide a keyboard.
    public void hideKeyboard() {
        try {
            InputMethodManager imm =
                    (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
            View focusView = getCurrentFocus();
            if (imm != null && focusView != null) {
                imm.hideSoftInputFromWindow(focusView.getWindowToken(), 0);
            }
        } catch (Exception e) {
            Log.d(TAG, e.toString());
        }
    }

    // Tap listener for MapView
    private final TapListener tapListener = origin -> {
            // Redirect the event to the venue tap controller.
            venueTapController.onTap(origin);
    };

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
        if (mapView != null) {
            mapView.getGestures().setTapListener(null);
            mapView.getGestures().setLongPressListener(null);
        }
        if(venueEngine != null) {
            venueEngine.destroy();
        }
        mapView.onDestroy();
        disposeHERESDK();
        mapLoadDone = false;
        super.onDestroy();
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        mapView.onSaveInstanceState(outState);
        super.onSaveInstanceState(outState);
    }
    
    private void disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine sdkNativeEngine = SDKNativeEngine.getSharedInstance();
        if (sdkNativeEngine != null) {
            sdkNativeEngine.dispose();
            // For safety reasons, we explicitly set the shared instance to null to avoid situations,
            // where a disposed instance is accidentally reused.
            SDKNativeEngine.setSharedInstance(null);
        }
        mapLoadDone = false;
    }

    private void removeVenue() {
        recyclerView.setAdapter(new VenueAdapter(getApplicationContext(), venueInfo, this));
        mapLoadDone = false;
        venue_search.setHint("Search for Venues");
        loadMapScene();
        header.setVisibility(View.GONE);
        topologyButton.setVisibility(View.GONE);
        levelSwitcher.setVisible(false);
        drawingSwitcher.setVisible(false);
        VenueMap venueMap = venueEngine.getVenueMap();
        venueMap.removeVenue(venueMap.getSelectedVenue());
    }

    @Override
    public void onBackPressed() {
        if(sheetBehavior.getState() == BottomSheetBehavior.STATE_EXPANDED) {
            sheetBehavior.setState(BottomSheetBehavior.STATE_COLLAPSED);
        }
        else if(mapLoadDone == true) {
            removeVenue();
        }
        else {
            super.onBackPressed();
        }
    }

    public void onVenueItemClicked(VenueInfo venueInfo) {
        progressBar.setVisibility(View.VISIBLE);
        try {
            // Try to parse a venue id.
            final int venueId = venueInfo.getVenueId();
            VenueMap venueMap = venueEngine.getVenueMap();
            Venue selectedVenue = venueMap.getSelectedVenue();
            hideKeyboard();
            if (selectedVenue == null || selectedVenue.getVenueModel().getId() != venueId) {
                // Select a venue by id.
                venueMap.selectVenueAsync(venueId, this ::onVenueLoadError);
            }
            if(sheetBehavior.getState() != BottomSheetBehavior.STATE_COLLAPSED)
                sheetBehavior.setState(BottomSheetBehavior.STATE_COLLAPSED);
        } catch (Exception e) {
            Log.d(TAG, "No Maps Found. " + e.toString());
        }
    }

    public void onSpaceItemClicked(VenueGeometry venueGeometry) {
        venueTapController.selectGeometry(venueGeometry, venueGeometry.getCenter(), true);
        if(sheetBehavior.getState() != BottomSheetBehavior.STATE_COLLAPSED)
            sheetBehavior.setState(BottomSheetBehavior.STATE_COLLAPSED);
    }
}
