# App Store screenshots

PNG captures of the real CinéTransat UI for [App Store Connect](https://appstoreconnect.apple.com).

## Included sets

| Folder | Device | Portrait size | App Store slot |
|--------|--------|---------------|----------------|
| `iPhone-6.9/` | iPhone 17 Pro Max | 1320 × 2868 | **6.9" display** (required for iPhone) |
| `iPad-13/` | iPad Pro 13-inch (M5) | 2064 × 2752 | **13" iPad** (required for universal apps) |

Apple scales the largest iPhone set down for smaller phones. You do not need separate exports for every device size unless you want custom crops.

## Files

| File | Screen |
|------|--------|
| `01-program.png` → `program.png` | Programme tab, week 1 with posters |
| `detail.png` | Film detail (E.T.) |
| `watchlist.png` | Watch list with sample films |
| `info.png` | Practical info |
| `settings.png` | Settings (language, notifications) |

## Regenerate

```bash
chmod +x scripts/capture_app_store_screenshots.sh
./scripts/capture_app_store_screenshots.sh
```

Optional environment variables:

- `IPHONE_DEVICE` — default `iPhone 17 Pro Max`
- `IPAD_DEVICE` — default `iPad Pro 13-inch (M5)`
- `CAPTURE_IPAD=0` — skip iPad captures

Screenshot mode uses bundled 2025 programme data (no Firebase splash) and a clean 9:41 status bar.

## Upload order (suggested)

1. Programme — hero shot with posters  
2. Detail — synopsis and screening info  
3. Watch list — personal planning  
4. Info — venue / weather context  
5. Settings — notifications and language  

App Store Connect accepts up to 10 screenshots per device size; add more weeks or the Festival tab if you like.
