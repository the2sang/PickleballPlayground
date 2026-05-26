import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chips", "textInput", "dropdown", "searchInput", "list", "hiddenFields"]
  static values = { namePrefix: String }

  connect() {
    const form = this.element.closest("[data-club-members]")
    this.members = JSON.parse(form?.dataset.clubMembers || "[]")
    this.selected = []
    this.renderList(this.members)
    document.addEventListener("click", this.onOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onOutsideClick)
  }

  onOutsideClick = (e) => {
    if (!this.element.contains(e.target)) this.close()
  }

  open() {
    this.dropdownTarget.classList.toggle("hidden")
    if (!this.dropdownTarget.classList.contains("hidden")) {
      this.searchInputTarget.value = ""
      this.renderList(this.availableMembers())
      this.searchInputTarget.focus()
    }
  }

  close() {
    this.dropdownTarget.classList.add("hidden")
  }

  search() {
    const q = this.searchInputTarget.value.toLowerCase()
    const filtered = this.availableMembers().filter(m => m.nickname.toLowerCase().includes(q))
    this.renderList(filtered)
  }

  select(event) {
    const id = parseInt(event.currentTarget.dataset.memberId)
    const member = this.members.find(m => m.id === id)
    if (!member) return
    this.selected.push(member)
    this.renderChips()
    this.addHiddenField(id)
    this.close()
  }

  removeMember(event) {
    const id = parseInt(event.currentTarget.dataset.memberId)
    this.selected = this.selected.filter(s => s.id !== id)
    this.renderChips()
    this.removeHiddenField(id)
  }

  availableMembers() {
    return this.members.filter(m => !this.selected.find(s => s.id === m.id))
  }

  renderChips() {
    this.chipsTarget.replaceChildren()
    this.selected.forEach(m => {
      const chip = document.createElement("span")
      chip.className = "member-chip"
      chip.title = m.nickname

      const initial = document.createElement("span")
      initial.className = "member-chip__initial"
      initial.textContent = m.nickname[0]

      const name = document.createElement("span")
      name.className = "member-chip__name"
      name.textContent = m.nickname

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "member-chip__remove"
      btn.dataset.memberId = m.id
      btn.dataset.action = "click->member-picker#removeMember"
      btn.textContent = "×"

      chip.append(initial, name, btn)
      this.chipsTarget.appendChild(chip)
    })
  }

  renderList(members) {
    this.listTarget.replaceChildren()
    if (members.length === 0) {
      const li = document.createElement("li")
      li.className = "member-list__empty"
      li.textContent = "회원이 없습니다"
      this.listTarget.appendChild(li)
      return
    }
    members.forEach(m => {
      const li = document.createElement("li")
      li.className = "member-list__item"
      li.dataset.memberId = m.id
      li.dataset.action = "click->member-picker#select"
      li.textContent = m.nickname
      this.listTarget.appendChild(li)
    })
  }

  addHiddenField(userId) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = `${this.namePrefixValue}[player_user_ids][]`
    input.value = userId
    input.dataset.userId = userId
    this.hiddenFieldsTarget.appendChild(input)
  }

  removeHiddenField(userId) {
    this.hiddenFieldsTarget.querySelector(`[data-user-id="${userId}"]`)?.remove()
  }
}
