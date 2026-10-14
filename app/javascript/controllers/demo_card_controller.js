import { Controller } from "@hotwired/stimulus"

// The two choices one card of the documents page offers: the member state it
// resolves its requirement in, and — where that country publishes several —
// the evidence type it asks for. And the answers it gives to the questions the
// Data Service Directory asks before it can name the provider, which go out
// together as soon as the last of them is given, and replace only what the
// resolution says. Choosing in either list sends the choice at
// once, and the server answers the card resolved on it: only what that choice
// changes is replaced — the country, everything under the list of countries;
// the type, the foot of the card with its document and its button. Neither list
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
const REPLACED = { country: ['top', 'foot'], type: ['foot'], answer: ['resolution'] }

// What the arriving card must still offer for its answer to be spliced in: a
// card that no longer does follows a request made meanwhile, in another tab.
const OFFERED = { country: 'countrySelect', type: 'typeSelect', answer: 'questions' }

// A question of the Data Service Directory.
const QUESTION = '[data-demo-card-question]'

export default class extends Controller {
  static targets = ["top", "foot", "status", "resolution",
    "countrySelect", "countryGroup", "countryFailure",
    "typeSelect", "typeGroup", "typeFailure",
    "questions", "answerFailure"]

  // What each list stands on, which it returns to when a choice gets no
  // answer: the card still names what it named there. A card following a
  // request renders neither list.
  countrySelectTargetConnected(select) {
    this.chosen = { ...this.chosen, country: select.value }
  }

  typeSelectTargetConnected(select) {
    this.chosen = { ...this.chosen, type: select.value }
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
    fetch(new Request(form.action, { method: 'POST', body: new FormData(form), headers: { 'Accept': 'text/html' } }))
      .then((response) => this.receive(response, list), () => this.fail(list))
  }

  // Nothing leaves while a question is unanswered — chapter 3.1.4 §4.4.3.3:
  // « For each EvidenceProviderClassification of the DSD:ERR:0005 a separate
  // answer must be provided by the user » —: the next answer given sends them
  // all. A field left by its Enter key has already said so by its `change`, so
  // the submission that key also causes sends nothing more.
  answer(event) {
    if (event.type === 'submit') return event.preventDefault()
    if (![...this.questionsTarget.querySelectorAll(QUESTION)].every(answered)) return

    this.recover()

    const form = this.questionsTarget
    fetch(new Request(form.action, { method: 'POST', body: new FormData(form), headers: { 'Accept': 'text/html' } }))
      .then((response) => this.receive(response, 'answer'), () => this.fail('answer'))
  }

  // Only what this application wrote for this address is spliced into the card,
  // and only a header it sets itself can say so. A `5xx` without it — the
  // directories out of reach, an error of the server, a proxy with nothing
  // behind it — is the card's to say. Anything else is the page's: a session
  // gone redirects to the login page, a form token refused answers `422`, and
  // reloading is what shows either.
  receive(response, list) {
    if (response.redirected) return window.location.reload()

    if (response.headers.get('Deferred-Fragment') !== '1') {
      return response.status >= 500 ? this.fail(list) : window.location.reload()
    }

    // A body cut short is the network again, and only that.
    return response.text().then((html) => this.splice(html, list), () => this.fail(list))
  }

  splice(html, list) {
    const card = new DOMParser().parseFromString(html, 'text/html').body.firstElementChild
    const names = REPLACED[list]
    const arriving = names.map((name) => card?.querySelector(`[data-demo-card-target~="${name}"]`))

    // A card that no longer offers the choice follows a request made meanwhile,
    // in another tab: the page says that better than a list left dangling.
    if (!card?.querySelector(`[data-demo-card-target~="${OFFERED[list]}"]`) || arriving.includes(null)) {
      return window.location.reload()
    }

    this.element.className = card.className
    names.forEach((name, index) => { this.part(name).innerHTML = arriving[index].innerHTML })

    // The prompt is offered only until a type is chosen, and the list is not
    // replaced: it goes here, the server rendering the list without it.
    if (list === 'type') this.typeSelectTarget.querySelector('option[value=""]')?.remove()
    if (list === 'answer') this.questionsTarget.querySelectorAll('select option[value=""]').forEach((prompt) => prompt.remove())

    if (list !== 'answer') this.chosen = { ...this.chosen, [list]: this.select(list).value }
    this.announce(names.flatMap((name) => [...this.part(name).querySelectorAll(ANNOUNCED)]))
  }

  // The list back on what the card stands on, and the sentence the server
  // rendered shown beside it, in the error state the DSFR gives the group and
  // announced by the region the card already has.
  fail(list) {
    if (list === 'answer') {
      this.answerFailureTarget.hidden = false
      return this.announce([this.answerFailureTarget])
    }

    const select = this.select(list)
    const failure = this.failure(list)

    select.value = this.chosen[list]
    failure.hidden = false
    this.group(list).classList.add(ERROR)
    select.setAttribute('aria-describedby', failure.id)
    this.announce([failure])
  }

  recover() {
    if (this.hasQuestionsTarget) this.answerFailureTarget.hidden = true

    for (const list of ['country', 'type']) {
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

