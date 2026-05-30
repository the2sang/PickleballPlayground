import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["front", "counter", "cancel"]
  static values = { savedCount: { type: Number, default: 0 } }

  handleKeydown(event) {
    // Cmd/Ctrl+Enter: 저장하고 다음 (Decision #1)
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      // form.submit() 사용 금지 — Turbo 인터셉트 불가 (Pitfall 5)
      const form = this.element.querySelector("form")
      if (form) form.requestSubmit()
      return
    }

    // Escape: 인라인 편집 frame이면 read-only 행으로 복귀 (Decision #4)
    if (event.key === "Escape") {
      const frame = this.element.closest("turbo-frame")
      if (frame && frame.id.startsWith("card_")) {
        event.preventDefault()
        if (this.hasCancelTarget) this.cancelTarget.click()
      }
      // add form은 frame 밖에 위치 — Escape 무시 (no-op)
    }
  }

  // Decision #1: 서버가 카운터를 렌더하므로 클라이언트는 value 변경 시 시각적 강조만
  savedCountValueChanged(newValue, oldValue) {
    if (this.hasCounterTarget && oldValue !== undefined && newValue > oldValue) {
      this.counterTarget.classList.add("card-form__counter--pulse")
      setTimeout(() => this.counterTarget.classList.remove("card-form__counter--pulse"), 300)
    }
  }
}
