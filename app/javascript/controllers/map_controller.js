import { Controller } from "@hotwired/stimulus";

// One fill colour per Austrian state code.
// Chosen to be distinct, medium-saturation, and readable over a light basemap.
const STATE_COLORS = {
  AT1: "#e07b54", // Burgenland
  AT2: "#6db56d", // Kärnten
  AT3: "#5b9bd5", // Niederösterreich
  AT4: "#e8a838", // Oberösterreich
  AT5: "#9b6bbf", // Salzburg
  AT6: "#d45f8a", // Steiermark
  AT7: "#4bb8b8", // Tirol
  AT8: "#7a9e5a", // Vorarlberg
  AT9: "#e05c5c", // Wien
};

const STATE_COLOR_EXPRESSION = [
  "match",
  ["get", "code"],
  "AT1",
  "#e07b54", // Burgenland
  "AT2",
  "#6db56d", // Kärnten
  "AT3",
  "#5b9bd5", // Niederösterreich
  "AT4",
  "#e8a838", // Oberösterreich
  "AT5",
  "#9b6bbf", // Salzburg
  "AT6",
  "#d45f8a", // Steiermark
  "AT7",
  "#4bb8b8", // Tirol
  "AT8",
  "#7a9e5a", // Vorarlberg
  "AT9",
  "#e05c5c", // Wien
  "#aaaaaa", // fallback
];

export default class extends Controller {
  static targets = ["map"];
  static values = { locations: Object, states: Object, centroids: Object };

  connect() {
    this.map = new maplibregl.Map({
      container: this.mapTarget,
      style: "https://tiles.openfreemap.org/styles/liberty",
      center: [13.33, 47.33],
      zoom: 7,
    });

    this.map.on("load", () => {
      this.#addStates();
      this.#addCentroids();
      this.#addLocations();
    });

    this.map.doubleClickZoom.disable();

    this.map.on("click", (e) => {
      const features = this.map.queryRenderedFeatures(e.point, {
        layers: ["locations-circle"],
      });

      if (features.length) {
        this.#showPopup(features[0]);
      }
    });

    this.map.on("dblclick", (e) => {
      const features = this.map.queryRenderedFeatures(e.point, {
        layers: ["locations-circle"],
      });

      if (!features.length) {
        this.dispatch("click", {
          detail: { lat: e.lngLat.lat, lng: e.lngLat.lng },
        });
      }
    });
  }

  disconnect() {
    this.map?.remove();
  }

  locationsValueChanged() {
    if (!this.map?.isStyleLoaded()) return;
    this.#addLocations();
  }

  statesValueChanged() {
    if (!this.map?.isStyleLoaded()) return;
    this.#addStates();
  }

  centroidsValueChanged() {
    if (!this.map?.isStyleLoaded()) return;
    this.#addCentroids();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  #showPopup(feature) {
    const props = feature.properties;
    const coords = feature.geometry.coordinates.slice();

    const distanceKm =
      props.distance_to_centroid != null
        ? `${(props.distance_to_centroid / 1000).toFixed(1)} km`
        : "—";

    const stateColor = STATE_COLORS[props.state_code];

    const stateInfo =
      props.state_name != null
        ? `<span class="inline-flex items-center gap-2"><span class="inline-block h-2.5 w-2.5 rounded-full" style="background:${stateColor};"></span><span>${props.state_name}</span></span>`
        : `<span class="italic text-gray-500">Outside Austria</span>`;

    new maplibregl.Popup({ className: "location-popup", closeButton: false })
      .setLngLat(coords)
      .setHTML(
        `<div class="min-w-72 px-4 py-3">
          <p class="text-lg font-semibold text-gray-900">${props.name}</p>
          <div class="mt-3 grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
            <div class="text-left text-gray-500">Lat</div>
            <div class="text-left text-gray-900">${props.latitude}</div>

            <div class="text-left text-gray-500">Lng</div>
            <div class="text-left text-gray-900">${props.longitude}</div>

            <div class="text-left text-gray-500">State</div>
            <div class="text-left text-gray-900">${stateInfo}</div>

            <div class="text-left text-gray-500">Distance to centroid</div>
            <div class="text-left text-gray-900">${distanceKm}</div>
          </div>
        </div>`,
      )
      .addTo(this.map);
  }

  #addStates() {
    this.map.addSource("states", { type: "geojson", data: this.statesValue });

    this.map.addLayer({
      id: "states-fill",
      type: "fill",
      source: "states",
      paint: {
        "fill-color": STATE_COLOR_EXPRESSION,
        "fill-opacity": 0.15,
      },
    });

    this.map.addLayer({
      id: "states-outline",
      type: "line",
      source: "states",
      paint: {
        "line-color": STATE_COLOR_EXPRESSION,
        "line-width": 2,
        "line-opacity": 0.8,
      },
    });
  }

  #addCentroids() {
    if (this.map.getSource("centroids")) {
      this.map.getSource("centroids").setData(this.centroidsValue);
      return;
    }

    this.map.addSource("centroids", {
      type: "geojson",
      data: this.centroidsValue,
    });

    this.map.addLayer({
      id: "centroids-halo",
      type: "circle",
      source: "centroids",
      paint: {
        "circle-radius": 9,
        "circle-color": "#ffffff",
        "circle-opacity": 0.9,
      },
    });

    this.map.addLayer({
      id: "centroids-dot",
      type: "circle",
      source: "centroids",
      paint: {
        "circle-radius": 5,
        "circle-color": STATE_COLOR_EXPRESSION,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#ffffff",
        "circle-opacity": 1,
      },
    });
  }

  #addLocations() {
    if (this.map.getSource("locations")) {
      this.map.getSource("locations").setData(this.locationsValue);
      return;
    }

    this.map.addSource("locations", {
      type: "geojson",
      data: this.locationsValue,
    });

    this.map.addLayer({
      id: "locations-circle",
      type: "circle",
      source: "locations",
      paint: {
        "circle-radius": 8,
        "circle-color": "#1e3a5f",
        "circle-stroke-width": 2,
        "circle-stroke-color": "#ffffff",
      },
    });

    this.map.on("mouseenter", "locations-circle", () => {
      this.map.getCanvas().style.cursor = "pointer";
    });

    this.map.on("mouseleave", "locations-circle", () => {
      this.map.getCanvas().style.cursor = "";
    });
  }
}
