import { Controller } from "@hotwired/stimulus"

// The zone of the documents page where the documents are asked for, a block per
// evidence type of the card's combination. It answers its own address, so the
// buttons and the waitings of every block come back as the contents of this
// element and replace them.
//
// The server decides what the zone says and whether it is still waiting: a
// fragment that stops declaring `data-polling` is what ends the asking. The one
// thing the server cannot say is that it could not be reached, and that is the
// whole of what this controller decides on its own.
//
// The element itself is never replaced: it carries the `aria-live` region, and a
// region swapped out along with what it announces announces nothing.

const INTERVAL = 2000

// How long a click or an interrogation waits for its answer, in milliseconds.
const DEADLINE = 30000

// What an answer replaces, and what it says of itself.
const BODY = '.demo-request__body'

// One block of the zone, and what it says of itself.
const BLOCK = '[data-demo-request-block]'

// The one word of the server's vocabulary this controller has to know: a click
// puts the waiting on screen before anything has been asked of anyone, so the
// zone has to say it is waiting too — see `splice`.
const PENDING = 'pending'

// What a block says once a request of its type is under way or delivered:
// news a refusal of the contract does not outweigh. Anything else — the
// button, or an earlier request's ending — is older than the refusal.
const SUPERSEDING = ['pending', 'preview', 'delivered']

// What a polled block says of itself: the states `polling?` re-asks for.
const POLLED = ['pending', 'preview']

// How many answers in a row the page may fail to get before it says so. A blip
// in the middle of a wait is not worth ending a journey on; a service that has
// stopped answering is, and nothing else will report it.
const ATTEMPTS = 3

export default class extends Controller {
  static targets = ["button", "loading", "failure", "disconnected"]
  static values = { url: String }

  connect() {
    this.failures = 0
    this.clicks = 0
    this.clicking = false
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // The click. Sent as the form was built — `button_to` puts the CSRF token in
  // it — so that what leaves is what would have left without this controller.
  //
  // The waiting takes the button's place at once, before anything has been asked
  // of anyone: the answer is a round trip away, and a screen that says nothing
  // until it comes back leaves the user clicking again. Both were rendered by
  // the server, so nothing here writes a word.
  //
  // Only the button's own form: the departure page may hold another, the one a
  // correspondent asked a `POST` for, and that one leaves the page as forms do.
  // Only the block clicked in: the others follow their own requests.
  //
  // One click at a time in a zone: while one is out, the zone's other buttons
  // take no click. A refusal of the contract is said only in the answer to its
  // own click, and the server can only answer for the clicks it has received —
  // an answer read while a second click was on its way would offer that one's
  // button again, a second click being a second exchange (chapter 4.4 §4.1).
  submit(event) {
    if (!this.buttonTargets.includes(event.target)) return

    event.preventDefault()
    if (this.clicking) return

    const block = event.target.closest(BLOCK)

    this.failures = 0
    this.show(this.within(block, this.loadingTargets))
    this.hide(this.within(block, this.buttonTargets))
    // What each reports is no longer what is happening.
    this.hide(this.within(block, this.failureTargets))
    delete block.dataset.refusedClick
    this.hide(this.within(block, this.disconnectedTargets))
    this.gaveUp = false
    this.declareWaiting(block)

    clearTimeout(this.timer)
    this.clicks += 1
    this.clicking = true
    this.offerButtons(false)
    this.ask(event.target.action, { method: 'POST', body: new FormData(event.target) }, { click: true })
  }

  // The header goes in with the rest and never in a second argument to `fetch`:
  // that argument replaces the whole header list, and the `Content-Type` a
  // `FormData` body writes for itself — boundary included — would go with it,
  // leaving the server a multipart it cannot cut up.
  //
  // An interrogation is a reading of the zone at the moment it was asked: one
  // asked before a click, or answered while the click is still out, says what
  // the zone was before that click, and would put its button back on screen. So
  // it is dropped, the click's own answer saying what the zone has become, and
  // the asking goes on from there.
  //
  // Each with a deadline, so that a server that never answers ends as one that
  // cannot be reached rather than in a waiting without end.
  //
  // A click holds the zone until what it brought back is on screen, not merely
  // until its answer began to arrive.
  ask(url, options = {}, { click = false } = {}) {
    const asked = this.clicks
    const current = () => click || (asked === this.clicks && !this.clicking)

    return Promise.resolve()
      .then(() => fetch(new Request(url, { ...options, headers: { 'Accept': 'text/html' }, signal: AbortSignal.timeout(DEADLINE) })))
      .then(
        (response) => (current() ? this.receive(response, current) : this.schedule()),
        // A request that never reached the server: `fetch` rejects on no status
        // of its own, so this is the network itself and not an answer.
        () => (current() ? this.fail() : this.schedule()),
      )
      // An answer that arrived and could not be read: the zone says it as it
      // says the network, and the console keeps why.
      .catch((error) => {
        console.error(error)
        if (current()) this.fail()
      })
      .finally(() => { if (click) this.release() })
  }

  // The click is over: the zone takes clicks again, and asks again if anything
  // asked for it meanwhile.
  release() {
    this.clicking = false
    this.offerButtons(true)

    if (this.rescheduled) this.schedule()
  }

  receive(response, current = () => true) {
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
      // A click made while this was read makes it a reading of the zone before
      // that click.
      if (!current()) return this.schedule()

      this.splice(html)
      this.failures = 0
      this.schedule()
    })
  }

  // An answer that says what the zone is already saying replaces nothing. The
  // waiting is one waiting: it starts under the button and ends when the document
  // arrives. Built again it would start its spinner over and announce the same
  // sentence a second time in the `aria-live` region — which is read as a second
  // wait beginning, a first one having apparently failed.
  //
  // What a fragment says is its outcome, and that is what is compared: two
  // waitings are the same waiting even when what surrounds them differs, and any
  // other answer — the document, a refusal — is a change and takes the zone.
  //
  // A block whose click the contract refused keeps its alert while its
  // neighbours are polled: no exchange holds that refusal, so the zone the
  // server renders next knows nothing of it and offers the button instead.
  splice(html) {
    const arriving = new DOMParser().parseFromString(html, 'text/html').querySelector(BODY)

    if (!arriving) {
      this.element.innerHTML = html
      return this.offerButtons(!this.clicking)
    }

    this.keepRefusedClicks(arriving)
    if (arriving.dataset.outcome === this.body?.dataset.outcome) return

    this.element.replaceChildren(arriving)
    this.offerButtons(!this.clicking)
  }

  keepRefusedClicks(arriving) {
    if (!this.body) return

    this.body.querySelectorAll(`${BLOCK}[data-refused-click="true"]`).forEach((refused) => {
      const same = arriving.querySelector(`${BLOCK}[data-demo-request-block="${refused.dataset.demoRequestBlock}"]`)
      if (same && !SUPERSEDING.includes(same.dataset.state)) same.replaceWith(document.importNode(refused, true))
    })
    arriving.dataset.outcome = outcomeOf(arriving)
  }

  // The zone made to say what the click has just put on screen. Without this the
  // answer to the click — a waiting, since that is what the click opened — would
  // arrive as a change of state and replace the waiting with an identical one.
  declareWaiting(block) {
    if (!this.body) return

    block.dataset.state = PENDING
    this.body.dataset.polling = 'true'
    this.body.dataset.outcome = outcomeOf(this.body)
  }

  // No answer, or one this application did not write. A wait under way tries
  // again a few times over before saying so: a blip in the middle of a journey
  // is not worth ending it on. The count is this controller's own rather than
  // the fragment's, the fragment on screen being the one that never got
  // replaced.
  //
  // A click whose own answer is lost is a wait too, and retrying it asks nobody
  // for a second document: what a retry sends is the consultation of `schedule`,
  // which chapter 4.4 §4.1 leaves free to be repeated.
  //
  // What giving up offers is a way back to the page, never the button: clicking
  // would ask for the document a second time, and chapter 4.4 §4.1 makes that a
  // second exchange — opened while the first is still under way, and losing it,
  // since the session follows one at a time. Reloading asks nobody anything and
  // resumes from whatever the server says of the exchange already open.
  fail() {
    this.failures += 1

    if (this.polling && this.failures < ATTEMPTS) return this.schedule()

    clearTimeout(this.timer)
    this.rescheduled = false
    this.gaveUp = true

    // Said in each block that was waiting — a click under way, or a request the
    // zone was polling for — and everywhere when none can be told.
    const waiting = [...this.element.querySelectorAll(BLOCK)]
      .filter((block) => POLLED.includes(block.dataset.state) || this.within(block, this.loadingTargets).some((loading) => !loading.hidden))
    const said = waiting.length ? waiting : [...this.element.querySelectorAll(BLOCK)]

    this.hide(this.loadingTargets)
    this.show(this.disconnectedTargets.filter((disconnected) => said.some((block) => block.contains(disconnected))))
  }

  // One tick at a time rather than a repeating timer: a server slower than the
  // interval would otherwise be asked again before it has answered.
  schedule() {
    clearTimeout(this.timer)
    this.rescheduled = this.clicking
    // Once the zone has said it could not reach the service, only a click asks
    // again: a reading answered late is not a sign the service is back.
    if (this.clicking || this.gaveUp) return

    if (this.polling) this.timer = setTimeout(() => this.ask(this.urlValue), INTERVAL)
  }

  get polling() {
    return this.body?.dataset.polling === 'true'
  }

  get body() {
    return this.element.querySelector(BODY)
  }

  // The buttons of the zone, which take no click while one is out.
  offerButtons(offered) {
    this.element.querySelectorAll('.demo-request__button button').forEach((button) => { button.disabled = !offered })
  }

  within(block, targets) {
    return targets.filter((target) => block.contains(target))
  }

  // Plural targets throughout: a settled zone renders neither button nor waiting,
  // and a zone with nothing to refuse renders no alert — where the singular form
  // throws on a target that is not there, this one is simply empty.
  hide(targets) {
    targets.forEach((target) => { target.hidden = true })
  }

  show(targets) {
    targets.forEach((target) => { target.hidden = false })
  }
}

// What a zone says, block by block, as `DemoRequestZoneComponent#outcome` writes it.
function outcomeOf(body) {
  return [...body.querySelectorAll(BLOCK)].map((block) => block.dataset.state).join(' ')
}
