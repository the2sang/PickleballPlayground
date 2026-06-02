import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "item", "prevButton", "nextButton", "status"]

  connect() {
    this.update = this.update.bind(this)
    this.viewportTarget.addEventListener("scroll", this.update, { passive: true })
    window.addEventListener("resize", this.update)
    this.update()
  }

  disconnect() {
    this.viewportTarget.removeEventListener("scroll", this.update)
    window.removeEventListener("resize", this.update)
  }

  prev() {
    this.viewportTarget.scrollBy({ left: -this.scrollAmount(), behavior: "smooth" })
  }

  next() {
    this.viewportTarget.scrollBy({ left: this.scrollAmount(), behavior: "smooth" })
  }

  update() {
    const maxScroll = this.maxScroll()
    const left = this.viewportTarget.scrollLeft
    const atStart = left <= 2
    const atEnd = left >= maxScroll - 2

    if (this.hasPrevButtonTarget) this.prevButtonTarget.disabled = atStart
    if (this.hasNextButtonTarget) this.nextButtonTarget.disabled = atEnd
    if (this.hasStatusTarget) this.statusTarget.textContent = this.statusText(left, maxScroll)
  }

  scrollAmount() {
    return this.viewportTarget.clientWidth
  }

  maxScroll() {
    return Math.max(0, this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth)
  }

  statusText(left, maxScroll) {
    if (this.itemTargets.length === 0) return "0 / 0"
    if (maxScroll <= 2) return `1-${this.itemTargets.length} / ${this.itemTargets.length}`

    const itemWidth = this.itemTargets[0].getBoundingClientRect().width
    const gap = parseFloat(getComputedStyle(this.itemTargets[0].parentElement).columnGap || "0")
    const step = Math.max(1, itemWidth + gap)
    const start = Math.min(this.itemTargets.length, Math.floor(left / step) + 1)
    const visible = this.visibleCount()
    const end = Math.min(this.itemTargets.length, start + visible - 1)

    return `${start}-${end} / ${this.itemTargets.length}`
  }

  visibleCount() {
    if (this.itemTargets.length === 0) return 0

    const itemWidth = this.itemTargets[0].getBoundingClientRect().width
    return Math.max(1, Math.round(this.viewportTarget.clientWidth / itemWidth))
  }
}
