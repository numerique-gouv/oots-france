require 'rails_helper'

# The cards the operator adds to the documents page beyond those the Evidence
# Broker lists for the procedure of the journey (RG6 to RG10 of OOTS-253).
RSpec.describe 'Admin::Demo::Cards' do
  # The two requirements `eb_requirements_t1_fr` lists for `T1`, and one the
  # catalogue holds beside them, which Finland serves.
  let(:premiere) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
  let(:seconde) { '2d21a531-d30e-4e30-9e5e-b53d6aedb30b' }
  let(:ajoutee) { '00000000-0000-0000-0000-000000000000' }
  let(:procedure) { 'T1' }

  before do
    sign_in
    identify_demo_user(procedure:)
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
    stub_procedure_requirements('T1', 'eb_requirements_t1_fr')
    stub_procedure_requirements('U1', 'eb_requirements_vides')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi', country: 'FI')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  # CA6: under the cards of the procedure, every requirement of the catalogue
  # less those the page carries, named as the directory names them.
  describe 'the choice of a card to add' do
    it 'offers the catalogue less the cards of the procedure, under them' do
      get documents_path

      expect(response.parsed_body.css('main h2').map { |heading| heading.text.squish }).to include('Add another evidence')
      # Said off screen only: the heading already says what the list offers.
      expect(added_label.text.squish).to eq('Document to add')
      expect(added_label['class']).to include('fr-sr-only')
      offered = options.pluck('value')
      expect(offered).to include(ajoutee)
      expect(offered).not_to include(premiere, seconde)
      expect(options.find { |option| option['value'] == ajoutee }.text).to eq('(TEST) Test Requirement')
      expect(response.parsed_body.at_css("main form[action='#{cartes_path}'] [type=submit]")['value']).to eq('Add')
    end

    context 'when the Evidence Broker lists nothing for the procedure' do
      let(:procedure) { 'U1' }

      it 'says so, and offers the whole catalogue' do
        get documents_path

        expect(response.parsed_body.css('main').text).to include('The European directories listed no evidence')
        expect(options.size).to eq(Directories::Catalogue.new.requirements.size + 1)
      end
    end

    # CA11: the catalogue costs the choice and nothing else.
    it 'stands without the choice when the catalogue cannot be read, and logs why' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_excluding('procedure-id' => 'T1')).to_timeout
      stub_procedure_requirements('T1', 'eb_requirements_t1_fr')
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides')
      allow(Rails.logger).to receive(:warn).and_call_original

      get documents_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('main .requirement-card').size).to eq(2)
      expect(added_label).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Catalogue de l'Evidence Broker illisible/)
    end
  end

  # CA7: a card like the others, under those of the procedure, with a cross.
  describe 'POST /admin/demo/v2.0/T1/cartes' do
    it 'adds the card under those of the procedure, resolved in France, with a cross of its own' do
      post cartes_path, params: { exigence: ajoutee }

      expect(response).to redirect_to(documents_path(anchor: "exigence-#{ajoutee}"))
      get documents_path

      cartes = response.parsed_body.css('main .requirement-card')
      expect(cartes.pluck('id')).to eq(["exigence-#{premiere}", "exigence-#{seconde}", "exigence-#{ajoutee}"])
      expect(seen(cartes.last.at_css('.fr-card__title'))).to eq('(TEST) Test Requirement')
      expect(cartes.last.at_css('.fr-card__desc .country-tag').text.squish).to include('France')
      expect(cartes.last.text).to include('No provider')
      expect(cartes.map { |carte| carte.css('.requirement-card__remove button').map { |b| b['title'] } })
        .to eq([[], [], ['Remove this document']])
      expect(options.pluck('value')).not_to include(ajoutee)
    end

    it 'never asks the Evidence Broker which procedure the added requirement belongs to' do
      post cartes_path, params: { exigence: ajoutee }
      get documents_path

      asked = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.map do |signature|
        Rack::Utils.parse_nested_query(signature.uri.query.to_s)
      end
      first_queries = asked.select { |query| query['queryId'].to_s.include?('requirements-by-procedure') }
      expect(first_queries.pluck('procedure-id').uniq).to contain_exactly('T1', nil)
      expect(eb_asked('evidence-types-by-requirement', 'FR', ajoutee)).to have_been_made
    end

    # The form was rendered while the catalogue answered; the click may land
    # after it stopped.
    it 'sends the operator back to the page when the catalogue cannot be read, and logs why' do
      stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
        .with(query: hash_excluding('procedure-id' => 'T1')).to_timeout
      allow(Rails.logger).to receive(:warn).and_call_original

      post cartes_path, params: { exigence: ajoutee }

      expect(response).to redirect_to(documents_path)
      expect(Demo::Card.added(journey_id)).to be_empty
      expect(Rails.logger).to have_received(:warn).with(/Catalogue de l'Evidence Broker illisible/)
    end

    # The list opens on an empty, required option; a submission that still
    # chose nothing adds nothing.
    it 'opens the list on nothing chosen, and adds nothing when nothing is chosen' do
      get documents_path

      expect(options.first).to have_attributes(text: 'Select a document')
      expect(options.first.to_h).to include('value' => '', 'disabled' => 'disabled', 'selected' => 'selected')
      expect(response.parsed_body.at_css('main select#exigence-a-ajouter')['required']).to be_present

      post cartes_path, params: { exigence: '' }

      expect(response).to redirect_to(documents_path)
      expect(Demo::Card.added(journey_id)).to be_empty
    end

    # The catalogue changed since the page was rendered: nothing is added, and
    # the log says which requirement.
    it 'adds nothing of a requirement the catalogue no longer holds, and logs it' do
      allow(Rails.logger).to receive(:warn).and_call_original

      post cartes_path, params: { exigence: '12345678-1234-1234-1234-123456789012' }

      expect(response).to redirect_to(documents_path)
      expect(Demo::Card.added(journey_id)).to be_empty
      expect(Rails.logger).to have_received(:warn).with(/12345678-1234-1234-1234-123456789012/)
    end

    # No form renders a value that is no UUID, and no directory is asked about it.
    it 'refuses a value that is no UUID, asking no directory' do
      post cartes_path, params: { exigence: '../x' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Demo::Card.added(journey_id)).to be_empty
      expect(a_request(:get, %r{/eb/rest/search})).not_to have_been_made
    end

    # RG9: one card per requirement, whichever added it; a resubmission lands
    # on the card already there.
    it 'adds no second card of a requirement the page already carries' do
      get documents_path
      post cartes_path, params: { exigence: premiere }

      expect(response).to redirect_to(documents_path(anchor: "exigence-#{premiere}"))

      post cartes_path, params: { exigence: ajoutee }
      post cartes_path, params: { exigence: ajoutee }

      expect(response).to redirect_to(documents_path(anchor: "exigence-#{ajoutee}"))
      expect(Demo::Card.added(journey_id).count).to eq(1)
    end
  end

  # CA8: the choice of a country resolves an added card from its own
  # requirement, the procedure of the journey publishing it or not.
  describe 'the country of an added card' do
    before do
      get documents_path
      post cartes_path, params: { exigence: ajoutee }
    end

    it 'resolves it in the country chosen, without touching the cards of the procedure' do
      patch pays_path(ajoutee), params: { pays: 'FI' }

      expect(response.parsed_body.text).to include('Keha v. 2.0', 'Dummy PDF - FI')
      expect(response.parsed_body.at_css('.requirement-card__remove button')['title']).to eq('Remove this document')
    end

    context 'when the Evidence Broker lists nothing for the procedure' do
      let(:procedure) { 'U1' }

      it 'resolves it all the same' do
        patch pays_path(ajoutee), params: { pays: 'FI' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.text).to include('Keha v. 2.0', 'Dummy PDF - FI')
      end
    end

    # CA9: the card belongs to the journey, and its request leaves for what it
    # showed.
    it 'keeps it in its country on a reload, and asks for it there under the procedure of the journey' do
      stub_oots_france_public_keys
      stub_evidence_request
      stub_exchange_state
      patch pays_path(ajoutee), params: { pays: 'FI' }

      get documents_path
      carte = response.parsed_body.at_css("main #exigence-#{ajoutee}")
      expect(carte.at_css('select option[selected]')['value']).to eq('FI')

      post admin_demo_demande_path(exigence: ajoutee, version: 'v2.0', procedure:)

      expect(evidence_request_query).to include(
        'idExigence' => requirement_uri(ajoutee), 'exigenceHorsDemarche' => 'true',
        'codePays' => 'FI', 'codeDemarche' => 'T1',
      )
      expect(response.parsed_body.text).to include('Requesting the document')
    end
  end

  # CA10: taking a card off touches no exchange, and the card comes back as its
  # register says.
  describe 'DELETE /admin/demo/v2.0/T1/cartes/:exigence' do
    before do
      stub_oots_france_public_keys
      stub_evidence_request
      get documents_path
      post cartes_path, params: { exigence: ajoutee }
      patch pays_path(ajoutee), params: { pays: 'FI' }
      get documents_path
    end

    it 'takes the card off, leaving its request and asking the contract nothing' do
      stub_exchange_state(statut: 'pending')
      post admin_demo_demande_path(exigence: ajoutee, version: 'v2.0', procedure:)
      demands = contract_demands.size

      delete carte_path(ajoutee)

      expect(response).to redirect_to(documents_path)
      get documents_path
      expect(response.parsed_body.css("main #exigence-#{ajoutee}")).to be_empty
      expect(Demo::Request.where(requirement_uuid: ajoutee).count).to eq(1)
      expect(contract_demands.size).to eq(demands)
    end

    it 'brings it back in the country of its request, waiting, when added again' do
      stub_exchange_state(statut: 'pending')
      post admin_demo_demande_path(exigence: ajoutee, version: 'v2.0', procedure:)
      delete carte_path(ajoutee)

      post cartes_path, params: { exigence: ajoutee }
      get documents_path

      carte = response.parsed_body.at_css("main #exigence-#{ajoutee}")
      expect(carte.at_css('.fr-card__desc .country-tag').text.squish).to include('Finland')
      expect(carte.css('select')).to be_empty
      expect(carte.text).to include('Requesting the document')
    end

    it 'brings a refused one back in its country, offering to ask again and the list' do
      stub_exchange_state(statut: 'failed')
      post admin_demo_demande_path(exigence: ajoutee, version: 'v2.0', procedure:)
      delete carte_path(ajoutee)

      post cartes_path, params: { exigence: ajoutee }
      get documents_path

      carte = response.parsed_body.at_css("main #exigence-#{ajoutee}")
      expect(carte.at_css('select option[selected]')['value']).to eq('FI')
      expect(carte.at_css('.demo-request button').text.squish).to eq('Retry to request')
    end

    it 'leaves the cards of the procedure where they are' do
      delete carte_path(premiere)

      get documents_path
      expect(response.parsed_body.css("main #exigence-#{premiere}")).to be_present
    end
  end

  # CA5: a new identification opens a journey without the added cards, under
  # the procedure of the page it left from.
  it 'opens the next journey without them, under the procedure it departs from' do
    get documents_path
    post cartes_path, params: { exigence: ajoutee }

    identify_demo_user(procedure: 'R1')

    expect(response).to redirect_to(admin_demo_documents_path(version: 'v2.0', procedure: 'R1'))
    expect(Demo::Card.where(requirement_uuid: ajoutee)).to be_empty
  end

  def documents_path(**) = admin_demo_documents_path(version: 'v2.0', procedure:, **)

  def cartes_path = admin_demo_cartes_path(version: 'v2.0', procedure:)

  def carte_path(uuid) = admin_demo_carte_path(exigence: uuid, version: 'v2.0', procedure:)

  def pays_path(uuid) = admin_demo_pays_path(exigence: uuid, version: 'v2.0', procedure:)

  def added_label = response.parsed_body.at_css("main label[for='exigence-a-ajouter']")

  def options = response.parsed_body.css('main select#exigence-a-ajouter option')

  def journey_id = Demo::Journey.from_session(session[:demo_journey]).id

  def eb_asked(query, country, uuid)
    a_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search").with(query: hash_including(
      'queryId' => a_string_including(query), 'country-code' => country, 'requirement-id' => requirement_uri(uuid),
    ))
  end

  # The first query of the Evidence Broker under one procedure, told apart from
  # the catalogue, which asks it with no procedure at all.
  def stub_procedure_requirements(code, fixture)
    body, headers = common_services_answer(fixture)

    stub_request(:get, "#{DirectoryStubs::ACCEPTANCE}/eb/rest/search")
      .with(query: hash_including('queryId' => a_string_including('requirements-by-procedure'), 'procedure-id' => code))
      .to_return(body:, headers:)
  end
end
