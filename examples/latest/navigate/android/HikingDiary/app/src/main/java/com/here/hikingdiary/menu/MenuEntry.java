package com.here.hikingdiary.menu;

public class MenuEntry {
    private String key;
    private String text;

    public MenuEntry(String key, String text) {
        this.key = key;
        this.text = text;
    }

    public String getKey() {
        return key;
    }

    public String getText() {
        return text;
    }
}
