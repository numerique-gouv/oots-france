import { Controller } from "@hotwired/stimulus"

// The zone of the documents page where the document is asked for. It answers its
// own address, so both the press and the waiting come back as the contents of
// this element and replace them.
//
// The server decides what the zone says and whether it is still waiting: a
// fragment that stops declaring `data-polling` is what ends the asking. The one
// thing the server cannot say is that it could not be reached, and that is the
// whole of what this controller decides on its own.
//
// The element itself is never replaced: it carries the `aria-live` region, and a
// region swapped out along with what it announces announces nothing.

const INTERVAL = 2000

// How many answers in a row the page may fail to get before it says so. A blip
// in the middle of a wait is not worth ending a journey on; a service that has
// stopped answering is, and nothing else will report it.
const ATTEMPTS = 3

export default class extends Controller {
  static targets = ["press", "loading", "failure", "disconnected"]
  static values = { url: String }

  connect() {
    this.failures = 0
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // The press. Sent as the form was built — `button_to` puts the CSRF token in
  // it — so that what leaves is what would have left without this controller.
  //
  // The waiting takes the press's place at once, before anything has been asked
  // of anyone: the answer is a round trip away, and a screen that says nothing
  // until it comes back leaves the user pressing again. Both were rendered by
  // the server, so nothing here writes a word; what comes back replaces the two
  // of them.
  submit(event) {
    event.preventDefault()

    this.failures = 0
    this.show(this.loadingTargets)
    this.hide(this.pressTargets)
    // What each reports is no longer what is happening.
    this.hide(this.failureTargets)
    this.hide(this.disconnectedTargets)

    this.ask(event.target.action, { method: 'POST', body: new FormData(event.target) })
  }

  // The header goes in with the rest and never in a second argument to `fetch`:
  // that argument replaces the whole header list, and the `Content-Type` a
  // `FormData` body writes for itself — boundary included — would go with it,
  // leaving the server a multipart it cannot cut up.
  ask(url, options = {}) {
    fetch(new Request(url, { ...options, headers: { 'Accept': 'text/html' } }))
      .then((response) => this.receive(response))
      // A request that never reached the server: `fetch` rejects on no status of
      // its own, so this is the network itself and not an answer.
      .catch(() => this.fail())
  }

  receive(response) {
    // A browser without the session cookie is sent to the login page, which
    // belongs in the window rather than inside a card. Reloading takes it there,
    // and the guard remembers the address it refused.
    if (response.redirected) return window.location.reload()

    // Only what this application wrote for this address is spliced into the
    // page, and only a header it sets itself can say so. Two documents would
    // otherwise land in the card: the `502` nginx answers out of its own pocket
    // when nothing runs behind it, and `public/500.html`, whose stylesheet would
    // apply to everything around it. Neither is an answer, so both fail here.
    if (response.headers.get('Deferred-Fragment') !== '1') return this.fail()

    return response.text().then((html) => {
      this.element.innerHTML = html
      this.failures = 0
      this.schedule()
    })
  }

  // No answer, or one this application did not write. A wait under way may try
  // again on its own, a few times over; a press made from rest has nothing
  // waiting behind it and must not (`polling` is then false), which is why this
  // counts rather than trusting the fragment: the fragment on screen is the one
  // that never got replaced.
  //
  // What giving up offers is a way back to the page, never the press: pressing
  // would ask for the document a second time, and chapter 4.4 §4.1 makes that a
  // second exchange — opened while the first is still under way, and losing it,
  // since the session follows one at a time. Reloading asks nobody anything and
  // resumes from whatever the server says of the exchange already open.
  fail() {
    this.failures += 1

    if (this.polling && this.failures < ATTEMPTS) return this.schedule()

    clearTimeout(this.timer)
    this.hide(this.loadingTargets)
    this.show(this.disconnectedTargets)
  }

  // One tick at a time rather than a repeating timer: a server slower than the
  // interval would otherwise be asked again before it has answered.
  schedule() {
    clearTimeout(this.timer)

    if (this.polling) this.timer = setTimeout(() => this.ask(this.urlValue), INTERVAL)
  }

  get polling() {
    return this.element.querySelector('.demo-request__body')?.dataset.polling === 'true'
  }

  // Plural targets throughout: a settled zone renders neither press nor waiting,
  // and a zone with nothing to refuse renders no alert — where the singular form
  // throws on a target that is not there, this one is simply empty.
  hide(targets) {
    targets.forEach((target) => { target.hidden = true })
  }

  show(targets) {
    targets.forEach((target) => { target.hidden = false })
  }
}
