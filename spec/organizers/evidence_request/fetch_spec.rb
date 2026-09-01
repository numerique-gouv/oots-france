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
      evidence_types_for_procedure: Directories::CommonServices::RequiredEvidence.new(
        requirement: build(:requirement), evidence_types: [build(:evidence_type)],
      ),
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
end
