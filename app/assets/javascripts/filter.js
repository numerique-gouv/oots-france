// A client-side filter: the page renders everything the directory answered,
// and the field hides the entries that do not match what is typed.
//
// Server-side, the same would take a request and a reload per keystroke, where
// these listings hold a few dozen entries already loaded.
//
// The tally is rewritten from the forms the server rendered into `data-tally`:
// the French plurals live in `config/locales/fr.yml` and nowhere else, `COUNT`
// standing there for the number.

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

const wire = (input) => {
  // The words of an entry are taken once: the rendered text no longer moves.
  const items = Array.from(document.querySelectorAll(input.dataset.filter))
    .map((element) => ({ element, words: words(element.textContent) }))
  const tally = document.querySelector(input.dataset.filterTally)
  const empty = document.querySelector(input.dataset.filterEmpty)
  const forms = tally && JSON.parse(tally.dataset.tally)

  const apply = () => {
    const terms = words(input.value)
    let shown = 0

    items.forEach((item) => {
      const kept = matches(item.words, terms)

      item.element.hidden = !kept
      if (kept) shown += weight(item.element)
    })

    if (tally) tally.textContent = say(forms, shown)
    if (empty) empty.hidden = shown > 0
  }

  input.addEventListener('input', apply)
  apply()
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('input[data-filter]').forEach(wire)
})
