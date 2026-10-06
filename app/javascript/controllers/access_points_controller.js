import { Controller } from "@hotwired/stimulus"

// The access points page. A click on « Tester » or « Tester tous les points
// d'accès » posts its form in the background and gets the blocks back, so the
// page does not reload; while a block says a test is pending, the page asks for
// the blocks again until none does.
//
// The server decides what each block says: this controller only swaps a block
// whose outcome or request instant changed, and keeps the element itself — it
// carries the `aria-live` region, and a region swapped out with what it
// announces announces nothing.

const INTERVAL = 2000

// How many answers in a row may fail before the page is reloaded, which shows
// whatever the server says — the `502` of a gateway gone, the login page of an
// expired session.
const ATTEMPTS = 3

const BLOCK = '.access-point'
const PENDING = 'pending'
const SPINNER = '[data-access-points-spinner]'

export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }

  connect() {
    this.failures = 0
    this.reveal()
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // The form is sent as `button_to` built it, CSRF token included, with one
  // more field asking for the blocks instead of a redirection.
  submit(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return

    event.preventDefault()
    this.buttons(form).forEach((button) => { button.disabled = true })

    const body = new FormData(form)
    body.append('fragment', '1')
    this.ask(form.action, { method: 'POST', body }, () => window.location.reload())
  }

  // The header goes in with the rest, never as a second argument to `fetch`,
  // which would drop the `Content-Type` a `FormData` body writes for itself.
  //
  // A click whose answer is lost is not retried by the polling, which would
  // re-enable the buttons on blocks that never changed and lose the click
  // without a word: the page is reloaded instead, and says what the server
  // holds.
  ask(url, options = {}, failed = () => this.fail()) {
    fetch(new Request(url, { ...options, headers: { 'Accept': 'text/html' } }))
      .then((response) => this.receive(response, failed))
      .catch((error) => {
        console.error('access-points', error)
        failed()
      })
  }

  receive(response, failed) {
    if (response.redirected) return window.location.reload()
    if (response.headers.get('Deferred-Fragment') !== '1') return failed()

    return response.text().then((html) => {
      this.splice(html)
      this.failures = 0
      this.schedule()
    })
  }

  // Block by block, by party: a block that says what it already says is left
  // alone, so its spinner does not start over and nothing is announced twice.
  splice(html) {
    const arriving = new DOMParser().parseFromString(html, 'text/html')

    arriving.querySelectorAll(BLOCK).forEach((block) => {
      const current = this.block(block.dataset.party)
      if (!current) return

      if (current.dataset.outcome === block.dataset.outcome &&
          (current.dataset.requestedAt || '') === (block.dataset.requestedAt || '')) {
        this.buttons(current).forEach((button) => { button.disabled = false })
        return
      }

      current.innerHTML = block.innerHTML
      current.dataset.outcome = block.dataset.outcome
      current.dataset.requestedAt = block.dataset.requestedAt || ''
      // A value and not a bare attribute: `aria-busy` is `true` or absent.
      if (block.hasAttribute('aria-busy')) current.setAttribute('aria-busy', 'true')
      else current.removeAttribute('aria-busy')
    })

    this.buttons(this.element).filter((button) => !this.listTarget.contains(button))
      .forEach((button) => { button.disabled = false })
    this.reveal()
  }

  fail() {
    this.failures += 1

    if (this.failures >= ATTEMPTS) return window.location.reload()

    this.schedule(true)
  }

  // One tick at a time: a server slower than the interval is not asked again
  // before it has answered.
  schedule(retrying = false) {
    clearTimeout(this.timer)

    if (retrying || this.polling) this.timer = setTimeout(() => this.ask(this.urlValue), INTERVAL)
  }

  // Shown by the controller and never by the server: without JavaScript nothing
  // would ever stop it.
  reveal() {
    this.element.querySelectorAll(SPINNER).forEach((spinner) => { spinner.hidden = false })
  }

  get polling() {
    return this.listTarget.querySelector(`${BLOCK}[data-outcome="${PENDING}"]`) !== null
  }

  block(party) {
    return Array.from(this.listTarget.querySelectorAll(BLOCK)).find((block) => block.dataset.party === party)
  }

  buttons(scope) {
    return Array.from(scope.querySelectorAll('button[type="submit"], input[type="submit"]'))
  }
}
