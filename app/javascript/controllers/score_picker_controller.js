import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  select(event) {
    this.inputTarget.value = event.params.value
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus({ preventScroll: true })
  }
}
