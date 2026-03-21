import { Controller } from "@hotwired/stimulus";

// One fill colour per Austrian state code.
// Chosen to be distinct, medium-saturation, and readable over a light basemap.
const STATE_COLORS = {
  AT1: "#e07b54", // Burgenland     – terracotta
  AT2: "#6db56d", // Kärnten        – sage green
  AT3: "#5b9bd5", // Niederösterreich – steel blue
  AT4: "#e8a838", // Oberösterreich – amber
  AT5: "#9b6bbf", // Salzburg       – lavender
  AT6: "#d45f8a", // Steiermark     – rose
  AT7: "#4bb8b8", // Tirol          – teal
  AT8: "#7a9e5a", // Vorarlberg     – moss green
  AT9: "#e05c5c", // Wien           – red
};

// Build a MapLibre `match` expression that maps code → colour.
function stateColorExpression(fallback = "#aaaaaa") {
  const expr = ["match", ["get", "code"]];
  for (const [code, color] of Object.entries(STATE_COLORS)) {
    expr.push(code, color);
  }
  expr.push(fallback);
  return expr;
}

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
        ? (props.distance_to_centroid / 1000).toFixed(1) + " km"
        : "—";

    const stateColor =
      props.state_code != null
        ? (STATE_COLORS[props.state_code] ?? "#555")
        : "#555";

    const stateInfo =
      props.state_name != null
        ? `<tr>
             <td class="pr-2 text-gray-500">State</td>
             <td>
               <span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:${stateColor};margin-right:4px;vertical-align:middle;"></span>
               ${props.state_name}
             </td>
           </tr>
           <tr>
             <td class="pr-2 text-gray-500">Distance&nbsp;to&nbsp;centroid</td>
             <td>${distanceKm}</td>
           </tr>`
        : `<tr><td colspan="2" class="text-gray-400 italic">Outside all states</td></tr>`;

    new maplibregl.Popup({ className: "location-popup", closeButton: false })
      .setLngLat(coords)
      .setHTML(
        `<strong class="block mb-1">${props.name}</strong>
         <table class="text-sm">
           <tr><td class="pr-2 text-gray-500">Lat</td><td>${props.latitude}</td></tr>
           <tr><td class="pr-2 text-gray-500">Lng</td><td>${props.longitude}</td></tr>
           ${stateInfo}
         </table>`,
      )
      .addTo(this.map);
  }

  #addStates() {
    if (this.map.getSource("states")) {
      this.map.getSource("states").setData(this.statesValue);
      return;
    }

    this.map.addSource("states", {
      type: "geojson",
      data: this.statesValue,
    });

    // Per-state colour fill, low opacity so the basemap shows through.
    this.map.addLayer({
      id: "states-fill",
      type: "fill",
      source: "states",
      paint: {
        "fill-color": stateColorExpression(),
        "fill-opacity": 0.15,
      },
    });

    // Outline in the same hue but darker / more opaque.
    this.map.addLayer({
      id: "states-outline",
      type: "line",
      source: "states",
      paint: {
        "line-color": stateColorExpression(),
        "line-width": 2,
        "line-opacity": 0.8,
      },
    });

    // State name labels, coloured to match each state.
    this.map.addLayer({
      id: "states-label",
      type: "symbol",
      source: "states",
      layout: {
        "text-field": ["get", "name"],
        "text-size": 12,
        "text-font": ["Noto Sans Regular"],
        "text-anchor": "center",
      },
      paint: {
        "text-color": stateColorExpression("#555555"),
        "text-halo-color": "#ffffff",
        "text-halo-width": 1.5,
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

    // Outer ring – white halo for contrast.
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

    // Inner dot in the state's own colour with a thick stroke.
    this.map.addLayer({
      id: "centroids-dot",
      type: "circle",
      source: "centroids",
      paint: {
        "circle-radius": 5,
        "circle-color": stateColorExpression(),
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
