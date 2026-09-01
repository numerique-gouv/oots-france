require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveEvidenceType do
  subject(:resolve) do
    described_class.call(procedure_code: ProcedureCode::DIPLOMA_RECOGNITION, country_code: 'FI', common_services:)
  end

  let(:common_services) do
    instance_double(Directories::CommonServices, required_evidence_for_procedure: required)
  end
  let(:required) { [Directories::CommonServices::RequiredEvidence.new(requirement:, evidence_types: types)] }
  let(:requirement) { build(:requirement) }
  let(:types) { [build(:evidence_type, id: 'https://sr/premier'), build(:evidence_type, id: 'https://sr/second')] }

  # Letting the user choose among several is chapter 4.10: until then the first
  # is asked for, and which one that is has to be the directory's order rather
  # than an accident.
  it 'keeps the first type the procedure calls for' do
    expect(resolve.evidence_type.id).to eq('https://sr/premier')
  end

  # A request writes it into its `Requirements` slot, and the Evidence Broker
  # answers it in the same breath as the types.
  it 'keeps the requirement the procedure rests on' do
    expect(resolve.requirement).to eq(requirement)
  end

  # Told apart from an outage, which the same `CommonServicesError` family
  # carries: a directory that publishes an entry the rules refuse will publish
  # it again at the next attempt, where a timeout will not.
  it 'reports an entry the directory published against the rules under its own key' do
    allow(common_services).to receive(:required_evidence_for_procedure)
      .and_raise(InvalidDirectoryEntry, "L'exigence annoncée par l'annuaire : …")

    expect(resolve).to be_failure
    expect(resolve.error).to include(key: :invalid_directory_entry)
  end

  # A country declaring it issues nothing for one requirement says nothing about
  # its neighbours, and must not stand in their way.
  describe 'a requirement the country answers with nothing' do
    let(:required) do
      [Directories::CommonServices::RequiredEvidence.new(requirement: build(:requirement), evidence_types: []),
       Directories::CommonServices::RequiredEvidence.new(requirement:, evidence_types: types)]
    end

    it 'carries the exchange on the first requirement that published types' do
      expect(resolve.evidence_type.id).to eq('https://sr/premier')
      expect(resolve.requirement).to eq(requirement)
    end

    # Every requirement of the procedure is due (chapter 3.2.3), so the whole
    # answer stays available to what comes after — the one that published
    # nothing included, since chapter 4.4 multiplies the conversation timeout by
    # how many there are. How many requests it turns into is OOTS-139.
    it 'keeps every requirement the procedure rests on, not merely the one it sends' do
      expect(resolve.required_evidence).to eq(required)
    end
  end

  it 'asks for the types of the country being queried' do
    resolve

    expect(common_services).to have_received(:required_evidence_for_procedure)
      .with(ProcedureCode::DIPLOMA_RECOGNITION, 'FI')
  end

  # Reported as a failure of its own rather than left to surface as a nil three
  # steps later, when the message is built.
  describe 'a procedure that calls for nothing' do
    let(:types) { [] }

    it 'fails, naming the procedure' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :no_evidence_type, errors: [ProcedureCode::DIPLOMA_RECOGNITION])
    end
  end

  describe 'a procedure the broker does not declare' do
    it 'fails, rather than raising at the caller' do
      allow(common_services).to receive(:required_evidence_for_procedure)
        .and_raise(ProcedureCodeNotFound, "Code de démarche « #{ProcedureCode::DIPLOMA_RECOGNITION} » introuvable.")

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_procedure)
      expect(resolve.error[:errors].first).to include(ProcedureCode::DIPLOMA_RECOGNITION)
    end
  end

  # Chapter 3.2.4 separates two answers a caller must not receive as one, and it
  # is the parser that tells them apart — which is why this reads the real chain
  # from the bytes of an answer: the doubles above it cannot see that step. A
  # `NoMatch` is a success and must arrive as « Aucun type de justificatif dans
  # ce pays », where `EB:ERR:0001` is a refusal and stays one.
  #
  # The signature is doubled, and only it: the `NoMatch` body is fabricated from
  # a capture, so the digest the Commission signed does not cover it.
  describe 'the two ways a country can hold nothing' do
    subject(:resolved) do
      described_class.call(procedure_code: '00', country_code: 'FR', common_services: Directories::CommonServices.new)
    end

    before do
      stub_directory_resolution
      stub_directory_signature
      stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    end

    it 'reports an explicit NoMatch as this country having no evidence type' do
      stub_directory_body('eb', 'evidence-types-by-requirement', evidence_types_declaring_no_match)

      expect(resolved).to be_failure
      expect(resolved.error).to include(key: :no_evidence_type, errors: ['00'])
    end

    it 'keeps a refusal by EB:ERR:0001 a refusal' do
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_requirements_vides')

      expect(resolved).to be_failure
      expect(resolved.error).to include(key: :unknown_procedure)
    end
  end

  # A directory that is down is not the caller's fault: the controller answers
  # 502 on this key, where every other failure of this step is a 422.
  describe 'a directory that cannot be reached' do
    it 'fails as an upstream refusal' do
      allow(common_services).to receive(:required_evidence_for_procedure)
        .and_raise(CommonServicesError, 'Annuaire injoignable.')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :common_services_refused)
    end
  end
end
