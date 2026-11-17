POINTS_D_ACCES = '/admin/common_services/access_points'.freeze

# The blocks of the page, as either browser reads them: the HTTP client of the
# end-to-end scenarios, or the headless browser of the `@javascript` ones.
def bloc_du_point_d_acces(partie)
  return page.find('.access-point', text: partie) unless @navigateur

  Nokogiri::HTML(@navigateur.body).css('.access-point')
    .find { |candidate| candidate.at_css('.access-point__name')&.text == partie }
end

# The country of each party is the code its name carries, under the scheme
# that says it: `AP_EL_01` is Greek.
def passerelle_doublee(*parties)
  base = 'http://domibus:8080/domibus'
  allow(Settings).to receive_messages(domibus_base_url: base, domibus_credentials: { login: 'oots', password: 'secret' })
  stub_code_list(countries: { 'AT' => 'Autriche (l’)', 'EL' => 'Grèce (la)', 'IT' => 'Italie (l’)' })

  parties_du_pmode = parties.map do |partie|
    { name: partie, endpoint: 'https://as4.oots.example.eu/domibus/services/msh',
      identifiers: [{ partyId: partie,
                      partyIdType: { value: "urn:oasis:names:tc:ebcore:partyid-type:unregistered:#{partie[3, 2]}" } }] }
  end
  stub_request(:get, "#{base}/ext/party").with(query: hash_including({}))
    .to_return(body: parties_du_pmode.to_json, headers: { 'Content-Type' => 'application/json' })
  stub_request(:get, "#{base}/ext/truststore/entries")
    .to_return(body: [].to_json, headers: { 'Content-Type' => 'application/json' })
end

Étantdonné("une passerelle doublée dont le PMode déclare le point d'accès {string}") do |partie|
  passerelle_doublee(partie)
end

Étantdonné("une passerelle doublée dont le PMode déclare les points d'accès {string} et {string}") do |premiere, seconde|
  passerelle_doublee(premiere, seconde)
end

Étantdonné("une passerelle doublée dont le PMode déclare les points d'accès {string}, {string} et {string}") do |*parties|
  passerelle_doublee(*parties)
end

Quand("l'administrateur ouvre la page des points d'accès") do
  next @navigateur.visit(POINTS_D_ACCES) if @navigateur

  visit POINTS_D_ACCES
  # A mark on the window, which a reload would wipe: what lets a later step say
  # the page did not reload.
  page.execute_script('window.pageNonRechargee = true')
  # Every block taken out of the list, moved or replaced: what lets a later step
  # say which blocks moved.
  page.execute_script(<<~JS)
    window.blocsDeplaces = []
    new MutationObserver((records) => records.forEach((record) =>
      record.removedNodes.forEach((node) => node.dataset && window.blocsDeplaces.push(node.dataset.party))
    )).observe(document.querySelector('.access-points'), { childList: true })
  JS
end

Quand("il teste le point d'accès {string}") do |partie|
  next @navigateur.submit_to('/admin/common_services/connectivity_tests', party: partie) if @navigateur

  bloc_du_point_d_acces(partie).click_button(I18n.t('admin.common_services.access_points.index.test'))
end

Quand("il teste tous les points d'accès") do
  click_button I18n.t('admin.common_services.access_points.index.test_all')
end

Alors("le point d'accès {string} affiche {string}, sans bouton de test") do |partie, issue|
  bloc = bloc_du_point_d_acces(partie)

  # The DSFR badge upper-cases what it says, on screen and nowhere else.
  expect(bloc).to have_css('.fr-badge', text: /\A#{Regexp.escape(issue)}\z/i)
  expect(bloc).to have_no_button(I18n.t('admin.common_services.access_points.index.test'))
  expect(bloc['aria-busy']).to eq('true')
end

# The click that records the `ConnectivityTest` is served a moment after the
# step that made it.
def test_enregistre(partie)
  wait_until("Aucun test de connectivité enregistré pour #{partie} : le clic n'a pas été servi.") do
    ConnectivityTest.exists?(party_name: partie)
  end
  ConnectivityTest.find_by!(party_name: partie)
end

# The verdict as `ConnectivityTesting::ReadVerdict` records it: what follows is
# the page noticing, which is the subject here.
Quand("la France lit dans la passerelle que le point d'accès {string} a acquitté le test") do |partie|
  test_enregistre(partie).acknowledged!
end

Quand("la France lit dans la passerelle que le point d'accès {string} est en échec") do |partie|
  test_enregistre(partie).failed!(nil)
end

def page_non_rechargee
  expect(page.evaluate_script('window.pageNonRechargee')).to be(true)
end

Alors("le point d'accès {string} affiche {string}, sans que la page se soit rechargée") do |partie, issue|
  expect(bloc_du_point_d_acces(partie)).to have_css('.fr-badge', text: /\A#{Regexp.escape(issue)}\z/i)
  page_non_rechargee
end

# The gateway notifies nothing about a test message: its verdict is read by
# jobs, so the page is opened again until it says it.
Alors("la page des points d'accès affiche {string} pour {string}") do |issue, partie|
  patiente_jusqu_a("la ligne de #{partie} affiche « #{issue} »") do
    @navigateur.visit(POINTS_D_ACCES)

    bloc_du_point_d_acces(partie)&.at_css('.fr-badge')&.text.to_s.strip == issue
  end
end

# Capybara waits for an element, not for an order: the blocks are read again
# until they stand as expected.
def noms_dans_l_ordre
  page.document.synchronize do
    noms = page.all('.access-point__name').map(&:text)
    raise Capybara::ExpectationNotMet, "Les points d'accès se lisent #{noms.join(', ')}" unless yield(noms)
  end
end

Alors("le point d'accès {string} précède {string}") do |premiere, seconde|
  noms_dans_l_ordre do |noms|
    rangs = [noms.index(premiere), noms.index(seconde)]
    rangs.all? && rangs.first < rangs.last
  end
end

Alors("les points d'accès se lisent {string}, {string} et {string}") do |*attendus|
  noms_dans_l_ordre { |noms| noms == attendus }
end

Alors("la page ne s'est pas rechargée") do
  page_non_rechargee
end

# A property set on the element in the browser: it survives the element being
# moved, not the element being replaced by another.
Quand("une marque est posée sur le bloc du point d'accès {string}") do |partie|
  page.execute_script('arguments[0].marque = true', bloc_du_point_d_acces(partie))
end

Alors("seul le bloc du point d'accès {string} s'est déplacé") do |partie|
  expect(page.evaluate_script('window.blocsDeplaces')).to eq([partie])
end

Alors("le bloc du point d'accès {string} porte encore la marque") do |partie|
  expect(page.evaluate_script('arguments[0].marque === true', bloc_du_point_d_acces(partie))).to be(true)
end

Alors("le bloc du point d'accès {string} porte {string} à {string}") do |partie, attribut, valeur|
  expect(bloc_du_point_d_acces(partie)[attribut]).to eq(valeur)
end

Alors("le bloc du point d'accès {string} porte {string} à {string}, et plus {string}") do |partie, attribut, valeur, retire|
  bloc = bloc_du_point_d_acces(partie)

  expect(bloc[attribut]).to eq(valeur)
  expect(bloc[retire]).to be_nil
end
