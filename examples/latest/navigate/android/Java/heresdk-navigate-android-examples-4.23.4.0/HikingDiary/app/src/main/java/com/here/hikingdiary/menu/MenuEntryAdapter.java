package com.here.hikingdiary.menu;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.here.HikingDiary.R;

import java.util.List;

public class MenuEntryAdapter extends RecyclerView.Adapter<MenuEntryAdapter.MenuEntryViewHolder> {

    private List<MenuEntry> menuEntries;
    private OnMenuEntryClickListener onMenuEntryClickListener;
    OnMenuEntryDeleteListener onMenuEntryDeleteListener;

    public MenuEntryAdapter(List<MenuEntry> menuEntries, OnMenuEntryClickListener onMenuEntryClickListener, OnMenuEntryDeleteListener onMenuEntryDeleteListener) {
        this.menuEntries = menuEntries;
        this.onMenuEntryClickListener = onMenuEntryClickListener;
        this.onMenuEntryDeleteListener = onMenuEntryDeleteListener;
    }

    @NonNull
    @Override
    public MenuEntryViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.menu_item, parent, false);
        return new MenuEntryViewHolder(view, onMenuEntryClickListener, onMenuEntryDeleteListener);
    }

    @Override
    public void onBindViewHolder(@NonNull MenuEntryViewHolder holder, int position) {
        holder.bind(menuEntries.get(position));
    }

    @Override
    public int getItemCount() {
        return menuEntries.size();
    }

    static class MenuEntryViewHolder extends RecyclerView.ViewHolder {
        private TextView descriptionTextView;
        OnMenuEntryClickListener onMenuEntryClickListener;
        OnMenuEntryDeleteListener onMenuEntryDeleteListener;

        public MenuEntryViewHolder(@NonNull View itemView, OnMenuEntryClickListener onMenuEntryClickListener, OnMenuEntryDeleteListener onMenuEntryDeleteListener) {
            super(itemView);
            descriptionTextView = itemView.findViewById(R.id.menu_item_description);

            this.onMenuEntryClickListener = onMenuEntryClickListener;
            this.onMenuEntryDeleteListener = onMenuEntryDeleteListener;

            // OnClick listener for loading the entry.
            itemView.setOnClickListener(v -> {
                if (onMenuEntryClickListener != null) {
                    int position = getAdapterPosition();
                    if (position != RecyclerView.NO_POSITION) {
                        onMenuEntryClickListener.onMenuEntryClick(position);
                    }
                }
            });

            // onLongClick listener for deleting the entry.
            itemView.setOnLongClickListener(v -> {
                if (onMenuEntryDeleteListener != null) {
                    int position = getAdapterPosition();
                    if (position != RecyclerView.NO_POSITION) {
                        onMenuEntryDeleteListener.onMenuEntryDelete(position);
                    }
                }
                return true;
            });
        }

        public void bind(MenuEntry menuEntry) {
            descriptionTextView.setText(menuEntry.getText());
        }
    }

    public interface OnMenuEntryClickListener {
        void onMenuEntryClick(int position);
    }

    public interface OnMenuEntryDeleteListener {
        void onMenuEntryDelete(int position);
    }
}
