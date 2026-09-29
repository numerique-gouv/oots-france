# Chapter 4.9 on the side that asks, played end to end: the portal asks with
# the preview allowed, confirms it, and the user comes back through France's
# return address. France answers itself, so the preview space it follows is
# France's own.

Quand('le portail demande un justificatif pour la démarche {string} en acceptant que l\'usager le voie d\'abord') do |procedure|
  @response = demande(procedure, preview: true)
end

# Chapter 4.9 §5: the portal builds its launch page from the description.
Alors('le portail lit l\'adresse de l\'espace de prévisualisation et sa description') do
  state = etat_de_l_echange

  expect(state['adressePrevisualisation']).to start_with(oots_france_url)
  expect(state['descriptionPrevisualisation']).to include(include('langue' => be_present, 'texte' => be_present))
end

Quand('le portail confirme la prévisualisation avec son jeton et l\'adresse où reprendre la démarche') do
  response = Faraday.post("#{oots_france_url}/requete/#{@exchange_id}/previsualisation",
    beneficiaire: @fake_requester.beneficiary_token(oots_france_url, BENEFICIAIRE),
    adresseRetour: "#{@requester.url}/oots/callback")

  expect(response.status).to eq(202)
  @confirmation = JSON.parse(response.body)
end

Alors('le portail reçoit le lien à présenter à l\'usager') do
  expect(@confirmation).to include('methodePrevisualisation' => 'GET',
    'adressePrevisualisation' => start_with(oots_france_url))
end

Quand('l\'usager ouvre l\'espace de prévisualisation par le lien que le portail lui présente') do
  space_browser.follow_address(@confirmation.fetch('adressePrevisualisation'))
end

# The link appears once the second request has reached the space, which runs
# in parallel with the visit (chapter 4.9 §2 step 12): the page is asked again
# until it offers it.
Quand('l\'usager suit le lien de retour vers sa démarche') do
  relay = "#{oots_france_url}/retour/"

  patiente_jusqu_a('la page offre le lien de retour') do
    space_browser.follow_address(@confirmation.fetch('adressePrevisualisation'))
    space_browser.links('a.fr-btn').any? { |link| link.start_with?(relay) }
  end

  space_browser.follow_address(space_browser.links('a.fr-btn').find { |link| link.start_with?(relay) })
end

Alors('l\'usager arrive sur la page du portail, qui reçoit l\'échange et la conversation') do
  expect(@fake_requester.received_return)
    .to eq('echange' => @exchange_id, 'conversation' => JSON.parse(@response.body)['conversation'])
end

Alors('le journal des échanges contient la seconde requête et le retour de l\'usager') do
  sent = journal.where(event_type: 'request_sent').order(:occurred_at)

  expect(sent.count).to eq(2)
  expect(sent.last.preview_location).to eq(@confirmation.fetch('adressePrevisualisation'))
  expect(journal.find_by!(event_type: 'return_visited').preview_location).to start_with("#{oots_france_url}/retour/")
end
