import { Controller } from "@hotwired/stimulus"

// The button that validates the choice of the preview space, inactive until a
// choice is made. Without JavaScript it stays active, and the server refuses an
// empty choice and says so.
export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.submitTarget.disabled = !this.element.querySelector('input[type="radio"]:checked')
  }

  enable() {
    this.submitTarget.disabled = false
  }
}
