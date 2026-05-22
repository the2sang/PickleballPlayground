import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  search() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.element.requestSubmit(), 300)
  }
}
