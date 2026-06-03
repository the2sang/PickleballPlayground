import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    appname: String,
    query: String
  }

  open(event) {
    if (!this.hasQueryValue || this.queryValue.trim() === "") return

    event.preventDefault()

    const query = encodeURIComponent(this.queryValue.trim())
    const appname = encodeURIComponent(this.appnameValue || window.location.origin)
    const fallbackUrl = this.element.href
    const userAgent = navigator.userAgent

    if (/Android/i.test(userAgent)) {
      window.location.href =
        `intent://search?query=${query}&appname=${appname}` +
        "#Intent;scheme=nmap;action=android.intent.action.VIEW;" +
        "category=android.intent.category.BROWSABLE;package=com.nhn.android.nmap;end"
      return
    }

    if (/iPhone|iPad|iPod/i.test(userAgent)) {
      window.location.href = `nmap://search?query=${query}&appname=${appname}`

      window.setTimeout(() => {
        if (!document.hidden) window.location.href = fallbackUrl
      }, 1200)
      return
    }

    window.open(fallbackUrl, "_blank", "noopener") || (window.location.href = fallbackUrl)
  }
}
