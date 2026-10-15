import { Controller } from "@hotwired/stimulus"

// The two choices one card of the documents page offers: the member state it
// resolves its requirement in, and — where that country publishes several —
// the combination of evidence types it asks for. And the answers each line of
// the card gives to the questions the Data Service Directory asks before it can
// name that line's provider, which go out together as soon as the last of them
// is given, and replace only what that line's resolution says and the zone.
// Choosing in either list sends the choice at once, and the server answers the
// card resolved on it: only what that choice changes is replaced — the country,
// everything under the list of countries; the combination, the foot of the card
// with its lines and its buttons. Neither list
// is replaced by its own answer, so it keeps the focus, and the change is
// announced by a region that is never replaced either: a content update, not the
// change of context RGAA 7.4 forbids a choice in a list to cause by itself.
//
// The server decides everything the card says, and nothing here writes a word.

// What each replaced part of the card says, read out once it has arrived.
const ANNOUNCED = '[data-demo-card-announced]'

// The state the DSFR gives a list whose group carries an error text.
const ERROR = 'fr-select-group--error'

// What the answer to each choice replaces.
const REPLACED = { country: ['top', 'foot'], combination: ['foot'] }

// What the arriving card must still offer for its answer to be spliced in: a
// card that no longer does follows a request made meanwhile, in another tab.
const OFFERED = { country: 'countrySelect', combination: 'combinationSelect' }

// A question of the Data Service Directory.
const QUESTION = '[data-demo-card-question]'

// How long a choice waits for its answer, in milliseconds: the directories
// are asked two or three times over for one card.
const DEADLINE = 30000

// One line of the foot, an evidence type of the combination, by its UUID.
const LINE = 'data-demo-card-line'

export default class extends Controller {
  static targets = ["top", "foot", "status", "request",
    "countrySelect", "countryGroup", "countryFailure",
    "combinationSelect", "combinationGroup", "combinationFailure"]

  // What each list stands on, which it returns to when a choice gets no
  // answer: the card still names what it named there. A card following a
  // request renders neither list.
  countrySelectTargetConnected(select) {
    this.chosen = { ...this.chosen, country: select.value }
  }

  combinationSelectTargetConnected(select) {
    this.chosen = { ...this.chosen, combination: select.value }
  }

  // Sent as the form was built — the CSRF token and the `_method` are in it —
  // so that what leaves is what a submission would have sent. What a failure
  // said is no longer what is happening, so it goes before anything is asked.
  choose({ params: { list } }) {
    const form = this.select(list).form

    this.recover()

    // Only a request that never reached the server fails here: `fetch` rejects
    // on no status of its own, so this is the network itself and not an answer.
    // An error in handling an answer that did arrive is not an outage.
    this.send(form, list)
  }

  // Nothing leaves while a question of the line is unanswered — chapter 3.1.4
  // §4.4.3.3: « For each EvidenceProviderClassification of the DSD:ERR:0005 a
  // separate answer must be provided by the user » —: the next answer given
  // sends them all. A field left by its Enter key has already said so by its
  // `change`, so the submission that key also causes sends nothing more.
  answer(event) {
    if (event.type === 'submit') return event.preventDefault()

    const form = event.target.closest('form')
    if (![...form.querySelectorAll(QUESTION)].every(answered)) return

    this.recover()

    this.send(form, form)
  }

  // One choice after another, each sent once the answer to the one before has
  // been spliced in: the server writes the card whole at each choice, from
  // what it read of the one before, and two answers sent at once — one line's
  // questions and another's — would each write the card without the other.
  // `FormData` is read now, so that what leaves is what was chosen at this
  // moment.
  //
  // Each with a deadline counted from its own departure, so that one the
  // directories never answer fails as the network does rather than holding
  // every choice after it.
  send(form, choice) {
    const body = new FormData(form)

    const sent = (this.sent ?? 0) + 1
    this.sent = sent
    if (typeof choice === 'string') this.lastSent = { ...this.lastSent, [choice]: sent }

    this.queue = (this.queue ?? Promise.resolve())
      .then(() => {
        this.answering = sent
        // The answers of a line the foot no longer holds: a choice made since
        // replaced it, and what they would resolve is no longer on screen.
        if (typeof choice !== 'string' && !choice.isConnected) throw new Error('demo-card: line replaced before its answers left')
      })
      .then(() => fetch(new Request(form.action, { method: 'POST', body, headers: { 'Accept': 'text/html' }, signal: AbortSignal.timeout(DEADLINE) }))
        .then((response) => this.receive(response, choice), () => this.fail(choice)))
      // An answer that arrived and could not be spliced in leaves the card half
      // written: the page says it whole again, and the console keeps why. The
      // queue goes on from there.
      .catch((error) => {
        console.error(error)
        window.location.reload()
      })
  }

  // Only what this application wrote for this address is spliced into the card,
  // and only a header it sets itself can say so. A `5xx` without it — the
  // directories out of reach, an error of the server, a proxy with nothing
  // behind it — is the card's to say. Anything else is the page's: a session
  // gone redirects to the login page, a form token refused answers `422`, and
  // reloading is what shows either.
  //
  // `choice` is the list chosen in, or the form of a line's questions.
  receive(response, choice) {
    if (response.redirected) return window.location.reload()

    if (response.headers.get('Deferred-Fragment') !== '1') {
      return response.status >= 500 ? this.fail(choice) : window.location.reload()
    }

    // A body cut short is the network again, and only that.
    return response.text().then((html) => this.splice(html, choice), () => this.fail(choice))
  }

  splice(html, choice) {
    const card = new DOMParser().parseFromString(html, 'text/html').body.firstElementChild

    if (typeof choice !== 'string') return this.spliceLine(card, choice)

    const names = REPLACED[choice]
    const arriving = names.map((name) => card?.querySelector(`[data-demo-card-target~="${name}"]`))

    // A card that no longer offers the choice follows a request made meanwhile,
    // in another tab: the page says that better than a list left dangling.
    if (!card?.querySelector(`[data-demo-card-target~="${OFFERED[choice]}"]`) || arriving.includes(null)) {
      return window.location.reload()
    }

    this.element.className = card.className
    names.forEach((name, index) => { this.part(name).innerHTML = arriving[index].innerHTML })

    // The prompt is offered only until a combination is chosen, and the list is
    // not replaced: it goes here, the server rendering the list without it.
    if (choice === 'combination') this.combinationSelectTarget.querySelector('option[value=""]')?.remove()

    this.chosen = { ...this.chosen, [choice]: this.select(choice).value }
    this.announce(names.flatMap((name) => [...this.part(name).querySelectorAll(ANNOUNCED)]))
  }

  // The answer to a line's questions: the resolution of that line, and the
  // zone, which appears once every line names its provider. The questions stay
  // as they are, with the focus and what was typed.
  spliceLine(card, form) {
    const line = form.closest(`[${LINE}]`)
    const selector = `[${LINE}="${line.getAttribute(LINE)}"]`
    const arrivingLine = card?.querySelector(selector)
    const resolution = arrivingLine?.querySelector('[data-demo-card-target~="resolution"]')
    const request = card?.querySelector('[data-demo-card-target~="request"]')

    if (!arrivingLine?.querySelector('[data-demo-card-target~="questions"]') || !resolution || !request) {
      return window.location.reload()
    }

    this.element.className = card.className
    line.querySelector('[data-demo-card-target~="resolution"]').innerHTML = resolution.innerHTML
    this.requestTarget.innerHTML = request.innerHTML

    form.querySelectorAll('select option[value=""]').forEach((prompt) => prompt.remove())

    this.announce([...line.querySelectorAll(ANNOUNCED), ...this.requestTarget.querySelectorAll(ANNOUNCED)])
  }

  // The list back on what the card stands on, and the sentence the server
  // rendered shown beside it, in the error state the DSFR gives the group and
  // announced by the region the card already has. For a line's questions, the
  // sentence under them.
  fail(choice) {
    if (typeof choice !== 'string') {
      const failure = choice.querySelector('[data-demo-card-target~="answerFailure"]')
      failure.hidden = false
      return this.announce([failure])
    }

    // A later choice is on its way, and says more than this one.
    if (this.lastSent?.[choice] !== this.answering) return

    const select = this.select(choice)
    const failure = this.failure(choice)

    select.value = this.chosen[choice]
    failure.hidden = false
    this.group(choice).classList.add(ERROR)
    select.setAttribute('aria-describedby', failure.id)
    this.announce([failure])
  }

  recover() {
    this.element.querySelectorAll('[data-demo-card-target~="answerFailure"]').forEach((failure) => { failure.hidden = true })

    for (const list of ['country', 'combination']) {
      if (!this.hasList(list)) continue

      this.failure(list).hidden = true
      this.group(list).classList.remove(ERROR)
      this.select(list).removeAttribute('aria-describedby')
    }
    this.statusTarget.textContent = ''
  }

  announce(parts) {
    this.statusTarget.textContent = [...parts]
      .map((part) => part.textContent.replace(/\s+/g, ' ').trim())
      .join(' ')
  }

  hasList(list) { return this[`has${capitalised(list)}SelectTarget`] }

  select(list) { return this[`${list}SelectTarget`] }

  group(list) { return this[`${list}GroupTarget`] }

  failure(list) { return this[`${list}FailureTarget`] }

  part(name) { return this[`${name}Target`] }
}

function capitalised(word) { return word.charAt(0).toUpperCase() + word.slice(1) }

// A list on something other than its prompt, a radio button checked, a field
// holding more than blanks.
function answered(question) {
  const fields = [...question.querySelectorAll('select, input')]
  if (fields.some((field) => field.type === 'radio')) return fields.some((field) => field.checked)

  return fields.every((field) => field.value.trim() !== '')
}

