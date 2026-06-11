import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["inputs", "submit"]

  connect() {
    this.selectedIds = new Set()
    this.sync()
  }

  toggle(event) {
    const button = event.currentTarget
    const teamId = String(event.params.teamId)

    if (this.selectedIds.has(teamId)) {
      this.selectedIds.delete(teamId)
      this.markUnselected(button)
    } else {
      this.selectedIds.add(teamId)
      this.markSelected(button)
    }

    this.sync()
  }

  sync() {
    this.inputsTarget.innerHTML = Array.from(this.selectedIds).map((teamId) => (
      `<input type="hidden" name="advancing_team_ids[]" value="${teamId}">`
    )).join("")

    const hasSelection = this.selectedIds.size > 0
    this.submitTarget.disabled = !hasSelection
    this.submitTarget.setAttribute("aria-disabled", String(!hasSelection))
    this.submitTarget.style.opacity = hasSelection ? "1" : ".55"
    this.submitTarget.style.cursor = hasSelection ? "pointer" : "not-allowed"
  }

  markSelected(button) {
    button.textContent = "선택됨"
    button.setAttribute("aria-pressed", "true")
    button.classList.remove("btn--secondary")
    button.classList.add("btn--primary")
  }

  markUnselected(button) {
    button.textContent = "진출 선택"
    button.setAttribute("aria-pressed", "false")
    button.classList.remove("btn--primary")
    button.classList.add("btn--secondary")
  }
}
