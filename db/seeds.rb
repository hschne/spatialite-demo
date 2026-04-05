# =============================================================================
# Austrian States – import from ~/Downloads/at.json
# =============================================================================
# The file is a GeoJSON FeatureCollection with 9 Austrian state polygons
# (and one MultiPolygon: Tirol). Each feature has properties:
#   { "id" => "AT7", "name" => "Tirol", "source" => "https://simplemaps.com" }
#
# Run: bin/rails db:seed
# Idempotent: existing states are updated; no duplicates are created.

geojson_path = Rails.root.join("db/seeds/at.json")
collection = JSON.parse(File.read(geojson_path))

collection["features"].each do |feature|
  props = feature["properties"]

  state = State.find_or_initialize_by(code: props["id"])
  state.name = props["name"]
  state.geometry_json = feature["geometry"].to_json
  state.save!
end
