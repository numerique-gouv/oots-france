require 'rails_helper'

# OOTS-270: a combination of several evidence types, asked for whole. Greece
# publishes « Compound test evidence » for « (TEST) Test Requirement », which
# calls on « Projectathon test evidence » — on which the Data Service Directory
# asks « Projectathon test case » — and « Simple test evidence », served by the
# Ministry of Digital Governance without a question. Both providers sit behind
# `AP_EL_02`, which announces `oots-edm:v1.2`, so the journey is one.
RSpec.describe 'Admin::Demo::Combinations' do
  let(:exigence) { '00000000-0000-0000-0000-000000000000' }
  let(:compound) { 'e9bb55fc-e744-493d-ab9d-055f9c7e1d28' }
  let(:projectathon) { '8b3b6a31-9b62-48d7-8926-997df4f91bb5' }
  let(:simple) { '8b0aeabd-a0fd-4c62-bb15-71282fbf5992' }
  let(:question) { '1254f10f-406e-4f28-b1ba-d107b93fa264' }
  let(:projectathon_exchange) { 'aaaaaaaa-0000-4000-8000-0000000000b1' }
  let(:simple_exchange) { 'aaaaaaaa-0000-4000-8000-0000000000c1' }

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
      evidence_type: type_id(projectathon))
    stub_answered('TC03', 'dsd_data_services_el_8b3b6a31_tc03')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_el_8b0aeabd', evidence_type: type_id(simple))
    stub_request(:get, %r{/codelists/EL/ProjectathonTestCases/})
      .to_return(body: Rails.root.join('spec/fixtures/common_services/liste_classification_el_projectathon.gc').read,
        headers: { 'Content-Type' => 'text/plain' })
    stub_oots_france_public_keys
    stub_evidence_request_for_type(type_id(projectathon), projectathon_exchange)
    stub_evidence_request_for_type(type_id(simple), simple_exchange)
    stub_exchange_state(projectathon_exchange, statut: 'pending')
    stub_exchange_state(simple_exchange, statut: 'pending')
    patch admin_demo_pays_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { pays: 'EL' }
  end

  # CA1: one entry per list, named by its type or by its `sdg:Name`, in the
  # order the Evidence Broker writes them.
  it 'offers each combination the country publishes, in the order it writes them' do
    page

    expect(carte.css('select[name=combinaison] option').map { |option| option.text.squish }).to eq(
      ['Select a document', 'Simple test evidence', 'Projectathon test evidence', 'Compound test evidence'],
    )
  end

  # CA3, CA4: a line per type, the question on its own; nothing to request
  # until it is answered, and the card is no dead end.
  it 'names a line per type of the combination chosen, and asks the question on its line' do
    choose_combination

    fragment = response.parsed_body
    expect(fragment.css('[data-demo-card-line]').pluck('data-demo-card-line')).to eq([projectathon, simple])
    expect(fragment.at_css("[data-demo-card-line='#{projectathon}'] form.requirement-card__questions")).to be_present
    expect(lines_said(fragment).last).to eq(['Simple test evidence', 'Ministry of Digital Governance'])
    expect(fragment.at_css('.demo-request')).to be_nil
    expect(fragment.at_css('.requirement-card')['class']).not_to include('requirement-card--unsatisfiable')
    expect(contract_demands).to be_empty
  end

  # CA4, last clause: the answer resolves its line, and the one button comes.
  it 'offers one button for the whole combination once the question is answered' do
    choose_combination
    answer('TC03')

    fragment = response.parsed_body
    expect(lines_said(fragment)).to eq([['Projectathon test evidence', 'Ministry of Digital Governance'],
                                        ['Simple test evidence', 'Ministry of Digital Governance']])
    expect(fragment.css('.demo-request button').map { |button| button.text.squish }).to eq(['Request the documents'])
  end

  describe 'the button of the combination' do
    before do
      choose_combination
      answer('TC03')
    end

    # CA5: a request per type, in the order of the list, under the conversation
    # of the journey, each with its own answers and the combination it came
    # from.
    it 'asks for each type in its own request, in order, under one conversation' do
      post demande_path

      expect(contract_demands.map { |demand| query_of(demand)['idTypeJustificatif'] })
        .to eq([type_id(projectathon), type_id(simple)])
      expect(conversations_asked.uniq.size).to eq(1)
      expect(contract_demands.map { |demand| query_of(demand)['classificationFournisseur'] })
        .to eq([{ question => 'TC03' }, nil])
      expect(Demo::Request.order(:id).pluck(:exchange_id, :evidence_type_list_id))
        .to eq([[projectathon_exchange, compound], [simple_exchange, compound]])
    end

    # CA6: a block per request, each under the name of its type.
    it 'answers with a block per request, each waiting' do
      post demande_path

      expect(response.parsed_body.at_css('.demo-request__body')['data-outcome']).to eq('pending pending')
      expect(response.parsed_body.css('.demo-request__type').map { |name| seen(name.at_css('.directory-value')) })
        .to eq(['Projectathon test evidence', 'Simple test evidence'])
    end

    # CA5: a refusal of the contract stops the requests after it, and each
    # block keeps its own button, including after a reload.
    describe 'when the contract refuses the first' do
      before do
        stub_evidence_request_for_type(type_id(projectathon), nil, status: 422, error: 'EB:ERR:0001')
        post demande_path
      end

      it 'sends no other, says the refusal in its block, and offers the other its own button' do
        expect(contract_demands.size).to eq(1)
        expect(Demo::Request.count).to eq(0)

        first, second = blocks(response.parsed_body)
        expect(first.at_css('.demo-request__failure').text).to include('EB:ERR:0001')
        expect(second.at_css('button').text.squish).to eq('Request the document')
      end

      it 'offers each block its own button once the page is reloaded' do
        page

        expect(blocks(carte).map { |block| block.at_css('button').text.squish })
          .to eq(['Request the document', 'Request the document'])
      end

      it 'asks for the type of the block clicked, and for it alone' do
        post demande_path(type: simple)

        expect(query_of(contract_demands.last)['idTypeJustificatif']).to eq(type_id(simple))
        expect(contract_demands.size).to eq(2)
        expect(Demo::Request.sole.exchange_id).to eq(simple_exchange)
      end
    end

    # RG4: those already accepted run.
    describe 'when the contract refuses the second' do
      before do
        stub_evidence_request_for_type(type_id(simple), nil, status: 422, error: 'EB:ERR:0001')
        post demande_path
      end

      it 'keeps the first request running, and says the refusal in the block of the second' do
        expect(contract_demands.size).to eq(2)
        expect(Demo::Request.sole.exchange_id).to eq(projectathon_exchange)

        first, second = blocks(response.parsed_body)
        expect(first['data-state']).to eq('pending')
        expect(second['data-refused-click']).to eq('true')
        expect(second.at_css('.demo-request__failure').text).to include('EB:ERR:0001')
      end
    end

    # Requirement 27 of chapter 1 §2: a combination is asked for whole, so a
    # line that names nothing keeps every request home.
    it 'sends nothing while a line of the combination names no provider' do
      card = Demo::Card.sole
      card.update!(evidence_types: card.evidence_types.map.with_index { |line, rank| rank.zero? ? line : line.merge('provider_name' => nil) })

      post demande_path(type: projectathon)

      expect(response).to redirect_to(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))
      expect(contract_demands).to be_empty
    end

    it 'sends nothing for a type the card does not name' do
      post demande_path(type: '11111111-2222-3333-4444-555555555555')

      expect(response).to redirect_to(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))
      expect(contract_demands).to be_empty
    end

    # CA6: one document in, one refusal: each says its own, and the retry asks
    # for its type alone, under a new exchange.
    describe 'when one document comes back and the other is refused' do
      before do
        post demande_path
        Demo::Request.find_by(exchange_id: projectathon_exchange).receive_evidence!("%PDF-1.4\nprojectathon".b)
        stub_exchange_state(simple_exchange, statut: 'failed', codeErreur: 'EDM:ERR:0003')
      end

      it 'says each in its own block' do
        page

        first, second = blocks(carte)
        expect(first.text).to include('Document retrieved successfully')
        expect(first.at_css('a')['href']).to include("type=#{projectathon}")
        expect(second.text).to include('The document cannot be provided', 'Retry to request')
      end

      it 'asks for the refused type alone again, under a new exchange' do
        stub_evidence_request_for_type(type_id(simple), 'aaaaaaaa-0000-4000-8000-0000000000c2')
        stub_exchange_state('aaaaaaaa-0000-4000-8000-0000000000c2', statut: 'pending')

        post demande_path(type: simple)

        expect(contract_demands.size).to eq(3)
        expect(query_of(contract_demands.last)['idTypeJustificatif']).to eq(type_id(simple))
        expect(blocks(response.parsed_body).pluck('data-state')).to eq(%w[delivered pending])
      end

      it 'serves the document of the type the address names' do
        get admin_demo_justificatif_path(exigence:, type: projectathon, version: 'v1.2', procedure: 'T1')
        expect(response.body.b).to eq("%PDF-1.4\nprojectathon".b)

        get admin_demo_justificatif_path(exigence:, type: simple, version: 'v1.2', procedure: 'T1')
        expect(response).to redirect_to(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))
      end
    end

    # CA7: the card follows its requests while one of them runs.
    describe 'while a request runs' do
      before { post demande_path }

      it 'offers neither list nor question, and names the combination asked for' do
        page

        expect(carte.css('select')).to be_empty
        expect(carte.at_css('form.requirement-card__questions')).to be_nil
        expect(lines_said(carte).map(&:first)).to eq(['Projectathon test evidence', 'Simple test evidence'])
      end

      it 'offers both lists again, on the combination and its answers, once every request is refused' do
        stub_exchange_state(projectathon_exchange, statut: 'failed', codeErreur: 'EDM:ERR:0003')
        stub_exchange_state(simple_exchange, statut: 'failed', codeErreur: 'EDM:ERR:0003')

        page

        expect(carte.at_css('select[name=combinaison] option[selected]')['value']).to eq(compound)
        expect(carte.at_css('form.requirement-card__questions option[selected]')['value']).to eq('TC03')
      end
    end
  end

  # CA7: the combination holds with the card, and goes with its country.
  it 'renders the card on the combination chosen when the page is reloaded, and forgets it with the country' do
    choose_combination
    page
    expect(carte.at_css('select[name=combinaison] option[selected]')['value']).to eq(compound)
    expect(carte.css('[data-demo-card-line]').size).to eq(2)

    patch admin_demo_pays_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { pays: 'FI' }
    patch admin_demo_pays_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { pays: 'EL' }
    page
    expect(carte.at_css('select[name=combinaison] option[selected]')).to be_nil
  end

  # CA7: another combination undoes the answers of every line, even of a type
  # the new one calls on too.
  it 'forgets the answers when another combination is chosen' do
    choose_combination
    answer('TC03')
    choose_combination('f9e8ba9d-b82b-4ced-b697-ebd153262a6d')

    expect(Demo::Card.sole.provider_classifications).to eq({})
    expect(response.parsed_body.at_css('form.requirement-card__questions option[selected]')).to be_nil
  end

  def page = get(admin_demo_documents_path(version: 'v1.2', procedure: 'T1'))

  def carte = response.parsed_body.at_css("main #exigence-#{exigence}")

  def blocks(node) = node.css('[data-demo-request-block]').to_a

  # The type and the provider each line names, as the directories publish them.
  def lines_said(node)
    node.css('[data-demo-card-line]').map do |line|
      line.css('[data-demo-card-target~=resolution] .directory-value').map { |value| seen(value) }
    end
  end

  def demande_path(**) = admin_demo_demande_path(exigence:, version: 'v1.2', procedure: 'T1', **)

  def type_id(uuid) = "https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/EL/#{uuid}"

  def query_of(demand) = Rack::Utils.parse_nested_query(demand.uri.query.to_s)

  def choose_combination(list = compound)
    patch admin_demo_combinaison_path(exigence:, version: 'v1.2', procedure: 'T1'), params: { combinaison: list }
  end

  def answer(value)
    patch admin_demo_classification_fournisseur_path(exigence:, type: projectathon, version: 'v1.2', procedure: 'T1'),
      params: { classificationFournisseur: { question => value } }
  end

  # Declared after the question it answers, so that WebMock, which takes the
  # last stub matching, serves it to the augmented query alone.
  def stub_answered(value, fixture)
    body, headers = common_services_answer(fixture)

    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/dsd/rest/search")
      .with(query: hash_including('evidence-type-classification' => type_id(projectathon), question => value))
      .to_return(body:, headers:)
  end
end
