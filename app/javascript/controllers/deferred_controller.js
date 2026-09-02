import { Controller } from "@hotwired/stimulus"

// A page too slow to serve whole: it arrives with its heading and this element,
// which then asks the same address for the part that takes the time.
//
// Which pages do this, and why, is in
// `Admin::CommonServices::BaseController#listing_asked?`.

export default class extends Controller {
  static targets = ["spinner", "message"]
  static values = { url: String, failed: String }

  connect() {
    // Server-side the spinner would spin for ever beside the `<noscript>`
    // sentence, its animation being pure CSS: it is shown by whatever is going
    // to make it stop.
    this.spinnerTarget.hidden = false

    fetch(this.urlValue, { headers: { 'Accept': 'text/html' } })
      .then((response) => this.receive(response))
      // A request that never reached the server — `fetch` rejects on no status
      // of its own — and anything `receive` itself throws on.
      .catch(() => this.fail())
  }

  receive(response) {
    // A browser without the session cookie is sent to the login page, which
    // belongs in the window rather than inside a listing. Reloading takes it
    // there, and the guard remembers the address it refused.
    if (response.redirected) return window.location.reload()

    // Only what this application wrote for this address is spliced into the
    // page, and only a header it sets itself can say so. Two documents would
    // otherwise land in the console: the `502` nginx answers out of its own
    // pocket when nothing runs behind it, and `public/500.html`, whose
    // stylesheet would apply to everything around it.
    if (response.headers.get('Deferred-Fragment') !== '1') return this.fail()

    return response.text().then((html) => { this.element.outerHTML = html })
  }

  // Written into the announced paragraph rather than over it: replacing the
  // element would take the `role="status"` with it, and the sentence would
  // arrive where nothing reads it out. The wording comes from the server — no
  // French lives in this file.
  fail() {
    this.spinnerTarget.hidden = true
    this.messageTarget.textContent = this.failedValue
  }
}
