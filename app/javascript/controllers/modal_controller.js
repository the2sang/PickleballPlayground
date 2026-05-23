import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { autoOpen: Boolean }

  connect() {
    if (this.autoOpenValue) this.open()
  }

  open() {
    if (this.dialogTarget.open) return
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
