require 'rails_helper'

# The outbound side: France asks another member state. What the token itself is
# worth is judged in `spec/clients/beneficiary_token_spec.rb`; what is judged
# here is the step — whose key set it opens the token with, and what it does
# with a refusal.
RSpec.describe EvidenceRequest::DecryptBeneficiary do
  subject(:decrypt) { described_class.call(requester:, encrypted_beneficiary: 'un-jeton-chiffré') }

  let(:requester) { build(:evidence_requester) }
  let(:beneficiary) { build(:natural_person) }
  let(:opener) { instance_double(BeneficiaryToken, beneficiary:) }

  before { allow(BeneficiaryToken).to receive(:new).with(requester).and_return(opener) }

  # The token is signed by the requester, so the requester is what says which
  # published keys may authenticate it. Opening it on behalf of anyone else
  # would check the signature against the wrong key set.
  it 'opens the token on behalf of the requester that sent it' do
    decrypt

    expect(BeneficiaryToken).to have_received(:new).with(requester)
    expect(opener).to have_received(:beneficiary).with('un-jeton-chiffré')
  end

  it 'names the beneficiary the rest of the exchange is about' do
    expect(decrypt.beneficiary).to eq(beneficiary)
  end

  # A token we cannot open is the caller's fault and nobody else's: it has to
  # come back as a structured failure the controller turns into a 422, not as
  # an exception that would read as a fault of ours.
  describe 'a token it cannot open' do
    before do
      allow(opener).to receive(:beneficiary).and_raise(InvalidTokenError, 'Jeton bénéficiaire invalide')
    end

    it 'fails the exchange rather than raising' do
      expect(decrypt).to be_failure
      expect(decrypt.error).to include(key: :invalid_token, errors: ['Jeton bénéficiaire invalide'])
    end
  end
end
