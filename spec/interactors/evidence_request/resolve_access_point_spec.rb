require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveAccessPoint do
  subject(:resolve) { described_class.call(provider:, gateway:) }

  let(:provider) { build(:evidence_provider, access_point: build(:access_point, id: 'AP_DE_01')) }
  let(:recipient) { build(:access_point, id: 'blue_gw') }
  let(:gateway) { instance_double(DomibusClient, find_access_point: recipient) }

  # The message is addressed to the party the PMode declares, which is not the
  # identifier the directory carries: the directory names the access point, the
  # PMode says under which party identifier the gateway knows it.
  it 'addresses the message to the party the PMode declares' do
    expect(resolve.recipient).to eq(recipient)
    expect(gateway).to have_received(:find_access_point).with('AP_DE_01')
  end

  describe 'an access point the PMode does not declare' do
    before do
      allow(gateway).to receive(:find_access_point).and_raise(RecipientNotFound, "Point d'accès inexistant : AP_DE_01.")
    end

    it 'fails, naming the access point' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_recipient)
      expect(resolve.error[:errors].first).to include('AP_DE_01')
    end
  end

  # The same outage one step later is reported as a 502. Reported as an
  # unhandled 500 here, the status handed to the caller would depend on which
  # step happened to hit the gateway first.
  describe 'a gateway that does not answer' do
    it 'fails as a gateway refusal when the connection breaks' do
      allow(gateway).to receive(:find_access_point).and_raise(Faraday::ConnectionFailed, 'connexion refusée')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :gateway_refused, errors: ['connexion refusée'])
    end

    # A gateway answering 200 with something that is not JSON is the same
    # problem, and must not escape as a 500 blamed on nobody.
    it 'fails as a gateway refusal when the answer is not JSON' do
      allow(gateway).to receive(:find_access_point).and_raise(JSON::ParserError, 'unexpected token')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :gateway_refused)
    end
  end
end
