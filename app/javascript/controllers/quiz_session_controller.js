import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "form", "rating", "selectedAnswer", "nextButton", "timer", "timerDisplay", "pauseIcon",
                    "bookmarkButton", "bookmarkIcon", "difficultyStar"]
  static values  = {
    correct: String,
    duration: { type: Number, default: 60 },
    answered: { type: Boolean, default: false },
    nextUrl: String,
    deckId: Number,
    cardId: Number,
    difficulty: { type: Number, default: 0 },
    bookmarked: { type: Boolean, default: false }
  }

  connect() {
    this.answered      = this.answeredValue
    this.paused        = false
    this.remaining     = this.durationValue
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    this._updateProgress()
    this._renderBookmark()
    this._renderDifficulty()
    if (this.answered) {
      this._clearTimer()
      if (this.hasTimerTarget) this.timerTarget.disabled = true
    } else {
      this._startTimer()
    }
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
    if (this.hasSelectedAnswerTarget) this.selectedAnswerTarget.value = chosen.dataset.value
    this._reveal(chosen, correct)
    this._enableNext()
  }

  skipCard(event) {
    event.preventDefault()
    if (this.answered) return
    this.answered = true
    this._clearTimer()
    this.ratingTarget.value = 1
    if (this.hasSelectedAnswerTarget) this.selectedAnswerTarget.value = ""
    this._reveal(null, false)
    this._enableNext()
  }

  nextCard(event) {
    event.preventDefault()

    if (this.answeredValue && this.nextUrlValue) {
      window.Turbo.visit(this.nextUrlValue, { action: "replace" })
      return
    }

    if (!this.ratingTarget.value) return
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

  toggleBookmark(event) {
    event.preventDefault()

    const nextBookmarked = !this.bookmarkedValue
    this.bookmarkedValue = nextBookmarked
    this._renderBookmark()

    fetch(nextBookmarked ? this._cardBookmarksUrl() : this._cardBookmarkUrl(), {
      method: nextBookmarked ? "POST" : "DELETE",
      headers: this._requestHeaders(),
      body: nextBookmarked ? JSON.stringify({ card_id: this.cardIdValue }) : null
    }).catch(() => {
      this.bookmarkedValue = !nextBookmarked
      this._renderBookmark()
    })
  }

  rateDifficulty(event) {
    event.preventDefault()

    const nextDifficulty = parseInt(event.currentTarget.dataset.difficulty, 10)
    const previousDifficulty = this.difficultyValue
    this.difficultyValue = nextDifficulty
    this._renderDifficulty()

    fetch(`/decks/${this.deckIdValue}/card_ratings`, {
      method: "POST",
      headers: this._requestHeaders(),
      body: JSON.stringify({ card_id: this.cardIdValue, difficulty: nextDifficulty })
    }).catch(() => {
      this.difficultyValue = previousDifficulty
      this._renderDifficulty()
    })
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
    if (this.hasSelectedAnswerTarget) this.selectedAnswerTarget.value = ""
    this._reveal(null, false)
    this._enableNext()
  }

  _updateDisplay() {
    if (this.hasTimerDisplayTarget) {
      this.timerDisplayTarget.textContent = this.remaining
    }
    this._updateProgress()
    if (this.hasTimerTarget && this.remaining <= 10) {
      this.timerTarget.classList.add("quiz-timer--urgent")
    }
  }

  _updateProgress() {
    if (!this.hasTimerTarget) return
    const progress = Math.max(0, Math.min(1, 1 - this.remaining / this.durationValue))
    this.timerTarget.style.setProperty("--quiz-timer-top", `${(1 - progress) * 100}%`)
    this.timerTarget.style.setProperty("--quiz-timer-bottom", `${progress * 100}%`)
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

  _enableNext() {
    if (this.hasNextButtonTarget) this.nextButtonTarget.disabled = false
  }

  _renderBookmark() {
    if (this.hasBookmarkButtonTarget) {
      this.bookmarkButtonTarget.classList.toggle("quiz-bookmark--active", this.bookmarkedValue)
      this.bookmarkButtonTarget.setAttribute("aria-pressed", String(this.bookmarkedValue))
      this.bookmarkButtonTarget.setAttribute("aria-label", this.bookmarkedValue ? "북마크 해제" : "북마크")
    }
    if (this.hasBookmarkIconTarget) {
      this.bookmarkIconTarget.setAttribute("icon", this.bookmarkedValue ? "lucide:bookmark-check" : "lucide:bookmark")
    }
  }

  _renderDifficulty() {
    this.difficultyStarTargets.forEach((star, index) => {
      star.classList.toggle("quiz-difficulty__star--active", index < this.difficultyValue)
    })
  }

  _cardBookmarkUrl() {
    return `/decks/${this.deckIdValue}/card_bookmarks/${this.cardIdValue}`
  }

  _cardBookmarksUrl() {
    return `/decks/${this.deckIdValue}/card_bookmarks`
  }

  _requestHeaders() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
    }
  }
}
