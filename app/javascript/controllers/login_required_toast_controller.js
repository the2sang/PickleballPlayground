import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    message: String
  }

  show(event) {
    event.preventDefault()

    const container = document.getElementById("faw-toast-container")
    if (!container) return

    const toast = document.createElement("div")
    toast.className = "faw-toast faw-toast-border-sky faw-toast-border-left-10 faw-toast-slide-right"
    toast.textContent = this.messageValue || "로그인 후 사용할 수 있습니다."

    const progress = document.createElement("div")
    progress.className = "faw-toast-progress"
    toast.appendChild(progress)

    container.appendChild(toast)
  }
}
