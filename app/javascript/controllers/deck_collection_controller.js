import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "query", "page", "range", "prevButton", "nextButton", "empty"]
  static values = { pageSize: { type: Number, default: 9 } }

  connect() {
    this.currentPage = 1
    this.render()
  }

  search() {
    this.currentPage = 1
    this.render()
  }

  prev() {
    if (this.currentPage > 1) {
      this.currentPage--
      this.render()
    }
  }

  next() {
    if (this.currentPage < this.pageCount) {
      this.currentPage++
      this.render()
    }
  }

  render() {
    const filteredItems = this.filteredItems()
    this.pageCount = Math.max(1, Math.ceil(filteredItems.length / this.pageSizeValue))
    this.currentPage = Math.min(this.currentPage, this.pageCount)

    const startIndex = (this.currentPage - 1) * this.pageSizeValue
    const endIndex = startIndex + this.pageSizeValue
    const visibleItems = new Set(filteredItems.slice(startIndex, endIndex))

    this.itemTargets.forEach((item) => {
      item.hidden = !visibleItems.has(item)
    })

    this.updateStatus(filteredItems.length, startIndex, endIndex)
  }

  filteredItems() {
    const query = this.normalizedQuery()
    if (!query) return this.itemTargets

    return this.itemTargets.filter((item) => {
      const title = item.dataset.deckTitle || ""
      const normalizedTitle = this.normalize(title)
      const initialTitle = this.initials(title)

      return normalizedTitle.includes(query) || initialTitle.includes(query)
    })
  }

  normalizedQuery() {
    if (!this.hasQueryTarget) return ""

    return this.normalize(this.queryTarget.value)
  }

  normalize(value) {
    return String(value).toLowerCase().replace(/\s+/g, "")
  }

  initials(value) {
    const choseong = [
      "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
      "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    return Array.from(String(value)).map((char) => {
      const code = char.charCodeAt(0) - 0xac00
      if (code < 0 || code > 11171) return this.normalize(char)

      return choseong[Math.floor(code / 588)]
    }).join("")
  }

  updateStatus(total, startIndex, endIndex) {
    const currentStart = total === 0 ? 0 : startIndex + 1
    const currentEnd = Math.min(endIndex, total)

    if (this.hasPageTarget) this.pageTarget.textContent = `${this.currentPage} / ${this.pageCount}`
    if (this.hasRangeTarget) this.rangeTarget.textContent = `${currentStart}-${currentEnd} / ${total}`
    if (this.hasPrevButtonTarget) this.prevButtonTarget.disabled = this.currentPage <= 1
    if (this.hasNextButtonTarget) this.nextButtonTarget.disabled = this.currentPage >= this.pageCount || total === 0
    if (this.hasEmptyTarget) this.emptyTarget.hidden = total > 0
  }
}
