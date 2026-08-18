// Un filtre côté client : la page rend tout ce que l'annuaire a répondu, et le
// champ masque les entrées qui ne correspondent pas à ce qui est tapé.
//
// Côté serveur, il faudrait une requête et un rechargement par frappe pour
// autant, alors que ces listes tiennent en quelques dizaines d'entrées déjà
// chargées.
//
// Le décompte est réécrit à partir des formes que le serveur a rendues dans
// `data-tally` : les pluriels français vivent dans `config/locales/fr.yml` et
// nulle part ailleurs, `COUNT` y tenant la place du nombre.

const flatten = (text) =>
  text.toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '')

// Les mots d'une entrée : tout ce qui n'est ni lettre ni chiffre sépare, si
// bien qu'un code entre parenthèses — « (AT) » — se cherche comme un mot.
const words = (text) => flatten(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean)

// Chaque terme tapé doit commencer un mot de l'entrée. Cherchée n'importe où
// dans le texte, la paire de lettres d'un code de pays se retrouverait dans la
// moitié des intitulés — « AT » dans « certificat ».
const matches = (found, terms) =>
  terms.every((term) => found.some((word) => word.startsWith(term)))

const say = (forms, count) => (forms[count] || forms.other).replace('COUNT', count)

// Une entrée pèse ce qu'elle contient — un pays fournisseur compte pour ses
// types de justificatif —, et une pour elle-même à défaut.
const weight = (item) => Number(item.dataset.tallyWeight || 1)

const wire = (input) => {
  // Les mots d'une entrée sont relevés une fois : le texte rendu ne bouge plus.
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
