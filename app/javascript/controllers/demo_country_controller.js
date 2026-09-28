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

export default class extends Controller {
  static targets = ["select", "resolution", "status"]

  // Sent as the form was built — the CSRF token and the `_method` are in it —
  // so that what leaves is what a submission would have sent.
  choose() {
    const form = this.selectTarget.form

    fetch(new Request(form.action, { method: 'POST', body: new FormData(form), headers: { 'Accept': 'text/html' } }))
      .then((response) => this.receive(response))
      // The network itself: the page is what says the directories are out of
      // reach, and reloading it is what shows that.
      .catch(() => window.location.reload())
  }

  // Only what this application wrote for this address is spliced into the card,
  // and only a header it sets itself can say so. Anything else — a session gone,
  // a directory out of reach, a proxy answering for nobody — is the page's to
  // say, so the page is loaded again.
  receive(response) {
    if (response.redirected || response.headers.get('Deferred-Fragment') !== '1') return window.location.reload()

    return response.text().then((html) => this.splice(html))
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
    this.statusTarget.textContent = [...this.element.querySelectorAll(ANNOUNCED)]
      .map((part) => part.textContent.replace(/\s+/g, ' ').trim())
      .join(' ')
  }
}
