package com.here.hikingdiary.menu;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.ItemTouchHelper;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.here.HikingDiary.R;

import java.util.ArrayList;
import java.util.List;

public class MenuActivity extends AppCompatActivity {

    public static final String CLICKED_INDEX_KEY = "clickedIndex";
    public static final String DELETE_INDEX_KEY = "deleteIndex";
    private MenuEntryAdapter adapter;
    private RecyclerView recyclerView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.diary_screen);
        // Add your menu entries to this list
        Bundle bundle = getIntent().getExtras();
        ArrayList<String> keys = new ArrayList<>((ArrayList) bundle.getStringArrayList("key_names"));
        ArrayList<String> descriptions = new ArrayList<>((ArrayList) bundle.getStringArrayList("key_descriptions"));

        List<MenuEntry> menuEntries = new ArrayList<>();

        for (int i = 0; i <= keys.size() - 1; i++) {
            menuEntries.add(new MenuEntry(keys.get(i), descriptions.get(i)));
        }

        adapter = new MenuEntryAdapter(menuEntries,
                position -> {
                    // Handle menu entry click
                    Log.d("MENU clicked:", menuEntries.get(position).getKey());
                    onItemClicked(position, false);
                },
                position -> {
                    // Handle menu entry delete
                    onItemClicked(position, true);
                    menuEntries.remove(position);
                    adapter.notifyItemRemoved(position);
                });

        setupRecyclerView();
        setupSwipeToDeleteCallback();
    }

    private void setupRecyclerView() {
        recyclerView = findViewById(R.id.recycler_view);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        recyclerView.setAdapter(adapter);
    }
    private void setupSwipeToDeleteCallback() {
        SwipeToDeleteCallback swipeToDeleteCallback = new SwipeToDeleteCallback(0, ItemTouchHelper.LEFT, adapter);
        ItemTouchHelper itemTouchHelper = new ItemTouchHelper(swipeToDeleteCallback);
        itemTouchHelper.attachToRecyclerView(recyclerView);
    }
    private void onItemClicked(int position, boolean isIndexToBeDeleted) {
        Intent resultIntent = new Intent();
        resultIntent.putExtra(CLICKED_INDEX_KEY, position);
        resultIntent.putExtra(DELETE_INDEX_KEY, isIndexToBeDeleted);
        setResult(Activity.RESULT_OK, resultIntent);
        finish();
    }
}

