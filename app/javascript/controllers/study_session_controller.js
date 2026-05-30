import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["back", "showButton", "ratingRow", "keyHints", "ratingButton", "divider"]

  connect() {
    this.flipped = false
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  flip(event) {
    if (event) event.preventDefault()
    this.flipped = true
    this.showButtonTarget.classList.add("hidden")
    this.showButtonTarget.setAttribute("aria-expanded", "true")
    this.backTarget.classList.remove("hidden")
    this.ratingRowTarget.classList.remove("hidden")
    if (this.hasKeyHintsTarget) this.keyHintsTarget.classList.remove("hidden")
    if (this.hasDividerTarget) this.dividerTarget.classList.remove("hidden")
  }

  submitRating(event) {
    // 더블클릭 가드 (D-05): 모든 평가 버튼을 즉시 disable
    // Turbo Stream replace 후 새 partial이 unflipped 초기 상태로 mount되므로 수동 re-enable 불필요 (Pitfall 4)
    this.ratingButtonTargets.forEach(btn => {
      btn.disabled = true
      btn.setAttribute("aria-disabled", "true")
    })
    // form submission은 button[type=submit]이 자동으로 처리 — preventDefault 금지
  }

  handleKeydown(event) {
    if (!this.flipped) return  // D-04: flip 전 키 입력 차단 (Pitfall 3)
    const map = { "1": 0, "2": 1, "3": 2, "4": 3 }
    const idx = map[event.key]
    if (idx !== undefined && !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault()
      this.ratingButtonTargets[idx]?.click()
    }
  }
}
