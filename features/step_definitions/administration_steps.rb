COUNTRIES = {
  'finlandaise' => 'FI',
  'allemande' => 'DE',
}.freeze

Étantdonné('une conversation délivrée avec la Finlande') do
  create(:conversation, :delivered, country_code: COUNTRIES.fetch('finlandaise'))
end

Étantdonné("une conversation en échec avec l'Allemagne") do
  create(:conversation, :failed, country_code: COUNTRIES.fetch('allemande'))
end

Quand("j'ouvre la liste des conversations") do
  visit admin_conversations_path
end

Quand("j'ouvre la fiche de la conversation {word}") do |nationality|
  visit admin_conversation_path(conversation_named(nationality).conversation_id)
end

Quand("je filtre sur l'état {string}") do |state|
  select state, from: 'status'
  click_button 'Filtrer'
end

Alors("je vois la conversation {word} avec l'état {string}") do |nationality, state|
  ligne = find('tbody tr', text: conversation_named(nationality).conversation_id)

  expect(ligne).to have_text(state)
end

Alors('je ne vois plus la conversation {word}') do |nationality|
  expect(page).to have_no_text(conversation_named(nationality).conversation_id)
end

Alors("je lis le code d'erreur {string}") do |code|
  expect(page).to have_text(code)
end

Alors("je lis la raison de l'échec de la conversation {word}") do |nationality|
  expect(page).to have_text(conversation_named(nationality).error_description)
end

def conversation_named(nationality)
  Conversation.find_by!(country_code: COUNTRIES.fetch(nationality))
end
