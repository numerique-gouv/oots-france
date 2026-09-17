require 'rails_helper'

# The whole chain, run for one question the steps cannot answer separately:
# whether the version check really stands between the exchange being opened and
# the message being submitted.
RSpec.describe EvidenceRequest::Fetch do
  subject(:fetch) { described_class.call(**arguments) }

  let(:gateway) { gateway_accepting_submissions }
  let(:access_point) { build(:access_point, :foreign) }

  let(:common_services) do
    instance_double(Directories::CommonServices,
      required_evidence_for_procedure: [Directories::CommonServices::RequiredEvidence.new(
        requirement: build(:requirement), evidence_types: [build(:evidence_type)],
      )],
      data_service: build(:data_service, providers: [build(:evidence_provider, access_point:)]))
  end

  let(:arguments) do
    {
      requester_id: '00000000000002',
      conversation_id: nil,
      requesters: instance_double(Directories::EvidenceRequesters, find: build(:evidence_requester)),
      encrypted_beneficiary: 'un-jeton-chiffré',
      procedure_code: ProcedureCode::SYSTEM_CHECK,
      country_code: 'DE',
      preview_possible: false,
      common_services:,
      gateway:,
      uuid: Oots::SequentialUuids.new,
      audit_trail: AuditTrail.new,
    }
  end

  before do
    allow(BeneficiaryToken).to receive(:new)
      .and_return(instance_double(BeneficiaryToken, beneficiary: build(:natural_person)))
  end

  context 'when the access point the directory named announces the version the request carries' do
    it 'submits' do
      expect(fetch).to be_success
      expect(gateway).to have_received(:submit)
    end
  end

  context 'when it announces another one' do
    let(:access_point) { build(:access_point, :foreign, :outdated) }

    # The point of the step: the exchange exists, so the refusal is read back on
    # its record, and nothing was handed to the gateway — a message declaring a
    # version the far end does not process is one chapter 4.7 has it reject.
    it 'opens the exchange, settles it as failed, and submits nothing' do
      expect(fetch).to be_failure
      expect(fetch.error).to include(key: :unsupported_specification)

      expect(fetch.exchange.status).to eq('failed')
      expect(gateway).not_to have_received(:submit)
    end
  end

  # Proven here and not only on the step: driven through `ResolveProvider`
  # rather than handed a recipient, a silent access point must still reach the
  # gateway. It is the one branch whose regression would be a refusal nobody
  # asked for.
  context 'when it announces no version at all' do
    let(:access_point) { build(:access_point, :foreign, conforms_to: []) }

    it 'submits, exactly as a version-announcing correspondent would' do
      expect(fetch).to be_success
      expect(gateway).to have_received(:submit)
    end
  end

  # The other question the steps cannot answer separately: what a requirement
  # named in `idExigence` costs when the country serves it with nothing. The
  # refusal has to come before the exchange is opened, so that a caller correcting
  # its parameter is not made to read back an exchange that never left.
  describe 'a procedure resting on two requirements' do
    let(:common_services) do
      instance_double(Directories::CommonServices,
        required_evidence_for_procedure: [
          Directories::CommonServices::RequiredEvidence.new(requirement: first, evidence_types: first_types),
          Directories::CommonServices::RequiredEvidence.new(requirement: second, evidence_types: second_types),
        ],
        data_service: data_service)
    end
    let(:first) { build(:requirement, id: 'https://sr.oots.tech.ec.europa.eu/requirements/1') }
    let(:second) { build(:requirement, id: 'https://sr.oots.tech.ec.europa.eu/requirements/2') }
    let(:first_types) { [build(:evidence_type, id: 'https://sr/du-premier')] }
    let(:second_types) { [build(:evidence_type, id: 'https://sr/du-second')] }
    let(:data_service) { build(:data_service, providers: [build(:evidence_provider, access_point:)]) }

    # Chapter 4.5.1 §3.1 lets several `sdg:Requirement` travel in one request
    # only where a single evidence type proves them all, so one request carries
    # one requirement and `idExigence` says which.
    context 'when the caller names the second' do
      let(:arguments) { super().merge(requirement_id: second.id) }

      it 'declares that requirement alone, and the type published for it' do
        expect(fetch).to be_success
        expect(fetch.requirement).to eq(second)
        expect(fetch.evidence_type.id).to eq('https://sr/du-second')
        expect(gateway).to have_received(:submit)
      end
    end

    context 'when the caller names one the country publishes nothing for' do
      let(:arguments) { super().merge(requirement_id: second.id) }
      let(:second_types) { [] }

      it 'refuses without opening an exchange or falling back on the first' do
        expect(fetch).to be_failure
        expect(fetch.error).to include(key: :no_evidence_type)

        expect(fetch.exchange).to be_nil
        expect(Exchange.count).to eq(0)
        expect(gateway).not_to have_received(:submit)
      end
    end

    context 'when the caller names one the procedure does not rest on' do
      let(:arguments) { super().merge(requirement_id: 'https://sr.oots.tech.ec.europa.eu/requirements/3') }

      it 'refuses under its own key, opening nothing and submitting nothing' do
        expect(fetch).to be_failure
        expect(fetch.error).to include(key: :unknown_requirement)

        expect(Exchange.count).to eq(0)
        expect(gateway).not_to have_received(:submit)
      end
    end

    # The Data Service Directory is asked after the evidence type is settled, so
    # a requirement published by one directory and served by neither is refused
    # a step later — and still before anything is opened.
    context 'when no provider serves the type the named requirement publishes' do
      let(:arguments) { super().merge(requirement_id: second.id) }
      let(:data_service) { build(:data_service, providers: []) }

      it 'refuses, opening nothing and submitting nothing' do
        expect(fetch).to be_failure
        expect(fetch.error).to include(key: :no_provider)

        expect(Exchange.count).to eq(0)
        expect(gateway).not_to have_received(:submit)
      end
    end
  end
end
