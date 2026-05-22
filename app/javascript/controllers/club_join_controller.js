import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._launchConfetti()
  }

  _launchConfetti() {
    const colors = ["#f94144","#f3722c","#f8961e","#f9c74f","#90be6d","#43aa8b","#577590","#a8dadc","#e63946","#b5179e"]
    const wrap = document.createElement("div")
    wrap.className = "pz-confetti-wrap"
    document.body.appendChild(wrap)
    for (let i = 0; i < 120; i++) {
      const p    = document.createElement("div")
      const size = 5 + Math.random() * 9
      p.className = "pz-confetti-piece"
      p.style.left              = `${Math.random() * 100}%`
      p.style.background        = colors[i % colors.length]
      p.style.animationDelay    = `${Math.random() * 1.8}s`
      p.style.animationDuration = `${2.5 + Math.random() * 2}s`
      p.style.width             = `${size}px`
      p.style.height            = `${size}px`
      p.style.borderRadius      = Math.random() > 0.5 ? "50%" : "3px"
      wrap.appendChild(p)
    }
    setTimeout(() => wrap.remove(), 6000)
  }
}
