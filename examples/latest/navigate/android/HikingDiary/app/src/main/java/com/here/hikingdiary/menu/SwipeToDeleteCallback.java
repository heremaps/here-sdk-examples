package com.here.hikingdiary.menu;

import android.graphics.Canvas;
import android.graphics.Color;
import androidx.annotation.NonNull;
import androidx.cardview.widget.CardView;
import androidx.recyclerview.widget.ItemTouchHelper;
import androidx.recyclerview.widget.RecyclerView;

public class SwipeToDeleteCallback extends ItemTouchHelper.SimpleCallback {
    private final MenuEntryAdapter adapter;
    public SwipeToDeleteCallback(int dragDirs, int swipeDirs, MenuEntryAdapter adapter) {
        super(dragDirs, swipeDirs);
        this.adapter = adapter;
    }

    @Override
    public boolean onMove(@NonNull RecyclerView recyclerView, @NonNull RecyclerView.ViewHolder viewHolder, @NonNull RecyclerView.ViewHolder target) {
        return false;
    }

    @Override
    public void onSwiped(@NonNull RecyclerView.ViewHolder viewHolder, int direction) {
        // Handle swipe action - delete item.
        int position = viewHolder.getAdapterPosition();
        adapter.onMenuEntryDeleteListener.onMenuEntryDelete(position);
    }

    @Override
    public void onChildDraw(@NonNull Canvas c, @NonNull RecyclerView recyclerView, @NonNull RecyclerView.ViewHolder viewHolder, float dX, float dY, int actionState, boolean isCurrentlyActive) {
        super.onChildDraw(c, recyclerView, viewHolder, dX, dY, actionState, isCurrentlyActive);

        float alpha = 1 - Math.abs(dX) / (float) viewHolder.itemView.getWidth();

        // Assuming your CardView is the root view of your ViewHolder
        CardView cardView = (CardView) viewHolder.itemView;
        int color = Color.argb((int) (alpha * 255), 255, 255, 255);
        int color2 = Color.MAGENTA;
        cardView.setCardBackgroundColor(color2);
    }
}