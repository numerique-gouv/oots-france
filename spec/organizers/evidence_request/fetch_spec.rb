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

  # A line the caller asked for has to reach the message itself, and not the
  # exchange alone: the slot of the body and the header both say it.
  describe 'a line the caller asks for' do
    let(:access_point) { build(:access_point, :foreign, conforms_to: ['oots-edm:v1.2', 'oots-edm:v2.0']) }
    let(:arguments) { super().merge(requested_specification:) }

    context 'when it is 1.2 and the access point announces both' do
      let(:requested_specification) { EdmSpecification::V1_2 }

      it 'submits a 1.2 request, with the two properties of its header' do
        expect(fetch).to be_success
        expect(fetch.exchange.specification).to eq(EdmSpecification::V1_2)

        expect(submitted_properties).to contain_exactly('originalSender', 'finalRecipient')
        expect(submitted_body).to include('oots-edm:v1.2')
      end
    end

    context 'when it is 2.0' do
      let(:requested_specification) { EdmSpecification::V2_0 }

      it 'submits a 2.0 request' do
        expect(fetch.exchange.specification).to eq(EdmSpecification::V2_0)
        expect(submitted_properties).to include('SpecificationId')
      end
    end

    context 'when the access point does not announce it' do
      let(:access_point) { build(:access_point, :foreign) }
      let(:requested_specification) { EdmSpecification::V1_2 }

      it 'opens the exchange, settles it as failed, and submits nothing' do
        expect(fetch).to be_failure
        expect(fetch.error).to include(key: :unannounced_specification)

        expect(fetch.exchange.status).to eq('failed')
        expect(gateway).not_to have_received(:submit)
      end
    end

    def submitted
      expect(gateway).to have_received(:submit) { |envelope| return Nokogiri::XML(envelope) }
    end

    def submitted_properties = submitted.xpath('//*[local-name()="MessageProperties"]/*[local-name()="Property"]/@name').map(&:value)

    def submitted_body = Base64.decode64(submitted.at_xpath('//*[local-name()="payload"]/*[local-name()="value"]').text)
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

  # CA12 and CA13 of OOTS-253: a requirement asked for outside its procedure is
  # resolved by the second query of the Evidence Broker alone, and the request
  # goes out under the procedure named, carrying that requirement as the broker
  # names it, its first type in the country asked and the service the Data
  # Service Directory names for that type.
  describe 'a requirement asked for outside its procedure' do
    let(:requirement_id) { 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000' }
    let(:arguments) do
      super().merge(procedure_code: ProcedureCode::STUDY_FINANCING, country_code: 'FI', requirement_id:,
        outside_procedure: true, common_services: Directories::CommonServices.new)
    end

    before do
      stub_directory_resolution
      stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi', country: 'FI')
      stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
    end

    it 'submits under the procedure named, the requirement and its type read from the second query alone' do
      expect(fetch).to be_success

      expect(fetch.exchange.procedure_code).to eq('T1')
      expect(fetch.requirement).to have_attributes(id: requirement_id,
        descriptions: include('EN' => '(TEST) Test Requirement'))
      expect(fetch.evidence_type.id)
        .to eq('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e-7cdc-4146-9ff9-e331514ffb74')
      expect(fetch.data_service).to be_present
      expect(gateway).to have_received(:submit)
      expect(a_request(:get, %r{/eb/rest/search})
        .with(query: hash_including('queryId' => a_string_including('requirements-by-procedure'))))
        .not_to have_been_made
    end
  end
end
