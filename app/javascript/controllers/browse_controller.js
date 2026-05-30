import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { cards: Array }
  static targets = ["front", "back", "showButton", "counter", "prevButton", "nextButton", "shuffleButton"]

  connect() {
    this.currentIndex = 0
    this.shuffled = false
    this.orderedCards = [...this.cardsValue]   // 원본 순서 보존
    this.displayCards = [...this.orderedCards] // 현재 표시 배열 (셔플 시 재할당)
    this.render()
  }

  flip(event) {
    if (event) event.preventDefault()
    this.showButtonTarget.classList.add("hidden")
    this.showButtonTarget.setAttribute("aria-expanded", "true")
    this.backTarget.classList.remove("hidden")
  }

  prev() {
    if (this.currentIndex > 0) {
      this.currentIndex--
      this.render()
    }
  }

  next() {
    if (this.currentIndex < this.displayCards.length - 1) {
      this.currentIndex++
      this.render()
    }
  }

  toggleShuffle() {
    this.shuffled = !this.shuffled
    if (this.shuffled) {
      this.displayCards = this.fisherYates([...this.orderedCards])
      this.shuffleButtonTarget.textContent = "셔플 중"
      this.shuffleButtonTarget.classList.add("text-blue-600")
      this.shuffleButtonTarget.classList.remove("text-gray-500")
    } else {
      this.displayCards = [...this.orderedCards]
      this.shuffleButtonTarget.textContent = "셔플"
      this.shuffleButtonTarget.classList.remove("text-blue-600")
      this.shuffleButtonTarget.classList.add("text-gray-500")
    }
    this.currentIndex = 0
    this.render()
  }

  render() {
    const card = this.displayCards[this.currentIndex]
    if (!card) return
    this.frontTarget.textContent = card.front
    this.backTarget.textContent  = card.back
    // 새 카드는 항상 unflipped 초기 상태 (back hidden, showButton 표시)
    this.backTarget.classList.add("hidden")
    this.showButtonTarget.classList.remove("hidden")
    this.showButtonTarget.setAttribute("aria-expanded", "false")
    // 카운터 + 네비 disabled
    this.counterTarget.textContent       = `${this.currentIndex + 1} / 전체 ${this.displayCards.length}`
    this.prevButtonTarget.disabled       = this.currentIndex === 0
    this.nextButtonTarget.disabled       = this.currentIndex === this.displayCards.length - 1
  }

  fisherYates(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]]
    }
    return arr
  }
}
