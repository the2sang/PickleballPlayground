import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    if (this.hasContentTarget) {
      this.contentTarget.hidden = !this.contentTarget.hidden
    } else {
      const panel = document.getElementById("memo-new-panel")
      if (panel) panel.hidden = !panel.hidden
    }
  }
}
