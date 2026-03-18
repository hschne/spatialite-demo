import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "map",
    "latitude",
    "longitude",
    "coordinatesDisplay",
    "coordinatesText",
  ];

  connect() {
    this.marker = null;

    this.map = new maplibregl.Map({
      container: this.mapTarget,
      style: "https://tiles.openfreemap.org/styles/liberty",
      center: [13.33, 47.33],
      zoom: 7,
    });

    this.map.on("click", (e) => {
      this.#placeMarker(e.lngLat.lng, e.lngLat.lat);
    });
  }

  disconnect() {
    this.map?.remove();
  }

  #placeMarker(lng, lat) {
    if (this.marker) {
      this.marker.setLngLat([lng, lat]);
    } else {
      this.marker = new maplibregl.Marker({ color: "#2563eb" })
        .setLngLat([lng, lat])
        .addTo(this.map);
    }

    this.latitudeTarget.value = lat.toFixed(6);
    this.longitudeTarget.value = lng.toFixed(6);

    this.coordinatesDisplayTarget.classList.remove("hidden");
    this.coordinatesTextTarget.textContent = `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
  }
}
