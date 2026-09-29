import { Controller } from "@hotwired/stimulus"

// The zone of the preview space that offers the way back. On the 2.0 line that
// way is only known once the second request has arrived, so the zone asks its
// own address again until the server stops saying it is waiting. The zone
// itself carries the `aria-live` region, so only its contents are replaced.

const INTERVAL = 5000

export default class extends Controller {
  static values = { url: String, waiting: Boolean }

  connect() {
    this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)

    if (this.waitingValue) this.timer = setTimeout(() => this.ask(), INTERVAL)
  }

  ask() {
    fetch(this.urlValue, { headers: { 'Accept': 'text/html' } })
      // A request that never reached the server is asked again; an error of
      // this controller's own is left to surface.
      .then((response) => this.receive(response), () => this.schedule())
  }

  // Only what this application wrote for this address is spliced in, as
  // `deferred_controller.js` does. Anything else stops the asking: the zone's
  // own link to refresh the page is then the way on.
  receive(response) {
    if (response.headers.get('Deferred-Fragment') !== '1') return

    return response.text().then((html) => {
      const arriving = new DOMParser().parseFromString(html, 'text/html').body.firstElementChild
      if (arriving?.dataset.previewReturnWaitingValue === 'true') return this.schedule()

      this.waitingValue = false
      this.element.innerHTML = arriving.innerHTML
    })
  }
}
