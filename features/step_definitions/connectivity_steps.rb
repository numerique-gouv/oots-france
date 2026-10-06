POINTS_D_ACCES = '/admin/common_services/access_points'.freeze

# The blocks of the page, as either browser reads them: the HTTP client of the
# end-to-end scenarios, or the headless browser of the `@javascript` ones.
def bloc_du_point_d_acces(partie)
  return page.find('.access-point', text: partie) unless @navigateur

  Nokogiri::HTML(@navigateur.body).css('.access-point')
    .find { |candidate| candidate.at_css('.access-point__name')&.text == partie }
end

Étantdonné("une passerelle doublée dont le PMode déclare le point d'accès {string}") do |partie|
  base = 'http://domibus:8080/domibus'
  allow(Settings).to receive_messages(domibus_base_url: base, domibus_credentials: { login: 'oots', password: 'secret' })
  stub_code_list(countries: { 'EL' => 'Grèce (la)' })

  partie_du_pmode = {
    name: partie, endpoint: 'https://as4.oots.example.gr/domibus/services/msh',
    identifiers: [{ partyId: partie, partyIdType: { value: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL' } }]
  }
  stub_request(:get, "#{base}/ext/party").with(query: hash_including({}))
    .to_return(body: [partie_du_pmode].to_json, headers: { 'Content-Type' => 'application/json' })
end

Quand("l'administrateur ouvre la page des points d'accès") do
  next @navigateur.visit(POINTS_D_ACCES) if @navigateur

  visit POINTS_D_ACCES
  # A mark on the window, which a reload would wipe: what lets a later step say
  # the page did not reload.
  page.execute_script('window.pageNonRechargee = true')
end

Quand("il teste le point d'accès {string}") do |partie|
  next @navigateur.submit_to('/admin/common_services/connectivity_tests', party: partie) if @navigateur

  bloc_du_point_d_acces(partie).click_button(I18n.t('admin.common_services.access_points.index.test'))
end

Alors("le point d'accès {string} affiche {string}, sans bouton de test") do |partie, issue|
  bloc = bloc_du_point_d_acces(partie)

  # The DSFR badge upper-cases what it says, on screen and nowhere else.
  expect(bloc).to have_css('.fr-badge', text: /\A#{Regexp.escape(issue)}\z/i)
  expect(bloc).to have_no_button(I18n.t('admin.common_services.access_points.index.test'))
  expect(bloc['aria-busy']).to eq('true')
end

# The verdict as `ConnectivityTesting::ReadVerdict` records it: what follows is
# the page noticing, which is the subject here.
Quand("la France lit dans la passerelle que le point d'accès {string} a acquitté le test") do |partie|
  ConnectivityTest.find_by!(party_name: partie).acknowledged!
end

Alors("le point d'accès {string} affiche {string}, sans que la page se soit rechargée") do |partie, issue|
  expect(bloc_du_point_d_acces(partie)).to have_css('.fr-badge', text: /\A#{Regexp.escape(issue)}\z/i)
  expect(page.evaluate_script('window.pageNonRechargee')).to be(true)
end

# The gateway notifies nothing about a test message: its verdict is read by
# jobs, so the page is opened again until it says it.
Alors("la page des points d'accès affiche {string} pour {string}") do |issue, partie|
  patiente_jusqu_a("la ligne de #{partie} affiche « #{issue} »") do
    @navigateur.visit(POINTS_D_ACCES)

    bloc_du_point_d_acces(partie)&.at_css('.fr-badge')&.text.to_s.strip == issue
  end
end
