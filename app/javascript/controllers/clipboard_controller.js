import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values  = { successText: { type: String, default: "복사됨!" } }

  copy() {
    const text = this.sourceTarget.dataset.clipboardText || this.sourceTarget.textContent.trim()
    navigator.clipboard.writeText(text).then(() => {
      const original = this.buttonTarget.textContent
      this.buttonTarget.textContent = this.successTextValue
      setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
    })
  }
}
