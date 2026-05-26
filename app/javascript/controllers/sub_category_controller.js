import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "customInput", "hiddenField"]

  static values = {
    customOption: { type: String, default: "__custom__" }
  }

  connect() {
    this.syncFromHidden()
  }

  onSelectChange() {
    if (this.selectTarget.value === this.customOptionValue) {
      this.showCustomInput()
    } else {
      this.hideCustomInput()
      this.hiddenFieldTarget.value = this.selectTarget.value
    }
  }

  onCustomInput() {
    this.hiddenFieldTarget.value = this.customInputTarget.value
  }

  syncFromHidden() {
    const current = this.hiddenFieldTarget.value
    const predefined = Array.from(this.selectTarget.options).map(o => o.value)
    const isPredefined = current === "" || predefined.includes(current)

    if (!isPredefined) {
      this.selectTarget.value = this.customOptionValue
      this.customInputTarget.value = current
      this.showCustomInput()
    } else {
      this.selectTarget.value = current
      this.hideCustomInput()
    }
  }

  showCustomInput() {
    this.customInputTarget.classList.remove("hidden")
    this.customInputTarget.focus()
  }

  hideCustomInput() {
    this.customInputTarget.classList.add("hidden")
    this.customInputTarget.value = ""
  }
}
