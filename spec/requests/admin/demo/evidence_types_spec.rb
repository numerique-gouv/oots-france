require 'rails_helper'

# OOTS-263: the evidence type a card names, where its country publishes several
# for the requirement. Austria publishes two for « (TEST) Test Requirement »,
# each in a list of its own, served by the same provider under two levels of
# assurance; its access point announces `oots-edm:v1.2`, so the journey is one.
RSpec.describe 'Admin::Demo::EvidenceTypes' do
  let(:exigence) { '00000000-0000-0000-0000-000000000000' }
  let(:high) { 'cb10c17a-8d2a-40af-bb77-e797182280bf' }
  let(:low) { '198ab7cc-8571-451d-9727-4be8ed221951' }

  before do
    sign_in
    identify_demo_user(version: 'v1.2')
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_at', country: 'AT')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_at_cb10c17a', evidence_type: type_id(high))
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_at_198ab7cc', evidence_type: type_id(low))
    choose_country('AT')
  end

  # CA2: two types, in the order the capture publishes them, nothing chosen.
  it 'offers the types the country publishes, on a prompt, and nothing to request' do
    page

    expect(type_list.at_css("label[for='#{type_list.at_css('select')['id']}']").text.squish)
      .to eq('Document to request')
    expect(type_list.css('option').map { |option| [option.text.squish, option['value']] }).to eq(
      [['Select a document', ''], ['Test Evidence Austria (AT)', high],
       ['Austrian Test Evidence Type without Reauthentication', low]],
    )
    expect(carte.at_css('.requirement-card__actions').text.squish).to be_empty
    expect(carte['class']).not_to include('requirement-card--unsatisfiable')
    expect(dsd_asked).not_to have_been_made
  end

  # CA3: the card alone, resolved on that type, the provider the Data Service
  # Directory publishes for it, and nothing asked of the contract.
  it 'answers the card alone, resolved on the type chosen' do
    choose_type(low)

    fragment = response.parsed_body

    expect(response.headers['Deferred-Fragment']).to eq('1')
    expect(named(fragment)).to eq(['Austrian Test Evidence Type without Reauthentication',
                                   'Test Evidence Provider Austria (AT)'])
    expect(fragment.at_css('.demo-request button').text.squish).to eq('Request the document')
    expect(fragment.at_css('select[name=type] option[selected]')['value']).to eq(low)
    expect(fragment.css('select[name=type] option').pluck('value')).not_to include('')
    expect(contract_demands).to be_empty
  end

  # CA11, first half: the type holds with the card.
  it 'renders the card on the type chosen when the page is reloaded' do
    choose_type(high)
    page

    expect(type_list.at_css('option[selected]')['value']).to eq(high)
    expect(named(carte)).to eq(['Test Evidence Austria (AT)', 'Test Evidence Provider Austria (AT)'])
    expect(Demo::Card.sole.evidence_type_id).to eq(type_id(high))
  end

  # CA12, server side: the types are the country's.
  it 'forgets the type chosen when another country is chosen' do
    choose_type(high)
    choose_country('FI')
    choose_country('AT')
    page

    expect(type_list.at_css('option[selected]')).to be_nil
    expect(type_list.at_css('option').text.squish).to eq('Select a document')
  end

  # CA6, first half: the request leaves with the type the card named.
  it 'has the button ask for the type chosen' do
    stub_oots_france_public_keys
    stub_evidence_request
    stub_exchange_state
    choose_type(low)
    post admin_demo_demande_path(exigence:, version: 'v1.2', procedure: 'T1')

    expect(evidence_request_query['idTypeJustificatif']).to eq(type_id(low))
    expect(Demo::Request.sole.evidence_type_id).to eq(type_id(low))
  end

  # RG8: what no list of the page offers reloads it.
  it 'refuses a type the country does not publish, or that is no UUID' do
    choose_type('00000000-0000-0000-0000-00000000dead')
    expect(response).to have_http_status(:unprocessable_content)

    choose_type('pas-un-uuid')
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'answers 502, and no fragment, when the directories cannot be reached' do
    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search").with(query: hash_including({})).to_timeout

    choose_type(low)

    expect(response).to have_http_status(:bad_gateway)
    expect(response.headers['Deferred-Fragment']).to be_nil
  end

  # An added card resolves from the requirement its row keeps, and is offered
  # the choice and holds it the same way.
  describe 'on a card the operator added' do
    let(:added) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }

    before do
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_at', country: 'AT',
        requirement: "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{added}")
      Demo::Card.add(journey_id: Demo::Card.sole.journey_id, country_code: 'AT', languages: %w[EN],
        requirement: build(:requirement, id: "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{added}"))
    end

    it 'offers the types on a prompt, and holds the one chosen' do
      page
      expect(added_card.at_css('.requirement-card__evidence-type option[selected]')).to be_nil

      patch(admin_demo_type_justificatif_path(exigence: added, version: 'v1.2', procedure: 'T1'), params: { type: low })
      expect(response.headers['Deferred-Fragment']).to eq('1')

      page
      expect(added_card.at_css('.requirement-card__evidence-type option[selected]')['value']).to eq(low)
    end

    def added_card = response.parsed_body.at_css("main #exigence-#{added}")
  end

  # CA13 and RG10: a card following a request names its country in its box and
  # the type asked for, offers neither list, and ignores a type submitted
  # meanwhile; once refused, both lists come back on what was asked.
  describe 'on a card following a request' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      choose_type(low)
      post admin_demo_demande_path(exigence:, version: 'v1.2', procedure: 'T1')
    end

    it 'offers neither list, and names the country and the type of the request' do
      page

      expect(carte.css('select')).to be_empty
      expect(carte.at_css('.fr-card__desc .country-tag').text.squish).to eq('🇦🇹 AT')
      expect(named(carte).first).to eq('Austrian Test Evidence Type without Reauthentication')
    end

    it 'ignores a type submitted while the request is under way' do
      choose_type(high)

      expect(response.parsed_body.css('select')).to be_empty
      expect(named(response.parsed_body).first).to eq('Austrian Test Evidence Type without Reauthentication')

      page

      expect(named(carte).first).to eq('Austrian Test Evidence Type without Reauthentication')
      expect(Demo::Card.sole.evidence_type_id).to eq(type_id(low))
    end

    it 'offers both lists again, on what was asked, once the correspondent refused' do
      stub_exchange_state(statut: 'failed')

      page

      expect(carte.at_css('select[name=pays] option[selected]')['value']).to eq('AT')
      expect(type_list.at_css('option[selected]')['value']).to eq(low)
      expect(carte.at_css('.demo-request button').text.squish).to eq('Retry to request')
    end
  end

  def page = get(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))

  def carte = response.parsed_body.at_css("main #exigence-#{exigence}")

  # The type and the provider the foot names, as the directories publish them.
  def named(node) = node.css('.requirement-card__actions .directory-value').map { |value| seen(value) }

  def type_list = carte.at_css('.requirement-card__evidence-type')

  def type_id(uuid) = "https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/AT/#{uuid}"

  def choose_country(code) = patch(admin_demo_pays_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { pays: code })

  def choose_type(uuid)
    patch(admin_demo_type_justificatif_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { type: uuid })
  end

  def dsd_asked
    a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('country-code' => 'AT'))
  end
end
