require 'rails_helper'

RSpec.describe 'Accueil' do
  describe 'GET /' do
    def page = response.parsed_body

    def section(id) = page.at_css("section[aria-labelledby='#{id}']")

    before { get '/' }

    it 'renders an HTML page in French, carrying the DSFR, without a session' do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(page.at_css('html')['lang']).to eq('fr')
      expect(page.css('.fr-header')).to be_present
      expect(page.at_css('main#contenu')).to be_present
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
      expect(section('users').text).to include('passe par le portail de sa démarche')
      expect(page.css('form, input, button[type="submit"]')).to be_empty
    end

    it 'warns that its links open a new window' do
      page.css('main a[target="_blank"]').each { expect(it['title']).to end_with(' - nouvelle fenêtre') }
    end

    it 'leads to the administration space from its header alone' do
      tool_links = page.css('.fr-header__tools-links a')
      expect(tool_links.map { [it['href'], it.text.squish] }).to eq([[admin_root_path, 'Espace d’administration']])
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
      expect(page.css('.fr-nav')).to be_empty
      expect(page.at_css('header').text).not_to include('Annuaires', 'Journal', 'Jobs', 'Démo', 'Se déconnecter')
    end
  end

  describe 'GET /up' do
    it 'answers without rendering a page' do
      get '/up'

      expect(response).to have_http_status(:ok)
    end
  end
end
