import { Controller } from "@hotwired/stimulus"

// 오픈 게임 세션의 코트 카드를 펼치고 접는다.
// 각 카드는 독립적으로 토글된다(다중 열림 허용).
export default class extends Controller {
  toggle(event) {
    const header = event.currentTarget
    const card = header.closest(".oss-card")
    if (!card) return

    const panel = card.querySelector(".oss-card__panel")
    if (!panel) return

    const isOpen = header.getAttribute("aria-expanded") === "true"
    header.setAttribute("aria-expanded", String(!isOpen))
    panel.hidden = isOpen
  }
}
