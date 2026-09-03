import { Controller } from "@hotwired/stimulus"

// A client-side filter: the page renders everything the directory answered,
// and the field hides the entries that do not match what is typed.
//
// Server-side, the same would take a request and a reload per keystroke, where
// these listings hold a few dozen entries already loaded.
//
// The tally is rewritten from the forms the server rendered into `data-tally`:
// the French plurals live in `config/locales/fr.yml` and nowhere else, `COUNT`
// standing there for the number.
//
// What is narrowed is named by CSS selector rather than by target: what is
// narrowed, what tallies it and what is said when nothing is left are three
// parts of a page, and `SearchFieldComponent` says why it does not reach into
// them.

const flatten = (text) =>
  text.toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '')

// The words of an entry: anything that is neither letter nor digit separates,
// so a code in brackets — « (AT) » — is searched for as a word.
const words = (text) => flatten(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean)

// Each term typed must begin a word of the entry. Searched anywhere in the
// text, the two letters of a country code would turn up in half the wordings —
// « AT » inside « certificat ».
const matches = (found, terms) =>
  terms.every((term) => found.some((word) => word.startsWith(term)))

const say = (forms, count) => (forms[count] || forms.other).replace('COUNT', count)

// An entry weighs what it holds — a providing country counts for its evidence
// types — and one for itself failing that.
const weight = (item) => Number(item.dataset.tallyWeight || 1)

export default class extends Controller {
  static values = { entries: String, tally: String, empty: String }

  // `connect` and not `DOMContentLoaded`: two pages of the console fetch their
  // listing after they have loaded, and the field arrives with it.
  connect() {
    // The words of an entry are taken once: the rendered text no longer moves.
    this.items = Array.from(document.querySelectorAll(this.entriesValue))
      .map((element) => ({ element, words: words(element.textContent) }))
    this.tally = this.hasTallyValue && document.querySelector(this.tallyValue)
    this.empty = this.hasEmptyValue && document.querySelector(this.emptyValue)
    this.forms = this.tally && JSON.parse(this.tally.dataset.tally)

    this.apply()
  }

  apply() {
    const terms = words(this.element.value)
    let counted = 0
    let entries = 0

    this.items.forEach((item) => {
      const kept = matches(item.words, terms)

      item.element.hidden = !kept
      if (!kept) return

      entries += 1
      counted += weight(item.element)
    })

    if (this.tally) this.tally.textContent = say(this.forms, counted)
    // The empty state answers « is anything left on screen », which is not what
    // the tally counts: an entry can be shown and weigh nothing, a country
    // declaring it issues no evidence type being one. Keyed on the tally, the
    // page would say nothing matches under an entry the reader can see.
    if (this.empty) this.empty.hidden = entries > 0
  }
}
