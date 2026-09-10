require 'rails_helper'

RSpec.describe Demo::BeneficiaryTokenWriter do
  subject(:token) { described_class.new(clock:).call(identity) }

  let(:clock) { instance_double(Clock, now: '2026-09-10T10:00:00.000Z') }
  let(:identity) do
    Demo::UserIdentity.new(
      level_of_assurance: 'Substantial', family_name: 'Sørensen', given_name: 'Freja Marie',
      birthdate: '2001-04-17', gender: 'female', place_of_birth: 'Aarhus',
      subject: "#{'a' * 64}v1", id_token: 'un-id-token',
    )
  end

  before { stub_oots_france_public_keys }

  # CA4, second half. The two halves belong in one example: a key set published
  # and a token signed prove nothing apart — it is that OOTS-France opens *this*
  # token with *those* keys that the contract rests on.
  describe 'the token OOTS-France then opens' do
    subject(:beneficiary) { BeneficiaryToken.new(requester).beneficiary(token) }

    let(:requester) { EvidenceRequester.french(id: '00000000000003', name: 'Université', url: 'http://oots.test/demo') }

    before do
      allow(Settings).to receive(:private_key_jwk)
        .and_return(JWT::JWK.new(oots_france_key).export(include_private: true).transform_keys(&:to_s))

      stub_request(:get, 'http://oots.test/demo/auth/cles_publiques')
        .to_return(body: PublicKeySet.new(Settings.demo_signing_key_jwk, use: 'sig').to_h.to_json,
          headers: { 'Content-Type' => 'application/json' })
    end

    it 'is accepted, and names the person the authentication attested' do
      expect(beneficiary).to have_attributes(
        family_name: 'Sørensen', given_name: 'Freja Marie', date_of_birth: '2001-04-17',
        level_of_assurance: 'Substantial', place_of_birth: 'Aarhus',
      )
    end

    # `BeneficiaryToken` translates the portal's lower case into the capitalised
    # code of `Gender-CodeList`, so the token has to carry the portal's own.
    it 'writes the sex in the vocabulary the reader translates from' do
      expect(beneficiary.gender).to eq('Female')
    end
  end

  describe 'what it puts in the claims' do
    subject(:claims) { JWT.decode(signed, nil, false).first }

    let(:signed) { JWE.decrypt(token, oots_france_key) }

    it 'writes the four mandatory fields of the contract' do
      expect(claims).to include(
        'niveauGarantie' => 'Substantial', 'nomUsage' => 'Sørensen',
        'prenom' => 'Freja Marie', 'dateNaissance' => '2001-04-17',
      )
    end

    it 'writes the optional ones only when the authentication returned them' do
      expect(claims).to include('sexe' => 'female', 'lieuNaissance' => 'Aarhus')
    end

    it 'omits what the authentication did not return' do
      identity.gender = nil
      identity.place_of_birth = nil
      identity.eidas_identifier = nil

      expect(claims.keys).not_to include('sexe', 'lieuNaissance', 'identifiantEidas')
    end

    # The `sub` is a pseudonym of FranceConnect+'s own, per service provider: it
    # names nobody outside the portal, and `R-EDM-REQ-C040` would refuse its
    # shape as an eIDAS identifier.
    it 'never carries the pseudonym FranceConnect+ handed the procedure' do
      expect(claims.values.join).not_to include(identity.subject)
    end

    it 'expires, so that a token read off a log is worth nothing later' do
      expect(claims['exp']).to eq(Time.zone.parse(clock.now).to_i + described_class::VALIDITY.to_i)
    end
  end

  # Reading it is what makes the demonstration exercise the publishing route;
  # deriving it from `Settings.private_key_jwk` would sidestep that route, and
  # leave a broken one invisible.
  it 'encrypts for the key it reads from the publishing route' do
    token

    expect(a_request(:get, "#{Settings.oots_france_url}/auth/cles_publiques")).to have_been_made
  end

  it 'seals it with the algorithms the reader admits, and no others' do
    header = JSON.parse(JWE::Base64.jwe_decode(token.split('.').first))

    expect(header).to include(
      'alg' => BeneficiaryToken::KEY_MANAGEMENT, 'enc' => BeneficiaryToken::CONTENT_ENCRYPTION,
    )
  end

  it 'signs it with the one algorithm the reader admits' do
    signed = JWE.decrypt(token, oots_france_key)

    expect(JWT.decode(signed, nil, false).last['alg']).to eq('ES256')
  end
end
