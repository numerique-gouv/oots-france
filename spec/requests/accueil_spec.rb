require 'rails_helper'

RSpec.describe 'Accueil' do
  def page = response.parsed_body

  def section(id) = page.at_css("section[aria-labelledby='#{id}']")

  # Annex II to Regulation (EU) 2018/1724, consolidated on 20 May 2026, column by
  # column, and the row Directive (EU) 2025/2205 adds to « Déménagement ».
  def annex_ii
    [
      ['Naissance', ["Demander une attestation d'enregistrement d'une naissance"]],
      ['Résidence', ['Demander une preuve de résidence']],
      ['Études', [
        "Demander à un organisme public ou une institution publique le financement d'études supérieures, " \
        'par exemple par des bourses et des prêts',
        "Présentation d'une première demande d'admission dans un établissement d'enseignement supérieur",
        'Demander la reconnaissance académique de diplômes, certificats ou autres preuves que des études ou ' \
        'des cours ont été suivis',
      ]],
      ['Vie professionnelle', [
        'Demander à établir quelle est la législation applicable conformément au titre II du règlement (CE) ' \
        'no 883/2004 du Parlement européen et du Conseil',
        "Notifier des changements de la situation personnelle ou professionnelle d'une personne recevant des " \
        'prestations de sécurité sociale pertinents aux fins de ces prestations',
        "Demander une carte européenne d'assurance maladie (CEAM)",
        "Soumettre une déclaration d'impôt sur le revenu",
      ]],
      ['Déménagement', [
        "Faire enregistrer un changement d'adresse",
        "Immatriculation d'un véhicule provenant d'un État membre ou déjà immatriculé dans un État membre de " \
        "l'Union européenne, par la procédure normale",
        "Obtenir une vignette pour l'utilisation des infrastructures routières nationales: redevances fondées " \
        'sur la durée (vignette), redevances fondées sur la distance (péages) délivrées par un organisme public ' \
        'ou une institution publique',
        "Obtenir des vignettes indiquant le niveau d'émissions délivrées par un organisme public ou une " \
        'institution publique',
        'Obtention ou renouvellement du permis de conduire (ajoutée par la directive (UE) 2025/2205, ' \
        'applicable au 26 novembre 2029)',
      ]],
      ['Retraite', [
        'Demander une pension ou des prestations de préretraite à un régime obligatoire',
        'Demander des informations sur les données relatives aux pensions des régimes obligatoires',
      ]],
      ["Démarrage et gestion d'une entreprise, et cessation d'activité", [
        "Notification de l'activité économique, autorisation d'exercer une activité économique, modifications " \
        "de l'activité économique et cessation de l'activité économique sans procédure d'insolvabilité ou de " \
        "liquidation, à l'exclusion de l'enregistrement initial d'une activité économique au registre du " \
        'commerce et hors procédures relatives à la constitution de sociétés ou à tout dépôt de pièces ' \
        "ultérieur par des sociétés au sens de l'article 54, deuxième alinéa, du traité sur le fonctionnement " \
        "de l'Union européenne",
        "Déclarations effectuées par les hôtes pour les procédures d'enregistrement en ce qui concerne les " \
        'services de location de logements de courte durée',
        "Enregistrement d'un employeur (personne physique) auprès d'un régime obligatoire de pension et " \
        "d'assurance",
        "Enregistrement de salariés auprès de régimes obligatoires de pension et d'assurance",
        "Soumettre une déclaration d'impôt sur les sociétés",
        "Notification de la fin du contrat de travail d'un salarié au régime de sécurité sociale, à " \
        "l'exclusion des procédures de licenciement collectif",
        'Paiement des cotisations sociales pour les salariés',
        "Notification d'un prestataire de services d'intermédiation de données",
        "Enregistrement en tant qu'organisation altruiste en matière de données reconnue dans l'Union",
      ]],
      ['Projets dans le secteur des matières premières critiques', [
        "Procédure concernant l'ensemble des autorisations pour construire et exploiter des projets dans le " \
        'secteur des matières premières critiques, dont les permis de construction, les autorisations ' \
        "d'utilisation de produits chimiques et les autorisations de raccordement au réseau, ainsi que les " \
        "évaluations et autorisations environnementales lorsqu'elles sont requises, et englobant toutes les " \
        "demandes et procédures, depuis la reconnaissance du fait que la demande est complète jusqu'à la " \
        'notification, par le point unique de contact concerné, de la décision globale sur ' \
        "l'issue de la procédure; conformément à l'article 9 du règlement (UE) 2024/1252.",
      ]],
      ['Projets de production de technologies «zéro net»', [
        'Procédures pour tous les permis pertinents pour construire, étendre, convertir et exploiter des ' \
        'projets de production de technologies «zéro net», et des projets stratégiques «zéro net», y compris ' \
        "les permis de construction, les autorisations d'utilisation de produits chimiques et les permis de " \
        'raccordement au réseau, les évaluations et autorisations environnementales lorsqu\'elles sont ' \
        'requises, et englobant toutes les demandes et procédures.',
      ]],
    ].freeze
  end

  describe 'GET /' do
    before { get '/' }

    it 'renders an HTML page in French, carrying the DSFR, without a session' do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(page.at_css('html')['lang']).to eq('fr')
      expect(page.css('.fr-header')).to be_present
      expect(page.at_css('main#contenu')).to be_present
    end

    it 'addresses the service provider that runs an online procedure and is not yet connected' do
      expect(page.at_css('.accueil-hero .fr-text--lead').text.squish).to include(
        "l'administration ou à l'opérateur qui expose une démarche en ligne française et n'est pas encore raccordé"
      )
      expect(section('connection').text).to include('Le raccordement demande au fournisseur de service')
    end

    it 'names the Single Digital Gateway, the regulation that establishes it and its article 14' do
      text = section('what-is-oots').text.squish

      expect(text).to include('portail numérique unique (PNU)', 'règlement (UE) 2018/1724', 'Son article 14 institue')
      expect(section('what-is-oots').at_css('a[href="https://design.numerique.gouv.fr/pnu/"]').text)
        .to eq('portail numérique unique (PNU)')
    end

    it 'says since when the exchange applies, where the evidence comes from, and what the user decides' do
      text = section('what-is-oots').text.squish

      expect(text).to include(
        "s'appliquent depuis le 12 décembre 2023",
        "vient directement de l'administration qui le délivre", 'réputé authentique',
        "L'usager demande l'échange, prévisualise le justificatif et décide"
      )
      expect(section('what-is-oots').at_css('a[href="https://eur-lex.europa.eu/eli/reg_impl/2022/1463/oj"]'))
        .to be_present
      expect(section('what-is-oots').at_css('a[href$="/OOTS/OOTSHUB+Home"]').text).to eq('hub OOTS')
    end

    it 'says what the Single Digital Gateway asks of a procedure concerned' do
      expect(section('procedures').text.squish).to include(
        'accomplie entièrement en ligne par un usager d\'un autre État membre',
        'lui viennent par le système technique, à la demande de l\'usager'
      )
    end

    it 'lists the procedures of Annex II under their life events, in the order of the Annex' do
      events = section('procedures').css('.fr-accordion').map do |accordion|
        [accordion.at_css('.fr-accordion__btn').text.squish, accordion.css('li').map { it.text.squish }]
      end

      expect(events).to eq(annex_ii)
      expect(section('procedures').at_css('a[href="https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:02018R1724-20260520"]'))
        .to be_present
      expect(section('procedures').at_css('a[href="https://eur-lex.europa.eu/eli/dir/2025/2205/oj"]')).to be_present
    end

    it 'names the four directives article 14 also serves, without listing their procedures' do
      directives = section('procedures').css('.fr-accordions-group ~ p a')

      expect(directives.pluck('href')).to eq(
        %w[2005/36 2006/123 2014/24 2014/25].map { "https://eur-lex.europa.eu/eli/dir/#{it}/oj" }
      )
      expect(directives.map(&:text)).to all(match(%r{\Adirective 20\d\d/\d+/(CE|UE) }))
    end

    it 'writes neither a count of procedures, nor a counter of the hub, nor a first or second person' do
      text = page.at_css('main').text.squish

      expect(text).not_to match(/\b21\b|%|\d+ (démarches|procédures|justificatifs|autorités)/)
      expect(text).not_to match(/\b(vous|nous)\b/i)
    end

    it 'says what OOTS is, and links to the regulation that provides for it' do
      expect(section('what-is-oots').text).to include('Ce qu\'est OOTS', 'échange automatisé et transfrontalier')
      expect(section('what-is-oots').at_css('a[href*="CELEX:32018R1724"]').text).to eq('règlement (UE) 2018/1724')
      expect(section('what-is-oots').at_css('a[href*="/TDD/"]').text).to eq('documents de conception technique')
    end

    it 'says the two roles France holds, and that it answers with test evidence alone' do
      expect(section('roles').css('h3 + p').map { it.text.squish }).to contain_exactly(
        a_string_including('Il demande les justificatifs aux autres États membres'),
        a_string_including('justificatifs de test seulement, aucun fournisseur de données français'),
      )
    end

    it 'says what joining asks, and links to the contract without writing any of its addresses' do
      expect(section('connection').text.squish).to include(
        "sans qu'ils aient à le fournir eux-mêmes", "déclaré auprès d'OOTS-France", 'clés de signature',
        "l'identité de l'usager, signée et chiffrée", 'adresse à lui'
      )
      expect(section('connection').at_css('a[href="https://github.com/numerique-gouv/oots-france"]').text)
        .to eq("dépôt d'OOTS-France")
      expect(section('connection').at_css('a[href$="#c%C3%B4t%C3%A9-evidence-requester-la-france-demande-un-justificatif"]'))
        .to be_present
      expect(response.body).not_to include('/requete/', '/auth/cles_publiques')
    end

    it 'says the service is not accredited, and open to requests on a test server alone' do
      expect(section('status').text.squish).to include(
        "n'est pas homologué", 'serveur de test', 'jamais sur des données réelles'
      )
    end

    it 'sends the user of a procedure to its portal, and offers them nothing to do' do
      expect(page.at_css('#users').text).to eq("L'usager d'une démarche")
      expect(section('users').text).to include('passe par le portail de sa démarche')
      expect(page.css('form, input, button[type="submit"]')).to be_empty
    end

    it 'reads nothing over the network to render' do
      expect(a_request(:any, /./)).not_to have_been_made
    end

    it 'keeps its sections, the procedures between what OOTS is and its roles' do
      expect(page.css('main section[aria-labelledby]').pluck('aria-labelledby'))
        .to eq(%w[what-is-oots procedures roles connection status users])
    end

    it 'warns that its links open a new window' do
      links = page.css('main a[target="_blank"]')

      expect(links.size).to eq(page.css('main a').size)
      links.each { expect(it['title']).to end_with(' - nouvelle fenêtre') }
    end

    it 'leads to the administration space from its header alone' do
      tool_links = page.css('.fr-header__tools-links .fr-btns-group a')
      expect(tool_links.map { [it['href'], it.text.squish] }).to eq([[admin_root_path, 'Administration']])
      expect(page.css('main a[href^="/admin"]')).to be_empty
    end

    it 'offers the header menu, where the DSFR copies the link on a small screen' do
      expect(page.css('#button-header-menu')).to be_present
      expect(page.css('.fr-header__menu-links')).to be_present
    end

    it 'marks each section with a decorative pictogram of the DSFR' do
      pictograms = page.css('main img.pictogram')
      expect(pictograms).to be_present
      expect(pictograms.map { [it['alt'], it['aria-hidden']] }.uniq).to eq([['', 'true']])
    end

    it 'carries none of the entries of the space in its header' do
      expect(page.css('nav.fr-nav')).to be_empty
      expect(page.at_css('header').text).not_to include('Annuaires', 'Journal', 'Jobs', 'Démo', 'Se déconnecter')
    end
  end

  describe 'GET / in English' do
    before do
      get root_path(locale: 'en')
      follow_redirect!
    end

    it 'says the same things as the French page, in English' do
      expect(page.at_css('.accueil-hero .fr-text--lead').text.squish)
        .to include('the administration or the operator that runs a French online procedure and is not yet connected')
      expect(section('what-is-oots').text.squish).to include(
        'Regulation (EU) 2018/1724 establishes the European Single Digital Gateway (SDG)', 'Its Article 14',
        'have applied since 12 December 2023', 'deemed authentic',
        'The user requests the exchange, previews the evidence and decides'
      )
      expect(section('procedures').text.squish).to include(
        'completed fully online by a user from another Member State', "at the user's request",
        'applicable from 26 November 2029'
      )
    end

    it 'lists the procedures in the words of the English text of Annex II' do
      events = section('procedures').css('.fr-accordion').map do |accordion|
        [accordion.at_css('.fr-accordion__btn').text.squish, accordion.css('li').map { it.text.squish }]
      end

      expect(events.map(&:first)).to eq(
        ['Birth', 'Residence', 'Studying', 'Working', 'Moving', 'Retiring', 'Starting, running and closing a business',
         'Critical raw materials projects', 'Net-zero technology manufacturing projects']
      )
      expect(events.map { it.last.size }).to eq(annex_ii.map { it.last.size })
      expect(events.flat_map(&:last)).to include(
        'Requesting proof of registration of birth',
        'Declarations by hosts for registration procedures in relation to short-term accommodation rental services',
        a_string_starting_with('Acquiring and renewing a driving licence (added by Directive (EU) 2025/2205')
      )
      expect(section('procedures').at_css('a[href*="/EN/TXT/HTML/?uri=CELEX:02018R1724-20260520"]')).to be_present
    end

    it 'names the four directives in English, each linked to its text' do
      expect(section('procedures').css('.fr-accordions-group ~ p a').map(&:text))
        .to all(match(%r{\ADirective 20\d\d/\d+/(EC|EU) }))
      expect(section('procedures').css('.fr-accordions-group ~ p a').size).to eq(4)
    end

    it 'warns that its links open a new window, and writes neither a count nor a first or second person' do
      links = page.css('main a[target="_blank"]')
      text = page.at_css('main').text.squish

      expect(links.size).to eq(page.css('main a').size)
      links.each { expect(it['title']).to end_with(' - new window') }
      expect(text).not_to match(/\b(you|we|21)\b|%|\d+ (procedures|pieces of evidence|authorities)/i)
    end
  end

  describe 'GET /up' do
    it 'answers without rendering a page' do
      get '/up'

      expect(response).to have_http_status(:ok)
    end
  end
end
