import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "form", "rating", "timer", "timerDisplay", "timerRing", "pauseIcon"]
  static values  = { correct: String, duration: { type: Number, default: 60 } }

  connect() {
    this.answered      = false
    this.paused        = false
    this.remaining     = this.durationValue
    this._circumference = 2 * Math.PI * 16  // r=16 → C≈100.53
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this._updateRing()
    this._startTimer()
  }

  disconnect() {
    this._clearTimer()
    document.removeEventListener("keydown", this.handleKeydown)
  }

  selectOption(event) {
    if (this.answered) return
    this.answered = true
    this._clearTimer()

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
    this._clearTimer()
    this.ratingTarget.value = 1
    this.optionTargets.forEach(btn => { btn.disabled = true })
    this.formTarget.requestSubmit()
  }

  pauseToggle() {
    if (this.answered) return
    this.paused = !this.paused

    if (this.paused) {
      this._clearTimer()
      if (this.hasPauseIconTarget) this.pauseIconTarget.setAttribute("icon", "lucide:play")
      if (this.hasTimerTarget) this.timerTarget.classList.add("quiz-timer--paused")
    } else {
      this._startTimer()
      if (this.hasPauseIconTarget) this.pauseIconTarget.setAttribute("icon", "lucide:pause")
      if (this.hasTimerTarget) this.timerTarget.classList.remove("quiz-timer--paused")
    }
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

  // ── private ──────────────────────────────────────────────

  _startTimer() {
    this.timerId = setInterval(() => this._tick(), 1000)
  }

  _clearTimer() {
    if (this.timerId) {
      clearInterval(this.timerId)
      this.timerId = null
    }
  }

  _tick() {
    this.remaining -= 1
    this._updateDisplay()
    if (this.remaining <= 0) {
      this._clearTimer()
      this._timeout()
    }
  }

  _timeout() {
    if (this.answered) return
    this.answered = true
    this.ratingTarget.value = 1
    this.optionTargets.forEach(btn => { btn.disabled = true })
    this.formTarget.requestSubmit()
  }

  _updateDisplay() {
    if (this.hasTimerDisplayTarget) {
      this.timerDisplayTarget.textContent = this.remaining
    }
    this._updateRing()
    if (this.hasTimerTarget && this.remaining <= 10) {
      this.timerTarget.classList.add("quiz-timer--urgent")
    }
  }

  _updateRing() {
    if (!this.hasTimerRingTarget) return
    const offset = this._circumference * (1 - this.remaining / this.durationValue)
    this.timerRingTarget.style.strokeDashoffset = offset
  }

  _reveal(chosen, correct) {
    this.optionTargets.forEach(btn => {
      btn.disabled = true
      const isCorrect = btn.dataset.value === this.correctValue
      const isChosen  = btn === chosen

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
