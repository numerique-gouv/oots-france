require 'rails_helper'

RSpec.describe Demo::CompleteIdentification do
  subject(:result) { described_class.call(code: 'un-code', state: 'l-etat-de-depart', expected:) }

  let(:expected) { { state: 'l-etat-de-depart', nonce: 'le-nonce-de-depart' } }

  before do
    stub_france_connect
    stub_france_connect_tokens(france_connect_id_token_claims)
  end

  it 'gives back the identity the authentication attested' do
    expect(result).to be_a_success
    expect(result.identity).to have_attributes(family_name: 'Sørensen', given_name: 'Freja Marie',
      birthdate: '2001-04-17', level_of_assurance: 'Substantial')
  end

  it 'holds the signed ID Token, which is what ends the session on the portal' do
    expect(result.identity.id_token.split('.').size).to eq(3)
  end

  # CA9: the level shown is the one reached, never the one asked for.
  it 'reads the high level when that is what the authentication reached' do
    stub_france_connect_tokens(france_connect_id_token_claims(acr: 'eidas3'))

    expect(result.identity.level_of_assurance).to eq('High')
  end

  # CA5: nothing carries an eIDAS identifier today, and nothing is fabricated.
  it 'holds an identity with no identifier, and never the pseudonym in its place' do
    expect(result.identity.eidas_identifier).to be_nil
    expect(result.identity.subject).to eq(FranceConnectStubs::DANISH_USERINFO.fetch('sub'))
  end

  # CA10: both are shown and both travel when received, and neither is invented.
  it 'carries the sex and the place of birth when the answer holds them' do
    expect(result.identity).to have_attributes(gender: 'female', place_of_birth: 'Aarhus')
  end

  it 'holds neither when the answer holds neither' do
    stub_france_connect_userinfo(FranceConnectStubs::DANISH_USERINFO.except('gender', 'birthplace'))

    expect(result.identity).to have_attributes(gender: nil, place_of_birth: nil)
  end

  describe 'what it refuses' do
    it 'refuses a return whose state is not the one this session departed on' do
      expect(described_class.call(code: 'un-code', state: 'un-autre-etat', expected:))
        .to be_a_failure
    end

    it 'refuses a return this session never asked for' do
      expect(described_class.call(code: 'un-code', state: 'l-etat-de-depart', expected: nil)).to be_a_failure
    end

    # CA12: a signature no published key verifies, on either document.
    it 'refuses an ID Token signed by a key FranceConnect+ does not publish' do
      foreign = OpenSSL::PKey::EC.generate('prime256v1')
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(
        body: { access_token: 'un-jeton', id_token:
          sealed_for_procedure(france_connect_id_token_claims, key: foreign) }.to_json,
      )

      expect(result).to be_a_failure
      expect(result.identity).to be_nil
    end

    it 'refuses a UserInfo response signed by a key FranceConnect+ does not publish' do
      foreign = OpenSSL::PKey::EC.generate('prime256v1')
      stub_request(:get, FranceConnectStubs::USERINFO_ENDPOINT)
        .to_return(body: sealed_for_procedure(FranceConnectStubs::DANISH_USERINFO, key: foreign))

      expect(result).to be_a_failure
    end

    it 'refuses an ID Token that answers another departure' do
      stub_france_connect_tokens(france_connect_id_token_claims(nonce: 'un-autre-nonce'))

      expect(result).to be_a_failure
      expect(result.error[:errors].join).to include('nonce')
    end

    it 'refuses an ID Token issued by someone else, or to someone else' do
      stub_france_connect_tokens(france_connect_id_token_claims(iss: 'https://ailleurs.invalid'))
      expect(result).to be_a_failure

      stub_france_connect_tokens(france_connect_id_token_claims(aud: 'une-autre-demarche'))
      expect(described_class.call(code: 'un-code', state: 'l-etat-de-depart', expected:)).to be_a_failure
    end

    # RG3: « le fournisseur de service doit vérifier que ce niveau égale ou
    # dépasse celui demandé ».
    it 'refuses a level below the one the departure asked for' do
      stub_france_connect_tokens(france_connect_id_token_claims(acr: 'eidas1'))

      expect(result).to be_a_failure
      expect(result.error[:errors].join).to include('eidas1', 'eidas2')
    end

    it 'refuses two documents that do not speak of the same person' do
      stub_france_connect_userinfo(FranceConnectStubs::DANISH_USERINFO.merge('sub' => 'quelqu-un-d-autre'))

      expect(result).to be_a_failure
      expect(result.error[:errors].join).to include('même personne')
    end

    # CA6: carried as it stands it would make the request be refused by
    # `R-EDM-REQ-C040`, and dropped in silence it would pass for « not
    # returned », which is a different thing.
    it 'refuses an identifier that is not of the shape the chapter gives, and says why' do
      stub_france_connect_userinfo(
        FranceConnectStubs::DANISH_USERINFO.merge(FranceConnectIdentity::PERSON_IDENTIFIER => 'DK-FR-61f6'),
      )

      expect(result).to be_a_failure
      expect(result.error[:errors].join).to include('PAYS/PAYS/IDENTIFIANT')
    end

    it 'relays the refusal FranceConnect+ redirected back with, rather than exchanging a code' do
      refused = described_class.call(state: 'l-etat-de-depart', expected:,
        announced_error: 'invalid_acr', error_description: 'acr_value is not valid')

      expect(refused).to be_a_failure
      expect(refused.error[:errors].join).to include('invalid_acr', 'acr_value is not valid')
      expect(a_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)).not_to have_been_made
    end

    # Ce que la démarche vérifie sur l'ID Token est l'issuer qu'on lui a
    # configuré, jamais celui que le document dit de lui-même.
    it 'refuses a discovery document announcing an issuer other than the configured one' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL)
        .to_return(body: discovery_document.merge(issuer: 'https://ailleurs.invalid').to_json)

      expect(result).to be_a_failure
      expect(result.identity).to be_nil
    end

    it 'refuses when the token endpoint declines the code' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
        .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

      expect(result).to be_a_failure
    end
  end
end
