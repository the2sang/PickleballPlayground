import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "result", "runBtn", "history"]
  static values  = { executeUrl: String, csrfToken: String }

  connect() {
    this._history = []
  }

  keydown(e) {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
      e.preventDefault()
      this.execute()
    }
    // Tab → 2 spaces
    if (e.key === "Tab") {
      e.preventDefault()
      const el = this.inputTarget
      const start = el.selectionStart
      const end   = el.selectionEnd
      el.value = el.value.slice(0, start) + "  " + el.value.slice(end)
      el.selectionStart = el.selectionEnd = start + 2
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this._renderPlaceholder()
  }

  preset(e) {
    this.inputTarget.value = e.currentTarget.dataset.sqlConsoleQueryParam
    this.inputTarget.focus()
  }

  async execute() {
    const sql = this.inputTarget.value.trim()
    if (!sql) return

    this._setLoading(true)

    try {
      const res = await fetch(this.executeUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfTokenValue,
          "Accept":       "application/json",
        },
        body: JSON.stringify({ sql }),
      })
      const data = await res.json()
      this._renderResult(data, sql)
      this._appendHistory(sql, data)
    } catch (err) {
      this._renderError("네트워크 오류: " + err.message)
    } finally {
      this._setLoading(false)
    }
  }

  // ── private ────────────────────────────────────────

  _setLoading(on) {
    this.runBtnTarget.disabled = on
    this.runBtnTarget.innerHTML = on
      ? '<iconify-icon icon="lucide:loader-circle" style="font-size:13px;animation:spin 1s linear infinite;"></iconify-icon> 실행 중...'
      : '<iconify-icon icon="lucide:play" style="font-size:13px;"></iconify-icon> 실행'
  }

  _renderPlaceholder() {
    this.resultTarget.innerHTML = `
      <div style="padding:20px;text-align:center;color:var(--hcp-cool-gray);font-size:13px;">
        SQL을 입력하고 실행 버튼을 누르세요.
      </div>`
  }

  _renderError(msg) {
    this.resultTarget.innerHTML = `
      <div style="padding:16px;display:flex;align-items:flex-start;gap:10px;
                  background:#fef2f2;color:#991b1b;">
        <iconify-icon icon="lucide:circle-x" style="flex-shrink:0;margin-top:1px;"></iconify-icon>
        <pre style="margin:0;font-family:inherit;font-size:13px;white-space:pre-wrap;word-break:break-all;">${this._esc(msg)}</pre>
      </div>`
  }

  _renderResult(data, sql) {
    if (data.type === "error") {
      this._renderError(data.error)
      return
    }

    if (data.type === "select") {
      if (data.row_count === 0) {
        this.resultTarget.innerHTML = `
          <div style="padding:20px;text-align:center;color:var(--hcp-cool-gray);font-size:13px;">
            조회 결과가 없습니다.
          </div>`
        return
      }

      const header = data.columns.map(c =>
        `<th style="padding:8px 12px;text-align:left;white-space:nowrap;
                    font-size:11px;text-transform:uppercase;letter-spacing:0.04em;
                    color:var(--hcp-mid-gray);border-bottom:1px solid var(--hcp-border-light);">${this._esc(c)}</th>`
      ).join("")

      const rows = data.rows.map(row => {
        const cells = row.map(v =>
          `<td style="padding:7px 12px;font-size:12px;font-family:'Courier New',Courier,monospace;
                      border-bottom:1px solid var(--hcp-border-light);white-space:nowrap;
                      max-width:300px;overflow:hidden;text-overflow:ellipsis;"
               title="${this._esc(String(v ?? ""))}">${this._esc(String(v ?? "NULL"))}</td>`
        ).join("")
        return `<tr style="transition:background 0.1s;" onmouseover="this.style.background='var(--hcp-surface)'" onmouseout="this.style.background=''">${cells}</tr>`
      }).join("")

      this.resultTarget.innerHTML = `
        <div style="overflow-x:auto;">
          <table style="width:100%;border-collapse:collapse;">
            <thead><tr>${header}</tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>
        <div style="padding:8px 12px;font-size:11px;color:var(--hcp-cool-gray);
                    border-top:1px solid var(--hcp-border-light);background:var(--hcp-surface);">
          ${data.row_count}행 조회됨
        </div>`
    } else {
      this.resultTarget.innerHTML = `
        <div style="padding:16px;display:flex;align-items:center;gap:10px;
                    background:#f0fdf4;color:#166534;">
          <iconify-icon icon="lucide:circle-check" style="flex-shrink:0;"></iconify-icon>
          <span style="font-size:13px;">${this._esc(data.message)}</span>
        </div>`
    }
  }

  _appendHistory(sql, data) {
    const ts     = new Date().toLocaleTimeString("ko-KR")
    const status = data.type === "error" ? "❌" : "✅"
    const info   = data.type === "select"
      ? `${data.row_count}행 조회`
      : data.type === "dml"
        ? data.message
        : data.error
    this._history.push(`[${ts}] ${status} ${info}\n  ${sql.replace(/\n/g, "\n  ")}`)
    this.historyTarget.textContent = this._history.slice(-20).join("\n\n")
    this.historyTarget.scrollTop   = this.historyTarget.scrollHeight
  }

  _esc(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
