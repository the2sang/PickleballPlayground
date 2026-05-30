import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    if (document.cookie.split(";").some(c => c.trim().startsWith(`${this.keyValue}=1`))) {
      this.element.remove()
    }
  }

  dismiss() {
    document.cookie = `${this.keyValue}=1; max-age=${60 * 60 * 24 * 365}; path=/; SameSite=Lax`
    this.element.remove()
  }
}
