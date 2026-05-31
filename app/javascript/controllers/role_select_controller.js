import { Controller } from "@hotwired/stimulus"

const LABELS = {
  user:  "회원",
  club:  "클럽관리자",
  admin: "시스템관리자",
}

export default class extends Controller {
  static targets = ["select", "form"]

  connect() {
    this._onOutsideClick = this._close.bind(this)
    this._build()
  }

  disconnect() {
    document.removeEventListener("click", this._onOutsideClick)
  }

  // ── private ──────────────────────────────────────────

  _build() {
    const select = this.selectTarget
    const current = select.value

    this._wrapper = document.createElement("div")
    this._wrapper.className = "rs-wrapper"

    this._trigger = document.createElement("button")
    this._trigger.type = "button"
    this._trigger.className = "rs-trigger"
    this._trigger.setAttribute("aria-haspopup", "listbox")
    this._trigger.setAttribute("aria-expanded", "false")
    this._trigger.innerHTML = `
      <span class="rs-value">${LABELS[current] ?? current}</span>
      <iconify-icon icon="lucide:chevrons-up-down" class="rs-chevron"></iconify-icon>
    `
    this._trigger.addEventListener("click", (e) => {
      e.stopPropagation()
      this._dropdown.hidden ? this._open() : this._close()
    })

    this._dropdown = document.createElement("div")
    this._dropdown.className = "rs-dropdown"
    this._dropdown.setAttribute("role", "listbox")
    this._dropdown.hidden = true

    Object.entries(LABELS).forEach(([value, label]) => {
      const item = document.createElement("div")
      item.className = "rs-item"
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", value === current ? "true" : "false")
      item.dataset.value = value
      item.innerHTML = `
        <iconify-icon icon="lucide:check" class="rs-check${value === current ? "" : " rs-check--hidden"}"></iconify-icon>
        <span>${label}</span>
      `
      item.addEventListener("click", () => this._pick(value, label))
      this._dropdown.appendChild(item)
    })

    this._wrapper.appendChild(this._trigger)
    this._wrapper.appendChild(this._dropdown)
    this.element.appendChild(this._wrapper)
  }

  _open() {
    this._dropdown.hidden = false
    this._trigger.setAttribute("aria-expanded", "true")
    requestAnimationFrame(() => {
      document.addEventListener("click", this._onOutsideClick)
    })
  }

  _close() {
    this._dropdown.hidden = true
    this._trigger.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this._onOutsideClick)
  }

  _pick(value, label) {
    const nickname = this.element.dataset.roleSelectNickname

    if (!confirm(`${nickname}의 권한을 변경합니까?`)) {
      this._close()
      return
    }

    this.selectTarget.value = value

    this._trigger.querySelector(".rs-value").textContent = label

    this._dropdown.querySelectorAll(".rs-item").forEach(item => {
      const isSelected = item.dataset.value === value
      item.setAttribute("aria-selected", isSelected ? "true" : "false")
      item.querySelector(".rs-check").classList.toggle("rs-check--hidden", !isSelected)
    })

    this._close()
    this.formTarget.requestSubmit()
  }
}
