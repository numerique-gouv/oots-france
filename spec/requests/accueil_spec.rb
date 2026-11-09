require 'rails_helper'

RSpec.describe 'Accueil' do
  def page = response.parsed_body

  def section(id) = page.at_css("section##{id}")

  def text_of(selector) = page.at_css(selector).text.squish

  def accordions(container)
    container.css('.fr-accordion').map do |accordion|
      [accordion.at_css('.fr-accordion__btn').text.squish, accordion.css('li').map { it.text.squish }]
    end
  end

  # Every link of the page and its footer that leaves the site: the main
  # content's and the footer's, the header's being the language selector's own.
  def external_links = page.css('main a[href^="http"], footer a[href^="http"]')

  describe 'GET /' do
    before { get '/' }

    it 'captions its opening illustration with the agreement of the user' do
      expect(page.at_css('.accueil-hero figure > figcaption').text.squish)
        .to eq("Le justificatif circule entre administrations, avec l'accord de l'usager.")
    end

    it 'renders an HTML page in French, carrying the DSFR, without a session' do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(page.at_css('html')['lang']).to eq('fr')
      expect(page.at_css('main#contenu')).to be_present
    end

    # CA1
    it 'lays out the sections of the mock-up in its order, under their anchors and titles' do
      sections = page.css('main section[id]').map { [it['id'], it.at_css('h2, h3').text.squish] }

      expect(sections).to eq([
        ['comprendre', 'OOTS en bref'],
        ['fonctionnement', 'Comment ça marche ?'],
        ['interet', 'Ce que votre administration y gagne'],
        ['concerne', 'Votre administration est-elle concernée ?'],
        ['demarches', 'Les démarches concernées'],
        ['raccorder', 'Se raccorder à OOTS-France'],
        ['etat', 'Où en est OOTS-France ?'],
        ['faq', 'Questions fréquentes'],
        ['contact', 'Votre administration est concernée, ou vous avez un doute ?'],
      ])
      expect(page.css('#what-is-oots, #procedures, #roles, #connection, #status, #users')).to be_empty
    end

    # CA2
    it 'leads from its header to its sections, its contact and the administration space' do
      expect(page.css('nav.fr-nav a').map { [it['href'], it.text.squish] }).to eq([
        ['#comprendre', 'OOTS en bref'], ['#fonctionnement', 'Comment ça marche'],
        ['#concerne', 'Êtes-vous concerné ?'], ['#raccorder', 'Se raccorder'], ['#faq', 'Questions fréquentes'],
      ])
      expect(page.css('.fr-header__tools-links .fr-btns-group a').map { [it['href'], it.text.squish] })
        .to eq([["mailto:#{Settings.team_mail_address}", 'Contact'], [admin_root_path, 'Administration']])
      expect(page.at_css('.fr-header__tools-links .fr-translate')).to be_present
      expect(page.css('#button-header-menu, .fr-header__menu-links').size).to eq(2)
      expect(page.at_css('header').text).not_to include('Justificatifs disponibles', 'Annuaires', 'Se déconnecter')
    end

    # CA4
    it 'names the service with its hyphen, and the service provider in the singular' do
      text = page.css('header, main, footer').map(&:text).join(' ').squish

      expect(text).not_to include('OOTS France')
      expect(text).not_to match(/fournisseurs? de services/i)
    end

    # CA5
    it 'attributes to each Common Service what it holds, and presents three of them' do
      cards = section('fonctionnement').css('.accueil-box--card').map do |card|
        [card.at_css('.accueil-title').text.squish, card.at_css('[lang="en"]').text]
      end

      expect(cards).to eq([
        ["Ce qu'il faut prouver, et quels justificatifs le prouvent", 'Evidence Broker'],
        ['Qui les délivre', 'Data Service Directory'],
        ['Le vocabulaire commun', 'Semantic Repository'],
      ])
      expect(section('fonctionnement').css('.accueil-box--card').last.text)
        .to include('listes de codes', 'à la conception', 'non pendant un échange')
      expect(section('fonctionnement').text).not_to include('Ils sont trois')
      expect(section('fonctionnement').text).to include("L'annuaire européen : les annuaires centraux")
      expect(section('fonctionnement').text).not_to include('Common Services')
    end

    # CA6
    it 'says what OOTS-France reads in the directories for each request, not that every country does' do
      text = section('fonctionnement').text.squish

      expect(text).to include(
        "Pour chaque demande d'une démarche française, OOTS-France lit dans ces annuaires quel type de " \
        "justificatif prouve l'exigence, et qui le délivre."
      )
      expect(text).not_to include('avant chaque demande')
    end

    # CA7
    it 'says the preview is a right, exercised at the provider of each piece of evidence' do
      preview = section('fonctionnement').css('ol > li')[3].text.squish
      form = section('raccorder').css('ol')[0].css('li')[2].text.squish

      expect(preview).to include('peut', 'Pour chaque justificatif', 'chez le fournisseur qui le délivre')
      expect(form).to include('doit pouvoir prévisualiser chaque justificatif', 'chez le fournisseur qui le délivre')
      expect(page.at_css('main').text).not_to include('du pays qui le délivre')
      expect(section('fonctionnement').css('ol > li')[0].text).to include('via FranceConnect+', '(eIDAS)')
    end

    # CA8
    it 'keeps the facts of the regulation, and writes no count' do
      text = page.at_css('main').text.squish

      expect(text).to include(
        "s'applique depuis le 12 décembre 2023", "vient directement de l'administration qui le délivre",
        'réputé authentique', "qu'à la demande explicite de l'usager", 'Il peut toujours le fournir lui-même'
      )
      expect(text).not_to match(/%|\d+ (démarches|procédures|justificatifs|autorités)/)
    end

    # CA9
    it 'lists the procedures under the life events of Annex II, then the directives' do
      events = accordions(section('demarches'))

      expect(events.map(&:first)).to eq([
        'Naissance', 'Résidence', 'Études', 'Vie professionnelle', 'Déménagement', 'Retraite',
        "Démarrage, gestion et cessation d'une entreprise", 'Matières premières critiques',
        'Technologies « zéro net »', 'Qualifications, services et marchés publics',
      ])
      expect(events.map { it.last.size }).to eq([1, 1, 3, 4, 4, 2, 6, 1, 1, 3])
      expect(events.flat_map(&:last))
        .to include('Obtenir ou renouveler son permis de conduire (à partir du 26 novembre 2029)')
      expect(section('demarches').css('#procedures-directives a').pluck('href')).to eq(
        %w[2005/36 2006/123 2014/24 2014/25].map { "https://eur-lex.europa.eu/eli/dir/#{it}/oj" }
      )
      expect(section('demarches').at_css('a[href="https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:02018R1724-20260520"]').text)
        .to eq('annexe II du règlement (UE) 2018/1724')
    end

    # CA10
    it 'leads to no page of available evidence' do
      expect(page.css('a').pluck('href')).not_to include(a_string_matching(/justificatifs/i))
      expect(page.at_css('main').text).not_to include('Vérifiez s', 'Vérifier qu’un justificatif', "Vérifier qu'un justificatif")
      expect(section('raccorder').css('ol')[0].css('li')[0].css('a')).to be_empty
    end

    # CA11
    it 'describes the call as the repository serves it, and points to the repository without writing it' do
      steps = section('raccorder').css('ol')[0].css('li').map { it.text.squish }

      expect(steps[3]).to include(
        'le code de la démarche, le pays', 'signée avec les clés de votre démarche',
        "chiffrée pour la clé publique d'OOTS-France", "l'adresse que votre démarche lui a déclarée"
      )
      expect(steps[3]).not_to include('chiffrée et signée avec vos clés', 'retour')
      expect(steps[1]).to include('FranceConnect+', 'eIDAS')
      documentation = page.css('main a').select { it.text.squish == 'Documentation technique' }
      expect(documentation.pluck('href')).to eq(['https://github.com/numerique-gouv/oots-france'] * 2)
      expect(response.body).not_to include('/requete/', '/auth/cles_publiques')
    end

    # CA12
    it 'says where the service stands, and who operates it' do
      text = section('etat').text.squish

      expect(text).to include(
        'en préproduction', 'que sur des données de test', 'après son homologation de sécurité',
        "Aucun fournisseur de données français n'y est raccordé aujourd'hui"
      )
      expect(section('etat').css('.accueil-milestone').map { it.css('p, h3').first(3).map { it.text.squish } })
        .to eq([
          ['Fait', 'Décembre 2023', "OOTS s'applique dans toute l'Union"],
          ['En cours', '2026', 'OOTS-France en préproduction'],
          ['À venir', '2027', 'Ouverture aux données réelles'],
        ])
      operated = [page.at_css('.accueil-diagram'), section('faq'), section('contact'), page.at_css('footer')]
      expect(operated.map(&:text)).to all(include('DINUM'))
    end

    it 'leads each of its in-page links to a section it carries' do
      targets = page.css('a[href^="#"]').pluck('href').uniq.map { it.delete_prefix('#') }

      expect(targets).to include('concerne', 'fonctionnement', 'demarches')
      expect(targets.reject { page.at_css("[id='#{it}']") }).to be_empty
    end

    # CA14
    it 'warns that each link leaving the site opens a new window' do
      expect(external_links.size).to be >= 19
      expect(external_links.map { [it['target'], it['title']] })
        .to all(match(['_blank', end_with(' - nouvelle fenêtre')]))
    end

    # CA15
    it 'closes on the footer of the mock-up' do
      footer = page.at_css('footer')

      expect(footer.text.squish).to include(
        'Service opéré par la direction interministérielle du numérique (DINUM)', 'Accessibilité : non conforme',
        'proposés sous licence etalab-2.0'
      )
      expect(footer.css('.fr-footer__content-link').map { [it.text, it['href']] }).to eq([
        ['numerique.gouv.fr', 'https://www.numerique.gouv.fr'], ['info.gouv.fr', 'https://info.gouv.fr'],
        ['service-public.gouv.fr', 'https://service-public.gouv.fr'],
        ['legifrance.gouv.fr', 'https://legifrance.gouv.fr'], ['data.gouv.fr', 'https://data.gouv.fr'],
      ])
      expect(footer.css('a').map { [it.text.squish, it['href']] }).to include(
        ['Code source', 'https://github.com/numerique-gouv/oots-france'],
        ['licence etalab-2.0', 'https://github.com/etalab/licence-ouverte/blob/master/LO.md']
      )
      expect(footer.css('a').map(&:text).join).not_to match(/Accessibilité|Mentions légales|Données personnelles|cookies/)
    end

    # CA16
    it 'offers no form, and reads nothing over the network to render' do
      expect(page.css('form, input, button[type="submit"]')).to be_empty
      expect(a_request(:any, /./)).not_to have_been_made
    end

    # CA18
    it 'shows the pre-production badge beside the name of the service' do
      expect(text_of('.fr-header__service-title')).to eq('OOTS-France Préproduction')
      expect(page.at_css('.fr-header__service-title .fr-badge').text).to eq('Préproduction')
      expect(text_of('.fr-header__service-tagline')).to eq('Échange de justificatifs entre administrations européennes')
    end

    # CA19
    it 'offers to write to the team, and names the national coordinator' do
      expect(page.css(%(main a[href="mailto:#{Settings.team_mail_address}"])).map { it.text.squish })
        .to eq(["Écrire à l'équipe", "Écrire à l'équipe OOTS-France"])
      expect(section('faq').text).to include('Le coordinateur national du portail numérique unique, à la DINUM')
    end
  end

  # CA13
  describe 'the retention of the exchange log' do
    def answer = section('faq').at_css('#faq-data').text.squish

    it 'states the duration the deployment applies' do
      allow(Settings).to receive(:audit_trail_retention).and_return(18.months)
      get '/'

      expect(answer).to end_with('conservé 18 mois.')
    end

    it 'states twelve months on the installation of the repository' do
      allow(Settings).to receive(:audit_trail_retention).and_return(12.months)
      get '/'

      expect(answer).to end_with('conservé 12 mois.')
    end
  end

  # CA2, CA15, CA18: what the other pages share of the header and the footer.
  describe 'the sign-in page' do
    before { get new_admin_session_path }

    it 'carries neither the anchors nor the contact of the presentation page' do
      expect(page.css('nav.fr-nav a').pluck('href')).not_to include('#comprendre', '#faq')
      expect(page.at_css('header').text).not_to include('Contact')
    end

    it 'carries the badge, the tagline and the footer of the site' do
      expect(text_of('.fr-header__service-title')).to eq('OOTS-France Préproduction')
      expect(text_of('.fr-header__service-tagline')).to eq('Échange de justificatifs entre administrations européennes')
      expect(page.at_css('footer').text.squish).to include('Accessibilité : non conforme', 'Code source')
      expect(page.css('footer .fr-footer__content-link').size).to eq(5)
    end
  end

  describe 'GET / in English' do
    before do
      get root_path(locale: 'en')
      follow_redirect!
    end

    # CA3
    it 'says the same things in English, navigation included' do
      expect(page.at_css('html')['lang']).to eq('en')
      expect(page.css('nav.fr-nav a').map { it.text.squish })
        .to eq(['OOTS in brief', 'How it works', 'Are you concerned?', 'Connecting', 'FAQ'])
      expect(text_of('.fr-header__service-title')).to eq('OOTS-France Pre-production')
      expect(section('fonctionnement').text.squish).to include(
        'at the provider that issues it', 'For each request of a French procedure, OOTS-France reads'
      )
      expect(accordions(section('demarches')).map(&:first).last).to eq('Qualifications, services and public procurement')
      expect(section('demarches').at_css('a[href*="/EN/TXT/HTML/?uri=CELEX:02018R1724-20260520"]')).to be_present
    end

    it 'warns in English that each link leaving the site opens a new window' do
      expect(external_links.size).to be >= 19
      expect(external_links.pluck('title')).to all(end_with(' - new window'))
      expect(page.at_css('footer').text).to include('Accessibility: not compliant')
    end
  end

  describe 'GET /up' do
    it 'answers without rendering a page' do
      get '/up'

      expect(response).to have_http_status(:ok)
    end
  end
end
