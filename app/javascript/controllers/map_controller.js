import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["map"];
  static values = { locations: Object };

  connect() {
    this.map = new maplibregl.Map({
      container: this.mapTarget,
      style: "https://tiles.openfreemap.org/styles/liberty",
      center: [13.33, 47.33],
      zoom: 7,
    });

    this.map.on("load", () => {
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

  #showPopup(feature) {
    const props = feature.properties;
    const coords = feature.geometry.coordinates.slice();

    new maplibregl.Popup({ className: "location-popup", closeButton: false })
      .setLngLat(coords)
      .setHTML(
        `<div class="px-3 py-2">
          <p class="font-semibold text-gray-900 text-sm">${props.name}</p>
          <p class="text-xs text-gray-500 mt-1">${props.latitude}, ${props.longitude}</p>
        </div>`,
      )
      .addTo(this.map);
  }

  #addLocations() {
    if (this.map.getSource("locations")) {
      this.map.getSource("locations").setData(this.locationsValue);
    } else {
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
          "circle-color": "#2563eb",
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
}
