require 'rails_helper'

RSpec.describe 'Admin::Demo::Procedures' do
  describe 'GET /admin/demo/v2.0' do
    before do
      sign_in
      stub_code_list
      stub_directory_resolution
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
    end

    # CA1 of OOTS-253: the console's screen, in French, every code a request may
    # name in the order of the `Procedures` list, then `00` under the wording of
    # a procedure no list names.
    it 'offers every code of the list in its order, then the system check, untitled' do
      get admin_demo_procedures_path(version: 'v2.0')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css('main h1').text.squish).to eq('Choose the procedure')
      cards = response.parsed_body.css('#liste-demarches .fr-card')
      expect(cards.size).to eq(30)
      expect(cards.map { |card| card.at_css('a')['href'] }.sort)
        .to eq(ProcedureCode::ADMITTED.map { |code| "/admin/demo/v2.0/#{code}" }.sort)
      expect(session[:france_connect]).to be_nil
    end

    it 'offers to search the cards' do
      get admin_demo_procedures_path(version: 'v2.0')

      expect(response.parsed_body.at_css("main label[for='recherche-demarche']").text.squish)
        .to eq('Search a code or a title')
    end

    # RG1 as amended on the screen: the procedures France declares say so in
    # their footer, as on the directory pages, and the others carry none.
    it 'marks the procedures France declares, and those alone' do
      get admin_demo_procedures_path(version: 'v2.0')

      expect(card('T1').at_css('.fr-card__footer').text.squish)
        .to match(/\A.*France \(FR\) requires \d+ documents?\z/)
      expect(card('U4').at_css('.fr-card__footer')).to be_nil
    end

    # The system check first; then those France declares; then the others —
    # each group sorted by code, naturally.
    it 'lists the system check, then the procedures France declares, then the others, each by code' do
      get admin_demo_procedures_path(version: 'v2.0')

      codes = codes_listed
      expect(codes.first).to eq('00')
      declared = codes.drop(1).take_while { |code| card(code).at_css('.fr-card__footer') }
      expect(declared).not_to be_empty
      expect(declared).to eq(natural(declared))
      expect(codes.drop(1 + declared.size)).to eq(natural(ProcedureCode::PUBLISHED - declared))
      expect(natural(%w[X10 X9])).to eq(%w[X9 X10])
      expect(card('R1').at_css('.fr-card__title').text.squish).to eq('R1 — Requesting a birth registration certificate')
      expect(card('00').at_css('.fr-card__title').text.squish).to eq('00 — No label')
    end

    it 'stands without the footers, and with no alert, when the Evidence Broker cannot be reached' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including({})).to_timeout

      get admin_demo_procedures_path(version: 'v2.0')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('#liste-demarches .fr-card').size).to eq(30)
      expect(response.parsed_body.css('main .fr-card__footer, main .fr-alert')).to be_empty
      expect(codes_listed).to eq(['00', *natural(ProcedureCode::PUBLISHED)])
    end

    def codes_listed
      response.parsed_body.css('#liste-demarches .fr-card__title').map { |title| title.text.squish.split(' — ').first }
    end

    def natural(codes) = codes.sort_by { |code| [code[/\A\D*/], code[/\d+\z/].to_i] }

    def card(code)
      response.parsed_body.css('#liste-demarches .fr-card')
        .find { |found| found.at_css('.fr-card__title').text.squish.split(' — ').first == code }
    end

    it 'stands under the trail of the console, its line last' do
      get admin_demo_procedures_path(version: 'v2.0')

      expect(response.parsed_body.css('.fr-breadcrumb__link').map { |crumb| crumb.text.squish })
        .to eq(['Espace d’administration', 'Demo', '2.0'])
    end
  end
end
