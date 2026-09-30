import { Controller } from "@hotwired/stimulus"

// The member state one card of the documents page resolves its requirement in.
// Choosing it in the list sends it at once, and the server answers the card
// resolved in that country: only what the resolution produces is replaced — the
// line naming the country, and the foot of the card with its document and its
// button, or the sentence saying nothing satisfies it. The list is never
// replaced, so it keeps the focus, and the change is announced by a region that
// is not replaced either: a content update, not the change of context RGAA 7.4
// forbids a choice in a list to cause by itself.
//
// The server decides everything the card says, and nothing here writes a word.

// What each replaced part of the card says, read out once it has arrived.
const ANNOUNCED = '[data-demo-country-announced]'

// The state the DSFR gives a list whose group carries an error text.
const ERROR = 'fr-select-group--error'

export default class extends Controller {
  static targets = ["select", "resolution", "status", "group", "failure"]

  // The country the card stands in, which the list returns to when a choice
  // gets no answer: the card still names what it named there. A card following
  // a request renders no list, and so has no country to return to.
  selectTargetConnected(select) {
    this.country = select.value
  }

  // Sent as the form was built — the CSRF token and the `_method` are in it —
  // so that what leaves is what a submission would have sent. What the failure
  // said is no longer what is happening, so it goes before anything is asked.
  choose() {
    const form = this.selectTarget.form

    this.recover()

    // Only a request that never reached the server fails here: `fetch` rejects
    // on no status of its own, so this is the network itself and not an answer.
    // An error in handling an answer that did arrive is not an outage.
    fetch(new Request(form.action, { method: 'POST', body: new FormData(form), headers: { 'Accept': 'text/html' } }))
      .then((response) => this.receive(response), () => this.fail())
  }

  // Only what this application wrote for this address is spliced into the card,
  // and only a header it sets itself can say so. A `5xx` without it — the
  // directories out of reach, an error of the server, a proxy with nothing
  // behind it — is the card's to say. Anything else is the page's: a session
  // gone redirects to the login page, a form token refused answers `422`, and
  // reloading is what shows either.
  receive(response) {
    if (response.redirected) return window.location.reload()

    if (response.headers.get('Deferred-Fragment') !== '1') {
      return response.status >= 500 ? this.fail() : window.location.reload()
    }

    // A body cut short is the network again, and only that.
    return response.text().then((html) => this.splice(html), () => this.fail())
  }

  splice(html) {
    const card = new DOMParser().parseFromString(html, 'text/html').body.firstElementChild
    const arriving = card?.querySelectorAll('[data-demo-country-target="resolution"]') ?? []

    // A card that no longer offers the choice follows a request made meanwhile,
    // in another tab: the page says that better than a list left dangling.
    if (!card?.querySelector('select') || arriving.length !== this.resolutionTargets.length) {
      return window.location.reload()
    }

    this.element.className = card.className
    this.resolutionTargets.forEach((target, index) => { target.innerHTML = arriving[index].innerHTML })
    this.country = this.selectTarget.value
    this.announce(this.element.querySelectorAll(ANNOUNCED))
  }

  // The list back on the country the card stands in, and the sentence the
  // server rendered shown beside it, in the error state the DSFR gives the
  // group and announced by the region the card already has.
  fail() {
    this.selectTarget.value = this.country
    this.failureTarget.hidden = false
    this.groupTarget.classList.add(ERROR)
    this.selectTarget.setAttribute('aria-describedby', this.failureTarget.id)
    this.announce([this.failureTarget])
  }

  recover() {
    this.failureTarget.hidden = true
    this.groupTarget.classList.remove(ERROR)
    this.selectTarget.removeAttribute('aria-describedby')
    this.statusTarget.textContent = ''
  }

  announce(parts) {
    this.statusTarget.textContent = [...parts]
      .map((part) => part.textContent.replace(/\s+/g, ' ').trim())
      .join(' ')
  }
}
