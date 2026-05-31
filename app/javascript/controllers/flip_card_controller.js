// app/javascript/controllers/flip_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { cards: Array, ratings: Object, deckId: Number }
  static targets = ["front", "back", "inner", "counter",
                    "prevBtn", "nextBtn", "star", "countdown", "swapBtn"]

  connect() {
    this.index          = 0
    this.flipped        = false
    this.swapped        = false
    this.countdownTimer = null
    this.handleKeydown  = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this.render()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    this.clearTimers()
  }

  // ── Flip ────────────────────────────────────────────────────────
  flip() {
    if (!this.flipped) {
      this.flipped = true
      this.innerTarget.classList.add("flip-card__inner--flipped")
      this.startCountdown()
    } else {
      this.flipped = false
      this.innerTarget.classList.remove("flip-card__inner--flipped")
      this.clearTimers()
      this.countdownTarget.classList.add("hidden")
    }
  }

  startCountdown() {
    let remaining = 3
    this.countdownTarget.textContent = remaining
    this.countdownTarget.classList.remove("hidden")
    this.countdownTimer = setInterval(() => {
      remaining -= 1
      if (remaining > 0) {
        this.countdownTarget.textContent = remaining
      } else {
        this.clearTimers()
        this.flip()
      }
    }, 1000)
  }

  clearTimers() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer)
      this.countdownTimer = null
    }
  }

  // ── Swap ────────────────────────────────────────────────────────
  swap() {
    this.swapped = !this.swapped
    this.swapBtnTarget.classList.toggle("flip-swap-btn--active", this.swapped)
    if (this.flipped) {
      this.flipped = false
      this.innerTarget.classList.remove("flip-card__inner--flipped")
      this.clearTimers()
      this.countdownTarget.classList.add("hidden")
    }
    this.render()
  }

  // ── Navigation ──────────────────────────────────────────────────
  navigate(event) {
    const dir = event.currentTarget.dataset.direction
    this.clearTimers()
    if (this.flipped) {
      this.flipped = false
      this.innerTarget.classList.remove("flip-card__inner--flipped")
      this.countdownTarget.classList.add("hidden")
    }
    if (dir === "prev") {
      this.index = Math.max(0, this.index - 1)
    } else {
      this.index = Math.min(this.cardsValue.length - 1, this.index + 1)
    }
    this.render()
  }

  // ── Star rating ─────────────────────────────────────────────────
  rate(event) {
    const stars = parseInt(event.currentTarget.dataset.star, 10)
    const card  = this.cardsValue[this.index]

    // Optimistic UI update
    this.ratingsValue = { ...this.ratingsValue, [String(card.id)]: stars }
    this.renderStars()

    // Persist to server
    const csrf = document.querySelector('meta[name="csrf-token"]').content
    fetch(`/decks/${this.deckIdValue}/card_ratings`, {
      method:  "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
      body:    JSON.stringify({ card_id: card.id, difficulty: stars })
    })
  }

  // ── Keyboard ────────────────────────────────────────────────────
  handleKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    switch (event.key) {
      case " ":
      case "Enter":
        event.preventDefault()
        this.flip()
        break
      case "ArrowLeft":
        event.preventDefault()
        if (!this.prevBtnTarget.disabled) this.prevBtnTarget.click()
        break
      case "ArrowRight":
        event.preventDefault()
        if (!this.nextBtnTarget.disabled) this.nextBtnTarget.click()
        break
      default: {
        const n = parseInt(event.key, 10)
        if (n >= 1 && n <= 5) {
          event.preventDefault()
          this.starTargets[n - 1]?.click()
        }
      }
    }
  }

  // ── Render ──────────────────────────────────────────────────────
  render() {
    const card = this.cardsValue[this.index]
    this.frontTarget.textContent   = this.swapped ? card.back  : card.front
    this.backTarget.textContent    = this.swapped ? card.front : card.back
    this.counterTarget.textContent = `${this.index + 1} / ${this.cardsValue.length}`
    this.prevBtnTarget.disabled    = this.index === 0
    this.nextBtnTarget.disabled    = this.index === this.cardsValue.length - 1
    this.renderStars()
  }

  renderStars() {
    const card   = this.cardsValue[this.index]
    const rating = this.ratingsValue[String(card.id)] || 0
    this.starTargets.forEach((star, i) => {
      star.classList.toggle("flip-star--active", i < rating)
    })
  }
}
