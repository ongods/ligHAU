# Campus map data

The campus map uses MapLibre with MapTiler vector tiles. Internet access
is needed for the basemap; facility outlines are bundled with the application.
Visible text credits link to MapTiler and OpenStreetMap.

Set `MAPTILER_KEY` in `.env`, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/sync-map-config.ps1
flutter run -d chrome
```

The setup command writes only the browser map key and style ID to the git-ignored
`assets/config/map.local.json` fallback used by plain Chrome launches. Re-run it
and restart after changing `.env`. Explicit Dart defines take precedence.
The VS Code launch configuration uses the generated public map asset;
the complete `.env` file is never passed to Flutter.
GitHub Pages builds use the `MAPTILER_KEY` repository
secret. Restrict the browser key's allowed origins in MapTiler Cloud to localhost
and your deployed site.

The graphic logo is omitted; this requires a paid MapTiler plan. Text attribution
remains visible. See https://docs.maptiler.com/guides/map-design/attribution/add-attribution/.

`assets/data/hau_osm.json` contains 17 explicitly matched building outlines from
the OSM API extract downloaded on 2026-10-04:
https://www.openstreetmap.org/api/0.6/map?bbox=120.588,15.130,120.594,15.137

Each record stores the facility directory name, original OSM name, OSM way ID,
and latitude/longitude pairs. Pins use outline bounding-box midpoints, not
surveyed entrances. Source data is © OpenStreetMap contributors, ODbL 1.0;
it is separate from the repository's MIT-licensed code.

Five directory entries have no confirmed match: Plaza De Corazon, Yellow Food
Court, Geromin G. Nepomuceno, Sister Josefina Nepomuceno Formation Center, and
the aggregate Campus Parking Areas entry. They remain searchable and selectable
with an awaiting-coordinates label. Angel Food Court was not assumed to be
Yellow Food Court. Add verified geometry to the JSON to display these locations.

Building details, prototype hours, and unknown floor counts remain sourced from
the existing facility directory. OSM geometry does not verify those details.
Directions are not implemented by this map integration.

Set `MAPTILER_STYLE_ID` to choose a custom MapTiler style. The default is
`streets-v4`, with campus colors and facility icons applied by the app.
The map preserves road and walking-path styling, trees, crossings, and nearby
landmarks. Facility labels appear from zoom 17, and the 17 verified outlines
are drawn as selectable footprints with a highlighted selected facility.
The map does not offer tile prefetching or offline downloads.
