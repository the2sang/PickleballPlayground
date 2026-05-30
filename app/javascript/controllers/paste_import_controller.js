import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "separator"]

  detectSeparator() {
    const lines = this.textTarget.value.split("\n").slice(0, 5)
    const counts = { tab: 0, pipe: 0, dash: 0, comma: 0 }
    lines.forEach(line => {
      if (line.includes("\t")) counts.tab++
      if (line.includes("|")) counts.pipe++
      if (line.includes("==")) counts.dash++
      if (line.includes(",")) counts.comma++
    })
    const best = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]
    if (best && best[1] > 0) {
      this.separatorTarget.value = best[0]
    }
  }
}
