import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "copyIcon", "checkIcon"]

  copy() {
    const rawText = this.sourceTarget.dataset.clipboardText || this.sourceTarget.textContent.trim()
    const numbersOnly = rawText.replace(/\D/g, '')

    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(numbersOnly)
        .then(() => this.#showSuccess())
        .catch(() => this.#execCommandCopy(numbersOnly))
    } else {
      this.#execCommandCopy(numbersOnly)
    }
  }

  #execCommandCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.cssText = "position:fixed;top:0;left:0;opacity:0;pointer-events:none"
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    try {
      document.execCommand("copy")
      this.#showSuccess()
    } catch {
      // 복사 실패 — 아이콘 변경 없음
    } finally {
      document.body.removeChild(textarea)
    }
  }

  #showSuccess() {
    this.copyIconTarget.hidden = true
    this.checkIconTarget.hidden = false
    setTimeout(() => {
      this.copyIconTarget.hidden = false
      this.checkIconTarget.hidden = true
    }, 1500)
  }
}
