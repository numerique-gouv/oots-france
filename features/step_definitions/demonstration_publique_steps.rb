# The public entrance of the demonstration procedure, walked by a visitor who
# holds no session of the console. The walk itself is the console's, and its
# steps in `demarche_steps.rb` serve both actors.
Étantdonné('un visiteur sans session de l\'espace d\'administration') do
  @navigateur = DemoBrowser.new(procedure_url)
  @racine = '/demonstration'
end

Quand('le visiteur ouvre la démarche de démonstration depuis la page d\'accueil du site') do
  @navigateur.visit('/')
  lien = Nokogiri::HTML(@navigateur.body).css('header .fr-nav__link').find { |candidat| candidat.text.strip == 'Démo' } ||
         raise("Aucun lien « Démo » dans l'en-tête : #{@navigateur.body}")

  @navigateur.visit(lien['href'])
end

Alors('le visiteur arrive sur l\'écran du choix de la version, sous le bandeau de démonstration') do
  page = Nokogiri::HTML(@navigateur.body)

  expect(URI.parse(@navigateur.current_url).path).to eq(racine_de_la_demarche)
  expect(page.at_css('.fr-notice--info .fr-notice__title')&.text&.strip).to eq('Démonstration — données fictives')
  expect(page.css('.fr-card__title a').map { |carte| carte.text.strip }).to include('OOTS 2.0', 'OOTS 1.2')
end

# Under the SIRET of the public entrance, which `DONNEES_REQUETEURS` maps to a
# name of its own, distinct from the console's.
Alors('le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration publique') do
  depart = depart_de_la_requete

  expect(depart.evidence_requester_id).to eq(ENV.fetch('IDENTIFIANT_REQUETEUR_DEMONSTRATION_PUBLIQUE'))
  expect(depart.evidence_requester_id).not_to eq(ENV.fetch('IDENTIFIANT_REQUETEUR_DEMARCHE'))
  expect(depart.procedure_code).to eq(@demarche)
end

Alors('cette requête nomme le requêteur {string}') do |nom|
  expect(Nokogiri::XML(depart_de_la_requete.regrep_body).text).to include(nom)
end
