import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "latitude", "longitude", "name"];

  open({ detail: { lat, lng } }) {
    this.latitudeTarget.value = lat.toFixed(6);
    this.longitudeTarget.value = lng.toFixed(6);
    this.nameTarget.value = "";
    this.dialogTarget.showModal();
  }

  close() {
    this.dialogTarget.close();
    this.latitudeTarget.value = "";
    this.longitudeTarget.value = "";
    this.nameTarget.value = "";
  }
}
