require 'rails_helper'

# OOTS-269: the question the Data Service Directory asks on a card before it can
# name the provider — `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3. Greece publishes
# two evidence types for « (TEST) Test Requirement », and asks « Projectathon
# test case » of `8b3b6a31-…`, whose code list names eight test cases; answered
# `TC03`, it names `AP_EL_02`, whose access point announces `oots-edm:v1.2`.
RSpec.describe 'Admin::Demo::ProviderClassifications' do
  let(:exigence) { '00000000-0000-0000-0000-000000000000' }
  let(:projectathon) { '8b3b6a31-9b62-48d7-8926-997df4f91bb5' }
  let(:question) { '1254f10f-406e-4f28-b1ba-d107b93fa264' }
  let(:code_list) do
    'https://query.cs.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases/8b3b6a31-9b62-48d7-8926-997df4f91bb5'
  end

  before do
    sign_in
    identify_demo_user(version: 'v1.2')
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_el', country: 'EL')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_classification_requise_el_8b3b6a31',
      evidence_type: type_id)
    stub_answered('TC03', 'dsd_data_services_el_8b3b6a31_tc03')
    stub_request(:get, code_list).to_return(body: classification_list, headers: { 'Content-Type' => 'text/plain' })
    choose_country('EL')
    choose_type
  end

  # CA1: the question, its values, and nothing named or requested yet.
  it 'asks the question in a list of the values the code list publishes, and names nothing yet' do
    page

    expect(seen(questions.at_css('label'))).to eq('Projectathon test case')
    expect(questions.at_css('label .directory-value')['lang']).to eq('EN')
    expect(questions.css('option').map { |option| [option.text.squish, option['value']] }.first(3)).to eq(
      [['Select a value', ''], ['TC03 - Evidence request error flow due to Basic Registry error', 'TC03'],
       ['TC06 - Basic evidence request with reauthentication and preview', 'TC06']],
    )
    expect(questions.css('option').size).to eq(9)
    expect(questions.at_css('button')).to be_nil
    expect(resolution.text.squish).to be_empty
    expect(carte['class']).not_to include('requirement-card--unsatisfiable')
  end

  # CA3: the list is read at each render, never kept.
  it 'reads the code list and asks the directory again at each render' do
    2.times { page }

    expect(a_request(:get, code_list)).to have_been_made.times(3)
  end

  # CA3: a list that cannot be read costs its values alone.
  it 'asks in a text field where the code list cannot be read' do
    stub_request(:get, code_list).to_return(status: 500)

    page

    expect(questions.at_css("input[type=text][name='classificationFournisseur[#{question}]']")).to be_present
    expect(questions.css('select')).to be_empty
  end

  # CA4 and CA5: the same query, augmented; the card alone, resolved on the
  # answer, the question staying on it.
  it 'answers the card alone, resolved on the provider the answer designates' do
    answer('TC03')

    fragment = response.parsed_body
    expect(response.headers['Deferred-Fragment']).to eq('1')
    expect(fragment.css('.requirement-card__actions [data-demo-card-target=resolution] .directory-value')
      .map { |value| seen(value) }).to eq(['Projectathon test evidence', 'Ministry of Digital Governance'])
    expect(fragment.at_css('.demo-request button').text.squish).to eq('Request the document')
    expect(fragment.at_css("select[name='classificationFournisseur[#{question}]'] option[selected]")['value'])
      .to eq('TC03')
    expect(fragment.css("select[name='classificationFournisseur[#{question}]'] option").pluck('value')).not_to include('')
    expect(answered_query).to have_been_made
    expect(contract_demands).to be_empty
  end

  # CA8: the answer holds with the card, and a reload replays both queries.
  it 'renders the card on its answer when the page is reloaded' do
    answer('TC03')
    page

    expect(seen(resolution.at_css('.directory-value'))).to eq('Projectathon test evidence')
    expect(questions.at_css('option[selected]')['value']).to eq('TC03')
    expect(Demo::Card.find_by(requirement_uuid: exigence).provider_classifications).to eq(question => 'TC03')
  end

  # CA8: choosing another type or country undoes the answers.
  it 'forgets the answer when another evidence type is chosen' do
    answer('TC03')
    patch(admin_demo_type_justificatif_path(exigence:, version: 'v1.2', procedure: 'T1'),
      params: { type: '8b0aeabd-a0fd-4c62-bb15-71282fbf5992' })

    expect(Demo::Card.find_by(requirement_uuid: exigence).provider_classifications).to eq({})
  end

  it 'forgets the answer when another country is chosen' do
    answer('TC03')
    choose_country('FI')
    choose_country('EL')
    choose_type
    page

    expect(questions.at_css('option[selected]')).to be_nil
    expect(Demo::Card.find_by(requirement_uuid: exigence).provider_classifications).to eq({})
  end

  # CA7: a refusal of the augmented query is said like any other, the
  # question staying asked.
  it 'says a refusal of the answered query as the card says any other, still asking' do
    stub_answered('TC02', 'dsd_aucun_service_fr')

    answer('TC02')

    fragment = response.parsed_body
    expect(fragment.at_css('.requirement-card__refusal').text.squish).to include('No provider listed by EL for this evidence')
    expect(fragment.at_css('.demo-request')).to be_nil
    expect(fragment.at_css('form.requirement-card__questions')).to be_present
    expect(fragment.at_css('.requirement-card')['class']).not_to include('requirement-card--unsatisfiable')
  end

  # RG4, server side: what no form of the page sends reloads it.
  it 'refuses an answer missing, or one to a question nobody asked' do
    answer('')
    expect(response).to have_http_status(:unprocessable_content)

    patch path, params: { classificationFournisseur: { question => 'TC03', 'aaaaaaaa-0000-4000-8000-000000000000' => 'X' } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'answers 502, and no fragment, when the directories cannot be reached' do
    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search").with(query: hash_including({})).to_timeout

    answer('TC03')

    expect(response).to have_http_status(:bad_gateway)
    expect(response.headers['Deferred-Fragment']).to be_nil
  end

  # CA9: the request leaves with the answer the card was resolved on.
  describe 'the request of the card' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      answer('TC03')
      post admin_demo_demande_path(exigence:, version: 'v1.2', procedure: 'T1')
    end

    it 'sends the answer, and the register keeps it' do
      expect(evidence_request_query['classificationFournisseur']).to eq(question => 'TC03')
      expect(evidence_request_query['idTypeJustificatif']).to eq(type_id)
      expect(Demo::Request.sole.provider_classifications).to eq(question => 'TC03')
    end

    it 'refuses an answer submitted while the request is under way' do
      answer('TC02')

      expect(response).to have_http_status(:unprocessable_content)
      expect(Demo::Request.sole.provider_classifications).to eq(question => 'TC03')
    end

    # CA8: the card following a request asks nothing.
    it 'asks nothing while the request is under way, and asks again on its answer once refused' do
      page
      expect(carte.at_css('form.requirement-card__questions')).to be_nil

      stub_exchange_state(statut: 'failed')
      page
      expect(questions.at_css('option[selected]')['value']).to eq('TC03')
      expect(carte.at_css('.demo-request button').text.squish).to eq('Retry to request')
    end
  end

  # An added card resolves from the requirement its row keeps, and is answered
  # and holds its answers the same way.
  describe 'on a card the operator added' do
    let(:added) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }

    before do
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_el', country: 'EL',
        requirement: "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{added}")
      Demo::Card.add(journey_id: Demo::Card.sole.journey_id, country_code: 'EL', languages: %w[EN],
        requirement: build(:requirement, id: "https://sr.acc.oots.tech.ec.europa.eu/requirements/#{added}"))
      patch(admin_demo_type_justificatif_path(exigence: added, version: 'v1.2', procedure: 'T1'), params: { type: projectathon })
    end

    it 'is resolved on its answer, and asks again on it at the next render' do
      patch admin_demo_classification_fournisseur_path(exigence: added, version: 'v1.2', procedure: 'T1'),
        params: { classificationFournisseur: { question => 'TC03' } }
      expect(response.headers['Deferred-Fragment']).to eq('1')

      page
      card = response.parsed_body.at_css("main #exigence-#{added}")
      expect(card.at_css('form.requirement-card__questions option[selected]')['value']).to eq('TC03')
      expect(seen(card.at_css('[data-demo-card-target=resolution] .directory-value'))).to eq('Projectathon test evidence')
    end
  end

  def page = get(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))

  def path = admin_demo_classification_fournisseur_path(exigence:, version: 'v1.2', procedure: 'T1')

  def carte = response.parsed_body.at_css("main #exigence-#{exigence}")

  def questions = carte.at_css('form.requirement-card__questions')

  def resolution = carte.at_css('[data-demo-card-target=resolution]')

  def type_id = "https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/EL/#{projectathon}"

  def classification_list = Rails.root.join('spec/fixtures/common_services/liste_classification_el_projectathon.gc').read

  def answer(value) = patch(path, params: { classificationFournisseur: { question => value } })

  def choose_country(code) = patch(admin_demo_pays_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { pays: code })

  def choose_type
    patch(admin_demo_type_justificatif_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { type: projectathon })
  end

  # Declared after the question it answers, so that WebMock, which takes the
  # last stub matching, serves it to the augmented query alone.
  def stub_answered(value, fixture)
    body, headers = common_services_answer(fixture)

    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('evidence-type-classification' => type_id, question => value))
      .to_return(body:, headers:)
  end

  def answered_query
    a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('evidence-type-classification' => type_id, 'country-code' => 'EL', question => 'TC03'))
  end
end
