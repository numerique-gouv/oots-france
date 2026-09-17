require 'rails_helper'

RSpec.describe FranceConnectRefusal do
  subject(:reason) { described_class.new(error, url).reason }

  let(:url) { "#{FranceConnectStubs::ISSUER}/token" }
  let(:error) { Faraday::BadRequestError.new(nil, { status: 400, headers: {}, body: }) }

  # What the sandbox answered on 2026-09-17: the three fields are the first thing
  # the support of FranceConnect asks for, and the client's own message carries
  # none of them.
  describe 'a refusal FranceConnect+ motivates' do
    let(:body) do
      { error: 'invalid_client_metadata',
        error_description: 'client JSON Web Key Set failed to be refreshed (fetch failed)',
        error_uri: 'https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-erreurs/' \
                   '?code=Y044D511&id=4074082d-7095-4067-99d7-ebb795041b72' }.to_json
    end

    it 'says the status, the address and the three fields as they were received' do
      expect(reason).to include('400', url, 'invalid_client_metadata',
        'client JSON Web Key Set failed to be refreshed (fetch failed)',
        'Y044D511', '4074082d-7095-4067-99d7-ebb795041b72')
    end

    # The address is the last thing the sentence carries, and it is a
    # correspondent's: nothing is appended behind it, a full stop included.
    it 'ends on the address it was given, with nothing added behind it' do
      expect(reason).to end_with('id=4074082d-7095-4067-99d7-ebb795041b72')
    end
  end

  # A translated fragment is never concatenated, so an absent field means another
  # sentence rather than a label with nothing after it.
  describe 'the fields RFC 6749 §5.2 makes optional' do
    context 'when only the error is named' do
      let(:body) { { error: 'invalid_grant' }.to_json }

      it 'names it, and leaves no empty label behind' do
        expect(reason).to include('400', 'invalid_grant')
        expect(reason).not_to include('—', 'voir')
      end
    end

    context 'when the error is described but documented nowhere' do
      let(:body) { { error: 'invalid_grant', error_description: 'code expiré' }.to_json }

      it 'says the description, and offers no address to see' do
        expect(reason).to include('invalid_grant', 'code expiré')
        expect(reason).not_to include('voir')
      end
    end

    context 'when the error is documented but not described' do
      let(:body) { { error: 'invalid_grant', error_uri: 'https://docs.invalid/Y044' }.to_json }

      it 'offers the address, and describes nothing' do
        expect(reason).to include('invalid_grant', 'voir', 'https://docs.invalid/Y044')
      end
    end

    context 'when a field is present but empty' do
      let(:body) { { error: 'invalid_grant', error_description: '', error_uri: '' }.to_json }

      it 'treats it as absent rather than showing a label with nothing after it' do
        expect(reason).to include('invalid_grant')
        expect(reason).not_to include('—', 'voir')
      end
    end

    # Each field is judged on its own: one that is empty must not cost the
    # sentence the other one earned, nor leave its own label standing empty.
    context 'when the description is empty and the address is not' do
      let(:body) do
        { error: 'invalid_grant', error_description: '', error_uri: 'https://docs.invalid/Y044' }.to_json
      end

      it 'offers the address, and opens no place for the description' do
        expect(reason).to include('voir', 'https://docs.invalid/Y044')
        expect(reason.count('—')).to eq(1)
      end
    end

    context 'when the address is empty and the description is not' do
      let(:body) { { error: 'invalid_grant', error_description: 'code expiré', error_uri: '' }.to_json }

      it 'describes the refusal, and offers no address to see' do
        expect(reason).to include('code expiré')
        expect(reason).not_to include('voir')
      end
    end

    # One method judges the three, so what is not a string is dropped wherever it
    # sits, and never shown as itself nor as its class.
    context 'when an optional field is not a string' do
      let(:body) { { error: 'invalid_grant', error_description: 42, error_uri: %w[une adresse] }.to_json }

      it 'drops it as it drops an absent one' do
        expect(reason).to include('invalid_grant')
        expect(reason).not_to include('—', 'voir', '42', 'adresse')
      end
    end
  end

  # Nothing below is a refusal this can read, and the caller then relays the
  # raising of the HTTP client, which names the status and the address.
  describe 'what motivates nothing' do
    context 'when the body is not JSON at all' do
      let(:body) { '<html><body>502 Bad Gateway</body></html>' }

      it { is_expected.to be_nil }
    end

    context 'when the body reads as JSON but is not an object' do
      let(:body) { '["invalid_grant"]' }

      it { is_expected.to be_nil }
    end

    context 'when the object names no error' do
      let(:body) { { message: 'quelque chose a échoué' }.to_json }

      it { is_expected.to be_nil }
    end

    context 'when the error is empty' do
      let(:body) { { error: '' }.to_json }

      it { is_expected.to be_nil }
    end

    # RFC 6749 §5.2 makes it a string; anything else is shown neither as itself
    # nor as its class.
    context 'when the error is not a string' do
      let(:body) { { error: 400 }.to_json }

      it { is_expected.to be_nil }
    end

    context 'when nothing answered at all' do
      let(:error) { Faraday::ConnectionFailed.new('Failed to open TCP connection') }

      it { is_expected.to be_nil }
    end
  end
end
