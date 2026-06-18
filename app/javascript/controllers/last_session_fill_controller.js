import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title",
    "venueName",
    "address",
    "courtCount",
    "fee",
    "maxParticipants",
    "maxWaitlist",
    "courtName",
    "notes"
  ]

  static values = {
    values: Object
  }

  fill() {
    if (!this.hasValuesValue) return

    this.assign(this.titleTarget, this.valuesValue.title)
    this.assign(this.venueNameTarget, this.valuesValue.venueName)
    this.assign(this.addressTarget, this.valuesValue.address)
    this.assign(this.courtCountTarget, this.valuesValue.courtCount)
    this.assign(this.feeTarget, this.valuesValue.fee)
    this.assign(this.maxParticipantsTarget, this.valuesValue.maxParticipants)
    this.assign(this.maxWaitlistTarget, this.valuesValue.maxWaitlist)
    this.assign(this.courtNameTarget, this.valuesValue.courtName)
    this.assign(this.notesTarget, this.valuesValue.notes)
    this.titleTarget.focus({ preventScroll: true })
  }

  assign(target, value) {
    target.value = value ?? ""
    target.dispatchEvent(new Event("input", { bubbles: true }))
    target.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
