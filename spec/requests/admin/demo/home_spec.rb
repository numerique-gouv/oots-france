require 'rails_helper'

RSpec.describe 'Admin::Demo::Home' do
  let(:label) { CodeListStubs::STUDY_FINANCING_LABEL }

  describe 'GET /admin/demo' do
    before do
      sign_in
      stub_code_list(procedures: { ProcedureCode::STUDY_FINANCING => label })
    end

    it 'stands in the portal it plays, under the procedure it is about' do
      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main').text).to include('Université de démonstration')
      expect(response.parsed_body.css('h1').text).to eq("T1 — #{label}")
    end

    it 'explains what the OOTS lets the procedure do' do
      get admin_demo_root_path

      expect(response.parsed_body.css('main').text)
        .to include('directement de', 'autre État membre', 'accord explicite')
    end

    it 'says it is a demonstration, and that the university is not real' do
      get admin_demo_root_path

      expect(response.parsed_body.css('.fr-callout').text)
        .to include("L'Université de démonstration n'existe pas")
    end

    # A single way in, and the label is the one the European flow of
    # FranceConnect+ carries — in English, and word for word.
    it 'offers one way to sign in, and only one' do
      get admin_demo_root_path

      buttons = response.parsed_body.css('main a.fr-btn')

      expect(buttons.map { |button| button.text.strip })
        .to eq(['Sign-in with a digital identity from another European country'])
      expect(buttons.first['href']).to eq(admin_demo_identification_path)
    end

    # The demonstration plays a Danish student and nothing else: the French
    # identity of FranceConnect+ has neither button, sentence nor link here.
    it 'carries no FranceConnect+ button of its own' do
      get admin_demo_root_path

      expect(response.body).not_to include('FranceConnect')
    end

    # A name is an ornament here as everywhere else in the console: the code
    # list lives on a host of its own, and the page says what it says without it.
    it 'stands without the code list' do
      stub_request(:get, CodeListClient::PROCEDURES).to_timeout

      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('h1').text).to eq('T1 — Aucun label')
    end
  end

  describe 'GET /admin/demo without a session' do
    it 'sends the visitor to the login page' do
      get admin_demo_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end
end
