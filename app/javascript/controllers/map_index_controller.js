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
  }

  disconnect() {
    this.map?.remove();
  }

  locationsValueChanged() {
    if (!this.map?.isStyleLoaded()) return;
    this.#addLocations();
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

      this.map.on("click", "locations-circle", (e) => {
        const props = e.features[0].properties;
        const coords = e.features[0].geometry.coordinates.slice();

        new maplibregl.Popup()
          .setLngLat(coords)
          .setHTML(
            `
            <strong>${props.name}</strong><br>
            Lat: ${props.latitude.toFixed(6)}<br>
            Lng: ${props.longitude.toFixed(6)}
          `,
          )
          .addTo(this.map);
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
