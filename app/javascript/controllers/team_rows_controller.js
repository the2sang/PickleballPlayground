import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template"]

  connect() {
    this.nextIndex = this.rowsTarget.querySelectorAll("[data-team-row]").length
  }

  add() {
    const idx = this.nextIndex++
    const clone = this.templateTarget.content.cloneNode(true)
    clone.querySelectorAll("[data-name-template]").forEach(el => {
      el.name = el.dataset.nameTemplate.replace(/__IDX__/g, idx)
    })
    this.rowsTarget.appendChild(clone)
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-team-row]")
    if (this.rowsTarget.querySelectorAll("[data-team-row]").length > 1) {
      row.remove()
    }
  }
}
