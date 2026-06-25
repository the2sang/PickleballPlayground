import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", 
    "sloganNumberField", 
    "sloganNumberDisplay", 
    "sloganTextDisplay", 
    "voterNameField",
    "sloganRow",
    "searchInput",
    "noResults"
  ]

  selectSlogan(event) {
    event.preventDefault()
    
    const number = event.currentTarget.dataset.voteNumberParam
    const text = event.currentTarget.dataset.voteTextParam

    // Populate the form fields in the modal
    if (this.hasSloganNumberFieldTarget) {
      this.sloganNumberFieldTarget.value = number
    }
    if (this.hasSloganNumberDisplayTarget) {
      this.sloganNumberDisplayTarget.textContent = `#${number}`
    }
    if (this.hasSloganTextDisplayTarget) {
      this.sloganTextDisplayTarget.textContent = text
    }
    if (this.hasVoterNameFieldTarget) {
      this.voterNameFieldTarget.value = ""
    }

    // Open the dialog
    if (this.hasModalTarget) {
      this.modalTarget.showModal()
      setTimeout(() => {
        if (this.hasVoterNameFieldTarget) {
          this.voterNameFieldTarget.focus()
        }
      }, 50)
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.close()
    }
  }

  backdropClose(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  search() {
    if (!this.hasSearchInputTarget) return
    
    const query = this.searchInputTarget.value.toLowerCase().trim()
    let visibleCount = 0

    this.sloganRowTargets.forEach(row => {
      const sloganText = row.dataset.sloganText.toLowerCase()
      const voterName = (row.dataset.voterName || "").toLowerCase()
      const number = row.dataset.sloganNumber

      const matchesText = sloganText.includes(query)
      const matchesVoter = voterName.includes(query)
      const matchesNumber = number.includes(query)

      if (matchesText || matchesVoter || matchesNumber) {
        row.classList.remove("hidden")
        visibleCount++
      } else {
        row.classList.add("hidden")
      }
    })

    if (this.hasNoResultsTarget) {
      if (visibleCount === 0) {
        this.noResultsTarget.classList.remove("hidden")
      } else {
        this.noResultsTarget.classList.add("hidden")
      }
    }
  }

  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
      this.search()
      this.searchInputTarget.focus()
    }
  }
}
