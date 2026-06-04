import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "result"]
  static values  = { url: String }

  async fetch() {
    const duprId = this.inputTarget.value.trim()
    if (!duprId) {
      this.showResult("error", "DUPR ID를 입력해 주세요.")
      return
    }

    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "조회 중..."
    this.clearResult()

    try {
      const url = `${this.urlValue}?dupr_id=${encodeURIComponent(duprId)}`
      const resp = await window.fetch(url, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })
      const data = await resp.json()

      if (resp.ok) {
        this.showRating(data.rating)
      } else {
        this.showResult("error", data.error || "조회에 실패했습니다.")
      }
    } catch {
      this.showResult("error", "네트워크 오류가 발생했습니다.")
    } finally {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "정보 가져오기"
    }
  }

  showRating({ doubles, singles }) {
    const el = this.resultTarget
    el.className = "dupr-lookup__result dupr-lookup__result--success"
    el.textContent = ""

    if (doubles != null) {
      const span = document.createElement("span")
      span.textContent = `복식(Doubles): ${doubles}`
      el.appendChild(span)
    }
    if (singles != null) {
      if (doubles != null) el.appendChild(document.createTextNode("  ·  "))
      const span = document.createElement("span")
      span.textContent = `단식(Singles): ${singles}`
      el.appendChild(span)
    }
    if (!doubles && !singles) el.textContent = "레이팅 정보 없음"
    el.style.display = "block"
  }

  showResult(type, message) {
    const el = this.resultTarget
    el.className = `dupr-lookup__result dupr-lookup__result--${type}`
    el.textContent = message
    el.style.display = "block"
  }

  clearResult() {
    const el = this.resultTarget
    el.textContent = ""
    el.style.display = "none"
  }
}
