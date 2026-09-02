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
    types = directory.required_evidence_for_procedure('00', 'FR').flat_map(&:evidence_types)

    expect(types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'])
  end

  # The procedure is ours, the evidence types are the asked country's: swapping
  # the two is the wiring mistake the doubles cannot see.
  it 'lit les exigences chez nous et les types dans le pays interrogé' do
    directory.required_evidence_for_procedure('00', 'FI')

    expect(a_request(:get, "#{base}/eb/rest/search")
      .with(query: hash_including('procedure-id' => '00', 'country-code' => 'FR'))).to have_been_made
    expect(a_request(:get, "#{base}/eb/rest/search")
      .with(query: hash_including('requirement-id' => requirement, 'country-code' => 'FI'))).to have_been_made
  end

  it 'résout le fournisseur et son point d\'accès par le Data Service Directory' do
    provider = directory
      .data_service('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/x', 'FI')
      .providers.first

    expect(provider.ebms_identity.id).to eq('FIKEHA02')
    expect(provider.access_point.id).to eq('AP_FI_03')
  end

  it 'restreint la recherche de fournisseur à la version que nous produisons' do
    directory.data_service('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/x', 'FI')

    expect(a_request(:get, "#{base}/dsd/rest/search")
      .with(query: hash_including('specification' => EdmSpecification::IDENTIFIER))).to have_been_made
  end

  # The counterpart of the provider test above, on the requirement: nothing else
  # runs what the acceptance Evidence Broker actually publishes through
  # `R-EDM-REQ-C008`, so a drift in the identifiers it serves would surface only
  # on the wire.
  it 'accepte l\'exigence que l\'Evidence Broker publie réellement' do
    resolved = EvidenceRequest::ResolveEvidenceType.call(
      procedure_code: '00', country_code: 'FR', common_services: directory,
    )

    expect(resolved).to be_success
    expect(resolved.requirement.id).to eq(requirement)
  end

  # The case the doubles above cannot reach, on the answers the acceptance
  # Evidence Broker really gives: procedure `00` rests on two requirements for
  # France, and only one of them still publishes a French evidence type — the
  # other refuses with `EB:ERR:0001`. Nothing else in the suite runs two
  # requirements through the real client, the real parser and the real
  # signature, so nothing else would catch the second query being asked twice
  # under the same `requirement-id`, or the refusal of one sinking the other.
  # `docs/test_e2e.md` describes this same pair against the live directory.
  describe 'une démarche qui repose sur deux exigences' do
    let(:publiante) { 'https://sr.acc.oots.tech.ec.europa.eu/requirements/ffffffff-ffff-ffff-ffff-ffffffffffff' }
    let(:muette) { requirement }

    before do
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_deux_fr')
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_deux_fr', requirement: publiante)
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides', requirement: muette)
    end

    it 'interroge chaque exigence sous son propre identifiant' do
      directory.required_evidence_for_procedure('00', 'FR')

      [publiante, muette].each do |asked|
        expect(a_request(:get, "#{base}/eb/rest/search")
          .with(query: hash_including('requirement-id' => asked, 'country-code' => 'FR'))).to have_been_made
      end
    end

    it 'garde les deux exigences, celle qui ne publie rien comprise' do
      resolved = directory.required_evidence_for_procedure('00', 'FR')

      expect(resolved.map { |required| required.requirement.id }).to eq([publiante, muette])
      expect(resolved.map(&:published?)).to eq([true, false])
    end

    # C'est ce que le bout-en-bout éprouve contre l'annuaire vivant, et que rien
    # ne prouvait ici : le refus de l'exigence muette est écarté. Que l'ordre
    # des deux cesse de décider de l'issue se prouve ailleurs, l'annuaire
    # rendant aujourd'hui la publiante en tête — c'est
    # `resolve_evidence_type_spec.rb` qui met la muette en première position.
    it 'écarte le refus de l\'exigence muette et résout sur celle qui publie' do
      resolved = EvidenceRequest::ResolveEvidenceType.call(
        procedure_code: '00', country_code: 'FR', common_services: directory,
      )

      expect(resolved).to be_success
      expect(resolved.requirement.id).to eq(publiante)
      expect(resolved.evidence_type.id)
        .to eq('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4')
    end

    # L'inverse du précédent : sans personne pour le compenser, le refus est la
    # réponse, et il reste un refus d'annuaire plutôt qu'un pays sans type.
    it 'relève le refus quand aucune des deux exigences ne publie' do
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides', requirement: publiante)

      expect { directory.required_evidence_for_procedure('00', 'FR') }
        .to raise_error(EvidenceTypeNotFound, /FR/)
    end
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
        gateway:, exchange: create(:exchange), recipient: resolved.recipient,
        provider: resolved.provider, data_service: resolved.data_service,
        requester: build(:evidence_requester), beneficiary: build(:natural_person),
        evidence_type: build(:evidence_type), requirement: build(:requirement),
        procedure_code: ProcedureCode::DIPLOMA_RECOGNITION, preview_possible: false,
        uuid: Oots::SequentialUuids.new, audit_trail: AuditTrail.new,
      )

      Nokogiri::XML(gateway_envelope)
    end

    let(:gateway) { gateway_accepting_submissions }

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
  # rather than letting a `CommonServicesError` reach the caller unchanged. The
  # code the directory named has to survive that translation inside the message
  # itself; the spec below says where it ends up, and why nothing else carries
  # it.
  it 'traduit le refus de l\'annuaire en l\'exception que les interacteurs attendent' do
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    expect { directory.data_service('https://sr.acc.oots.tech.ec.europa.eu/x', 'FR') }
      .to raise_error(CountryCodeNotFound, /FR.*DSD:ERR:0001/m)
  end

  # One hop further, on the same real refusal: the code the directory named has
  # to survive into the reason an interactor hands on, that reason being the
  # only carrier there is. `EvidenceRequestsController#report_failure` joins it
  # into the `erreur` of the JSON answer and into the `detail:` of the
  # `request_refused` journal line, neither of which has a field of its own for
  # a code. Every spec downstream of here types that reason by hand, so this is
  # the last point where a real answer still proves it.
  it 'garde le code du refus dans le motif que l\'interacteur transmet' do
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    resolved = EvidenceRequest::ResolveProvider.call(
      common_services: directory, evidence_type: build(:evidence_type), country_code: 'FR',
    )

    expect(resolved).to be_failure
    expect(resolved.error[:key]).to eq(:unknown_country)
    expect(resolved.error[:errors].join).to include('DSD:ERR:0001')
  end
end
