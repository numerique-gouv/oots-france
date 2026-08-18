require 'rails_helper'

# The one spec that builds the real object graph — no double anywhere below the
# HTTP boundary. Every other spec of this chain injects a collaborator, which is
# what makes each layer testable and, taken together, leaves the wiring itself
# unchecked: a swapped country between the two chained Evidence Broker calls, a
# wrong default class, an argument in the wrong order, all satisfy the doubles.
#
# The end-to-end scenarios would have caught it, and they are suspended until
# France is registered — see `docs/test_e2e.md`. This stands in their place for
# what can be checked without a gateway.
RSpec.describe 'Le câblage des annuaires centraux' do
  include OotsNamespaces

  subject(:directory) { Directories::CommonServices.new }

  let(:base) { DirectoryStubs::ACCEPTANCE }
  let(:requirement) { 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000' }

  before do
    stub_directory_resolution

    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fr')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  it 'enchaîne les deux requêtes de l\'Evidence Broker jusqu\'au type de justificatif' do
    types = directory.evidence_types_for_procedure('00', 'FR')

    expect(types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'])
  end

  # The procedure is ours, the evidence types are the asked country's: swapping
  # the two is the wiring mistake the doubles cannot see.
  it 'lit les exigences chez nous et les types dans le pays interrogé' do
    directory.evidence_types_for_procedure('00', 'FI')

    expect(a_request(:get, "#{base}/eb/rest/search")
      .with(query: hash_including('procedure-id' => '00', 'country-code' => 'FR'))).to have_been_made
    expect(a_request(:get, "#{base}/eb/rest/search")
      .with(query: hash_including('requirement-id' => requirement, 'country-code' => 'FI'))).to have_been_made
  end

  it 'résout le fournisseur et son point d\'accès par le Data Service Directory' do
    provider = directory.providers('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/x', 'FI').first

    expect(provider.ebms_identity.id).to eq('FIKEHA02')
    expect(provider.access_point.id).to eq('AP_FI_03')
  end

  it 'restreint la recherche de fournisseur à la version que nous produisons' do
    directory.providers('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/x', 'FI')

    expect(a_request(:get, "#{base}/dsd/rest/search")
      .with(query: hash_including('specification' => EdmSpecification::IDENTIFIER))).to have_been_made
  end

  # The last hop, and the one nothing else covers. Every spec downstream is
  # handed a `recipient` already built, so none of them can tell whether the
  # party the message is addressed to is the one the directory named — which is
  # precisely what stub 2 got wrong, reading it from the local PMode instead.
  # Asserting the scheme too: the identifier alone routes nowhere without it.
  describe "le point d'accès de l'annuaire jusqu'à l'en-tête ebMS" do
    subject(:submitted) do
      resolved = EvidenceRequest::ResolveProvider.call(
        evidence_type: build(:evidence_type), country_code: 'FI', common_services: directory,
      )

      EvidenceRequest::SendToGateway.call(
        gateway:, conversation: create(:conversation), recipient: resolved.recipient,
        provider: resolved.provider, requester: build(:evidence_requester),
        beneficiary: build(:natural_person), evidence_type: build(:evidence_type),
        procedure_code: ProcedureCode::STUDENT_GRANT, preview_possible: false,
        uuid: Oots::SequentialUuids.new,
      )

      Nokogiri::XML(gateway_envelope)
    end

    let(:gateway) { instance_double(DomibusClient, submit: nil) }

    it 'adresse le message à la partie que le Data Service Directory a nommée' do
      expect(text_at(submitted, '//eb:To/eb:PartyId')).to eq('AP_FI_03')
      expect(attribute(at(submitted, '//eb:To/eb:PartyId'), 'type'))
        .to eq('urn:oasis:names:tc:ebcore:partyid-type:unregistered:FI')
    end

    # The access point is C3, the provider C4: the DSD answers `AP_FI_03`
    # behind which `FIKEHA02` holds the evidence, and the message carries both
    # in their own place.
    it 'garde le fournisseur en destinataire final, distinct du point d\'accès' do
      expect(text_at(submitted, '//eb:Property[@name="finalRecipient"]')).to eq('FIKEHA02')
    end

    def gateway_envelope
      expect(gateway).to have_received(:submit) { |envelope| return envelope }
    end
  end

  # The chain reports a refusal as the named exception the interactors handle,
  # rather than letting a `CommonServicesError` reach the caller unchanged.
  it 'traduit le refus de l\'annuaire en l\'exception que les interacteurs attendent' do
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    expect { directory.providers('https://sr.acc.oots.tech.ec.europa.eu/x', 'FR') }
      .to raise_error(CountryCodeNotFound, /FR/)
  end
end
