import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "copyIcon", "checkIcon"]

  copy() {
    const rawText = this.sourceTarget.dataset.clipboardText || this.sourceTarget.textContent.trim()
    const numbersOnly = rawText.replace(/\D/g, '')
    navigator.clipboard.writeText(numbersOnly).then(() => {
      this.copyIconTarget.hidden = true
      this.checkIconTarget.hidden = false
      setTimeout(() => {
        this.copyIconTarget.hidden = false
        this.checkIconTarget.hidden = true
      }, 1500)
    })
  }
}
