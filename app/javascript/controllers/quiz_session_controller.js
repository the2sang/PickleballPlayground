import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "form", "rating"]
  static values  = { correct: String }

  connect() {
    this.answered = false
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  selectOption(event) {
    if (this.answered) return
    this.answered = true

    const chosen  = event.currentTarget
    const correct = chosen.dataset.value === this.correctValue

    this.ratingTarget.value = correct ? 4 : 1
    this._reveal(chosen, correct)
    setTimeout(() => this.formTarget.requestSubmit(), 1000)
  }

  skipCard(event) {
    event.preventDefault()
    if (this.answered) return
    this.answered = true
    this.ratingTarget.value = 1
    this.optionTargets.forEach(btn => { btn.disabled = true })
    this.formTarget.requestSubmit()
  }

  handleKeydown(event) {
    if (this.answered) return
    if (event.metaKey || event.ctrlKey || event.altKey) return
    const idx = { "1": 0, "2": 1, "3": 2, "4": 3 }[event.key]
    if (idx !== undefined && this.optionTargets[idx]) {
      event.preventDefault()
      this.optionTargets[idx].click()
    }
  }

  _reveal(chosen, correct) {
    this.optionTargets.forEach(btn => {
      btn.disabled = true
      const isCorrect  = btn.dataset.value === this.correctValue
      const isChosen   = btn === chosen

      if (isCorrect) {
        btn.dataset.result = "correct"
      } else if (isChosen && !correct) {
        btn.dataset.result = "wrong"
      } else {
        btn.dataset.result = "inactive"
      }
    })
  }
}
