import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "slide", "counter", "prevButton", "nextButton"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.render()
  }

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
    this.render()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  prev() {
    if (this.indexValue <= 0) return
    this.indexValue -= 1
  }

  next() {
    if (this.indexValue >= this.slideTargets.length - 1) return
    this.indexValue += 1
  }

  indexValueChanged() {
    this.render()
  }

  render() {
    if (!this.hasSlideTarget) return

    this.slideTargets.forEach((slide, index) => {
      slide.style.transform = `translateX(${(index - this.indexValue) * 100}%)`
      slide.setAttribute("aria-hidden", index === this.indexValue ? "false" : "true")
    })

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.indexValue + 1} / ${this.slideTargets.length}`
    }
    if (this.hasPrevButtonTarget) this.prevButtonTarget.disabled = this.indexValue === 0
    if (this.hasNextButtonTarget) this.nextButtonTarget.disabled = this.indexValue === this.slideTargets.length - 1
  }
}
