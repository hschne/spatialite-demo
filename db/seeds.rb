# =============================================================================
# Austrian States – import from ~/Downloads/at.json
# =============================================================================
# The file is a GeoJSON FeatureCollection with 9 Austrian state polygons
# (and one MultiPolygon: Tirol). Each feature has properties:
#   { "id" => "AT7", "name" => "Tirol", "source" => "https://simplemaps.com" }
#
# Run: bin/rails db:seed
# Idempotent: existing states are updated; no duplicates are created.

geojson_path = File.expand_path("~/Downloads/at.json")

if File.exist?(geojson_path)
  puts "Importing Austrian states from #{geojson_path}…"
  collection = JSON.parse(File.read(geojson_path))

  collection["features"].each do |feature|
    props = feature["properties"]
    code = props["id"]
    name = props["name"]
    geometry = feature["geometry"].to_json

    state = State.find_or_initialize_by(code: code)
    state.name = name
    state.save!(validate: false) # save first so we have an id

    # Store the geometry via SpatiaLite's GeomFromGeoJSON, preserving SRID 4326.
    State.connection.execute(
      State.sanitize_sql_array([
        "UPDATE states SET geometry = SetSRID(GeomFromGeoJSON(?), 4326) WHERE id = ?",
        geometry,
        state.id
      ])
    )

    puts "  #{code}: #{name}"
  end

  puts "Done. #{State.count} state(s) in database."
else
  puts "Skipping state import: #{geojson_path} not found."
end
