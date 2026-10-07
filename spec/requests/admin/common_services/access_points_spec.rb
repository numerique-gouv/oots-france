require 'rails_helper'

RSpec.describe 'Admin::CommonServices::AccessPoints' do
  let(:listing) { 'http://domibus:8080/domibus/ext/party' }
  let(:page) { response.parsed_body }

  def row(name) = page.css('.access-point').find { |block| block.at_css('.access-point__name')&.text == name }

  def gateway_listing(parties = gateway_parties)
    stub_request(:get, listing).with(query: hash_including({}))
      .to_return(body: parties.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  before do
    allow(Settings).to receive_messages(
      domibus_base_url: 'http://domibus:8080/domibus',
      domibus_credentials: { login: 'oots', password: 'secret' },
    )
    stub_code_list(countries: { 'EL' => 'Grèce (la)', 'FR' => 'France (la)' })
  end

  describe 'GET /admin/common_services/access_points' do
    before { sign_in_as_administrator }

    it 'lists every party of the PMode and its MSH' do
      gateway_listing

      get admin_common_services_access_points_path

      expect(response).to have_http_status(:ok)
      expect(page.css('.access-point').size).to eq(12)
      expect(row('AP_EL_01').text).to include('https://as4.oots.example.gr/domibus/services/msh')
    end

    it 'repeats no identifier that is the name of the party' do
      gateway_listing

      get admin_common_services_access_points_path

      expect(row('AP_EL_01').at_css('.access-point__detail').text).not_to include('AP_EL_01')
      expect(row('AP_NL_01').at_css('.access-point__detail').text).to include('00000001805544434000')
    end

    it 'does not show the scheme of the identifier' do
      gateway_listing

      get admin_common_services_access_points_path

      expect(page.text).not_to include('urn:oasis:names:tc:ebcore:partyid-type')
    end

    it 'names the country of a member state\'s access point, and none for the others' do
      gateway_listing

      get admin_common_services_access_points_path

      expect(row('AP_EL_01').css('.country-tag').text).to include('Grèce')
      expect(row('ec_support_acc').css('.country-tag')).to be_empty
      expect(row('AP_NL_01').css('.country-tag')).to be_empty
    end

    it 'offers one button testing every access point' do
      gateway_listing

      get admin_common_services_access_points_path

      all = page.css('form').find { |form| form.text.include?("Tester tous les points d'accès") }
      expect(all['action']).to eq(admin_common_services_connectivity_tests_path)
      expect(all.at_css('input[name=party]')).to be_nil
    end

    it 'offers a test towards a party never tested' do
      gateway_listing

      get admin_common_services_access_points_path

      expect(row('AP_FR_01').text).to include('jamais testé')
      expect(row('AP_FR_01').css("form[action='#{admin_common_services_connectivity_tests_path}']")).not_to be_empty
    end

    it 'says a connection, with when the test was asked and nothing of when it left' do
      gateway_listing
      test = create(:connectivity_test, :acknowledged, party_name: 'AP_EL_01')

      get admin_common_services_access_points_path

      expect(row('AP_EL_01').text).to include('connecté', "Demandé le #{I18n.l(test.requested_at, format: :short)}")
      expect(row('AP_EL_01').text).not_to include('parti le')
    end

    it 'says a refusal for the configuration of the access point, with its code and detail' do
      gateway_listing
      create(:connectivity_test, :submitted, party_name: 'AP_EL_01', outcome: 'refused_for_configuration',
        error_code: 'EBMS:0003', error_detail: 'No matching party found')

      get admin_common_services_access_points_path

      expect(row('AP_EL_01').text).to include('refusé pour sa configuration', 'EBMS:0003', 'No matching party found')
    end

    it 'says a failure, a test without a verdict and one that never left' do
      gateway_listing
      create(:connectivity_test, :submitted, party_name: 'AP_EL_01', outcome: 'failed', error_code: 'EBMS:0005',
        error_detail: 'Connection refused')
      create(:connectivity_test, :submitted, party_name: 'AP_FI_01', outcome: 'no_verdict')
      create(:connectivity_test, party_name: 'AP_DE_01', outcome: 'not_submitted', submission_refusal: 'Connection refused')

      get admin_common_services_access_points_path

      expect(row('AP_EL_01').text).to include('en échec', 'EBMS:0005', 'Connection refused')
      expect(row('AP_FI_01').text).to include('sans verdict')
      expect(row('AP_DE_01').text).to include('non parti', 'Connection refused')
    end

    it 'offers no test towards a party it cannot address' do
      gateway_listing(gateway_parties.first(2) + [gateway_parties.last.merge('name' => 'AP_XX_01', 'identifiers' => [])])

      get admin_common_services_access_points_path

      expect(row('AP_XX_01').css('form')).to be_empty
    end

    it 'offers no test towards a party whose test is pending' do
      gateway_listing
      create(:connectivity_test, party_name: 'AP_EL_01')

      get admin_common_services_access_points_path

      expect(row('AP_EL_01').text).to include('en cours')
      expect(row('AP_EL_01').css('form')).to be_empty
    end

    it 'keeps the test of a party the PMode no longer declares, marked, without a button' do
      gateway_listing
      create(:connectivity_test, :acknowledged, party_name: 'AP_ZZ_01')

      get admin_common_services_access_points_path

      expect(row('AP_ZZ_01').text).to include('connecté', 'absent du PMode chargé')
      expect(row('AP_ZZ_01').css('form')).to be_empty
    end

    it 'hangs from the directories in the breadcrumb' do
      gateway_listing

      get admin_common_services_access_points_path

      expect(page.css('.fr-breadcrumb__link').map { |link| link.text.strip })
        .to eq(['Espace d’administration', 'Annuaires centraux', "Points d'accès"])
    end

    it 'answers the blocks alone when the page asks for them again' do
      gateway_listing
      create(:connectivity_test, party_name: 'AP_EL_01')

      get admin_common_services_access_points_path(fragment: 1)

      expect(response.headers['Deferred-Fragment']).to eq('1')
      expect(page.css('h1')).to be_empty
      expect(row('AP_EL_01')).to have_attributes(attributes: include('data-outcome', 'aria-busy'))
      expect(row('AP_EL_01')['data-outcome']).to eq('pending')
    end

    it 'answers 502 when the gateway does not answer' do
      stub_request(:get, listing).with(query: hash_including({})).to_raise(Faraday::ConnectionFailed.new('refused'))

      get admin_common_services_access_points_path

      expect(response).to have_http_status(:bad_gateway)
      expect(page.text).to include("La passerelle n'a pas répondu")
    end

    it 'answers 502 when the gateway refuses the Plugin User, and says so' do
      stub_request(:get, listing).with(query: hash_including({})).to_return(status: 401)

      get admin_common_services_access_points_path

      expect(response).to have_http_status(:bad_gateway)
      expect(page.text).to include("La passerelle a refusé l'accès de la France")
    end
  end

  describe 'POST /admin/common_services/connectivity_tests' do
    before { sign_in_as_administrator }

    it 'records the test pending and answers before anything is submitted' do
      gateway_listing

      expect { post admin_common_services_connectivity_tests_path, params: { party: 'AP_EL_01' } }
        .to have_enqueued_job(SubmitConnectivityTestJob).exactly(:once)

      expect(response).to redirect_to(admin_common_services_access_points_path)
      expect(ConnectivityTest.find_by!(party_name: 'AP_EL_01')).to have_attributes(outcome: 'pending',
        requested_at: be_within(1.second).of(Time.current), message_id: nil)
      expect(a_request(:post, %r{services/wsplugin})).not_to have_been_made
    end

    it 'answers the blocks rather than a redirection when the page posts in the background' do
      gateway_listing

      post admin_common_services_connectivity_tests_path, params: { party: 'AP_EL_01', fragment: 1 }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Deferred-Fragment']).to eq('1')
      expect(row('AP_EL_01')['data-outcome']).to eq('pending')
      expect(row('AP_EL_01')['aria-busy']).to eq('true')
      expect(row('AP_EL_01').css('form')).to be_empty
    end

    it 'tests every party but the ones pending' do
      gateway_listing(gateway_parties.first(3))
      create(:connectivity_test, party_name: gateway_parties.first['name'])

      expect { post admin_common_services_connectivity_tests_path }.to have_enqueued_job(SubmitConnectivityTestJob).exactly(:twice)
      expect(ConnectivityTest.pending.count).to eq(3)
    end

    it 'tests nothing the PMode does not declare' do
      gateway_listing

      expect { post admin_common_services_connectivity_tests_path, params: { party: 'AP_ZZ_01' } }
        .not_to have_enqueued_job(SubmitConnectivityTestJob)
    end
  end

  describe 'without a session' do
    it 'sends the visitor to the login page' do
      get admin_common_services_access_points_path

      expect(response).to redirect_to(new_admin_session_path)
    end

    it 'starts no test for a visitor' do
      expect { post admin_common_services_connectivity_tests_path, params: { fragment: 1 } }
        .not_to have_enqueued_job(SubmitConnectivityTestJob)
      expect(response).to redirect_to(new_admin_session_path)
      expect(ConnectivityTest.count).to eq(0)
    end
  end
end
