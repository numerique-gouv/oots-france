require 'rails_helper'

RSpec.describe Demo::BeneficiaryTokenWriter do
  subject(:token) { described_class.new(clock:).call(identity) }

  # Now, and not a date written down: the token carries an `exp`, and
  # `BeneficiaryToken` verifies it against the wall clock. A fixed instant makes
  # these examples pass until that instant is ten minutes old and fail for ever
  # after, which is a failure nothing in the tree explains.
  let(:clock) { instance_double(Clock, now: Time.current.iso8601(3)) }
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

  # Les cinq formes qu'un jeu de clés publié peut prendre sans que rien soit
  # injoignable, avec le JSON exact que la route sert. Elles sont ce qui rend
  # vérifiable le commentaire de `read_key` : les quatre premières lèvent quatre
  # classes qu'aucune parenté commune ne rassemble, et resserrer le rattrapage
  # sur l'une d'elles fait rougir les autres.
  describe 'a key set nothing can be read from' do
    # Deux coordonnées de la bonne longueur, en base64 valide, qui ne désignent
    # aucun point de la courbe.
    def hors_courbe(octet) = Base64.urlsafe_encode64(octet * 32, padding: false)

    {
      'a body that is no JSON at all' => '<html>maintenance</html>',
      'a set published empty' => { keys: [] }.to_json,
      'a key whose kty is absent' => { keys: [{ crv: 'P-256', x: 'ab', y: 'cd' }] }.to_json,
      'a coordinate in broken base64' =>
        { keys: [{ kty: 'EC', crv: 'P-256', x: 'pas-du-base64-!!', y: 'def' }] }.to_json,
      'a coordinate that is not even text' =>
        { keys: [{ kty: 'EC', crv: 'P-256', x: 1, y: 2 }] }.to_json,
    }.each do |cas, corps|
      it "refuses to seal anything on #{cas}" do
        stub_published_key_set(corps)

        expect { token }.to raise_error(UnusableKeySetError, /cles_publiques/)
      end
    end

    it 'refuses to seal anything on a point that is not on the curve' do
      stub_published_key_set(
        { keys: [{ kty: 'EC', crv: 'P-256', x: hors_courbe("\x01"), y: hors_courbe("\x02") }] }.to_json,
      )

      expect { token }.to raise_error(UnusableKeySetError, /cles_publiques/)
    end

    # Injoignable et inexploitable sont deux choses distinctes à dire à
    # l'usager, et c'est l'appelant qui nomme la première.
    it 'lets an unreachable route travel on as itself' do
      stub_request(:get, "#{Settings.oots_france_url}/auth/cles_publiques").to_timeout

      expect { token }.to raise_error(Faraday::Error)
    end

    def stub_published_key_set(corps)
      stub_request(:get, "#{Settings.oots_france_url}/auth/cles_publiques")
        .to_return(body: corps, headers: { 'Content-Type' => 'application/json' })
    end
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
