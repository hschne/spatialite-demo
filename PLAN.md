# Part 2 Spatial Queries Demo

## Goal

Extend the current SpatiaLite demo from "points on a map" into the blog post's part 2: import Austrian state polygons, render them, and demonstrate real spatial queries with point-in-polygon lookup plus distance-to-centroid calculations. The result should stay small and blog-friendly while making the difficult SpatiaLite pieces concrete in code.

## Tasks

1. **Fix SpatiaLite initialization and test infrastructure**
   - File: `lib/active_record/spatialite.rb` (new - port from MapIt)
   - File: `lib/tasks/spatialite.rake` (new - port from MapIt)
   - File: `config/initializers/spatialite.rb` (modify - add `truncate_tables` protection)
   - File: `test/test_helper.rb` (modify - add `parallelize_setup` with `Spatialite.connect`)
   - Changes:
     - Add `lib/active_record/spatialite.rb` with `init` and `connect` methods that call `InitSpatialMetadata(1)` with a guard to check if `spatial_ref_sys` is already populated. Port directly from MapIt.
     - Add `lib/tasks/spatialite.rake` to hook `db:create` and `db:test:prepare` so spatial metadata is initialized automatically on fresh databases. Port from MapIt.
     - In `config/initializers/spatialite.rb`, add the `truncate_tables` monkey-patch that excludes `spatial_ref_sys` from truncation during parallel test worker reset. Without this, parallel tests empty the 6559 SRID rows and geodesic `Distance(..., 1)` returns NULL.
     - In `test/test_helper.rb`, add `parallelize_setup { ActiveRecord::Spatialite.connect }` so per-worker test databases get their spatial metadata initialized.
   - Acceptance:
     - `bin/rails db:create` automatically initializes spatial metadata.
     - `bin/rails db:test:prepare` initializes spatial metadata for the test database.
     - Parallel tests do not lose `spatial_ref_sys` data between runs.
     - `Distance(..., 1)` returns real meter values in tests.

2. **Add a `State` model and database table**
   - File: `db/migrate/<timestamp>_create_states.rb`
   - File: `app/models/state.rb`
   - Changes:
     - Create a `states` table with stable identifiers for the imported dataset (`code`, `name`) plus a `geometry` column.
     - Add model-level validations for presence/uniqueness.
     - Add model helpers to serialize state geometry as GeoJSON and expose a feature collection for the map.
   - Acceptance:
     - `State` records can be created with a geometry blob.
     - `State.to_feature_collection` returns valid GeoJSON for all imported states.

3. **Implement GeoJSON import for Austrian states from `~/Downloads/at.json`**
   - File: `db/seeds.rb`
   - Optional helper file: `app/services/state_geojson_importer.rb` or `lib/...` if needed
   - Changes:
     - Parse the GeoJSON feature collection from `~/Downloads/at.json`.
     - Import all 9 states idempotently using `properties.id` and `properties.name`.
     - Convert GeoJSON geometry into SpatiaLite geometry with SRID 4326.
     - Handle both `Polygon` and `MultiPolygon` features cleanly.
   - Acceptance:
     - `bin/rails db:seed` imports 9 Austrian states.
     - Re-running seeds does not duplicate states.
     - Tirol imports successfully despite being a `MultiPolygon`.

4. **Add spatial query helpers for containment and centroid distance**
   - File: `app/models/location.rb`
   - File: `app/models/state.rb`
   - Changes:
     - Add a query to find the state containing a location point.
     - Add helpers to compute a state centroid and serialize it when needed.
     - Add a helper to calculate the distance from a location to the containing state's centroid.
     - Expose these values in a way the controller/view can pass through to the UI.
   - Acceptance:
     - For a saved location, the app can determine its containing Austrian state.
     - The app can compute a distance value for that location to the state centroid.
     - Queries work against SRID 4326 geometries.

5. **Extend the index page to send state polygons and enriched location data to the frontend**
   - File: `app/controllers/locations_controller.rb`
   - File: `app/views/locations/index.html.erb`
   - Changes:
     - Load both `@locations_geojson` and `@states_geojson`.
     - Enrich location feature properties with the containing state name/code and centroid-distance info.
     - Pass both datasets to the map Stimulus controller via `data-*` values.
   - Acceptance:
     - Index renders without errors when both locations and states exist.
     - The page has all data needed to show polygons and query results without extra requests.

6. **Render Austrian states and richer point popups on the map**
   - File: `app/javascript/controllers/map_index_controller.js`
   - Changes:
     - Add a GeoJSON source/layer pair for state polygons.
     - Style state fill/outline so polygons are visible but don't overpower location markers.
     - Update point popups to show:
       - location name
       - coordinates
       - containing state
       - distance to centroid
     - Optionally fit bounds or otherwise ensure the Austria map framing still looks good.
   - Acceptance:
     - The index map displays both state polygons and saved locations.
     - Clicking a location reveals the point-in-polygon result and centroid-distance output.

7. **Keep seeds/demo flow easy to run and verify**
   - File: `db/seeds.rb`
   - Changes:
     - Make sure the app can be bootstrapped with migrations + seeds in one obvious flow.
     - Keep the import logic simple enough to support the blog post and future draft updates.
   - Acceptance:
     - A fresh setup can run migrations, seed states, create a location, and see spatial results on the index map.

8. **Add automated tests for spatial queries**
   - File: `test/models/location_test.rb` (new)
   - File: `test/models/state_test.rb` (new)
   - Changes:
     - Test point-in-polygon: a location inside Wien returns Wien as its containing state.
     - Test point-in-polygon: a location outside all states returns nil.
     - Test distance-to-centroid: returns a plausible meter value for a known location.
     - Test `State.to_feature_collection` returns valid GeoJSON with all states.
     - Test `Location.to_geojson` includes state name and distance in properties when enriched.
     - Geometry setup in tests: create records with lat/lng (triggers `after_save :update_geometry` for locations); for states, insert geometry via raw SQL with `GeomFromGeoJSON(?)` bind params in test setup rather than fixtures (fixtures can't store SpatiaLite geometry blobs).
   - Acceptance:
     - `bin/rails test` passes with parallel workers.
     - Spatial queries return correct results in test environment.

## Files to Modify

- `app/models/location.rb` — add state lookup and centroid-distance helpers, enrich GeoJSON properties
- `app/controllers/locations_controller.rb` — load/publish state and enriched location GeoJSON
- `app/views/locations/index.html.erb` — pass state data to Stimulus
- `app/javascript/controllers/map_index_controller.js` — render state polygons and richer popups
- `db/seeds.rb` — import Austrian state GeoJSON from `~/Downloads/at.json`
- `config/initializers/spatialite.rb` — add `truncate_tables` protection for `spatial_ref_sys`
- `test/test_helper.rb` — add `parallelize_setup` with `Spatialite.connect`

## New Files

- `lib/active_record/spatialite.rb` — SpatiaLite init/connect helpers (ported from MapIt)
- `lib/tasks/spatialite.rake` — rake hooks for `db:create` and `db:test:prepare` (ported from MapIt)
- `db/migrate/<timestamp>_create_states.rb` — create `states` table
- `app/models/state.rb` — state geometry, GeoJSON serialization, spatial query helpers
- `test/models/location_test.rb` — spatial query tests for locations
- `test/models/state_test.rb` — spatial query tests for states

## What We're NOT Doing

- No incremental checkpoint branches or multi-commit tutorial scaffolding.
- No admin UI for importing or editing states.
- No generalized shapefile/GeoJSON ingestion framework.
- No production-hardening for arbitrary external datasets.
- No extra blog post editing yet; this is about implementing the demo app that part 2 will describe.
- No separate service object for the GeoJSON importer — inline in seeds is fine for a demo.

## Risks & Edge Cases

- `~/Downloads/at.json` contains both `Polygon` and `MultiPolygon`; import must support both.
- SpatiaLite geometry creation must preserve SRID 4326 or centroid/distance functions may behave incorrectly.
- **`spatial_ref_sys` must be initialized** — geodesic `Distance(..., 1)` returns NULL without it. The current app has no `InitSpatialMetadata` call anywhere. Task 1 fixes this.
- **`spatial_ref_sys` must be protected from truncation** — Rails parallel test workers call `truncate_tables` which empties it. The `truncate_tables` patch in task 1 prevents this. This is the exact issue documented in MapIt's `26-03-18-spatialite-parallel-tests.md`.
- Distance output is in **meters** (geodesic via `Distance(geom1, geom2, 1)`). UI should format as km.
- Point-in-polygon semantics near borders can be tricky (`Within` vs `Contains` vs `Intersects`); `Contains()` is the right choice — "does this state polygon contain this point?"
- Seeds should be idempotent so repeated setup doesn't create duplicate state rows.
- Test geometry setup must use raw SQL or model callbacks, not fixtures — fixtures can't populate SpatiaLite geometry blobs.
