require 'rails_helper'

RSpec.describe FranceConnectToken do
  subject(:opener) { described_class.new }

  let(:claims) { { 'sub' => 'un-pseudonyme', 'acr' => 'eidas2' } }

  before { stub_france_connect }

  describe '#signed' do
    it 'gives back the signed token the envelope holds' do
      expect(opener.signed(sealed_for_procedure(claims)).split('.').size).to eq(3)
    end

    # The envelope is addressed to us and to nobody else: another key of the
    # same type does not open it.
    it 'refuses what was encrypted for another key' do
      other = JWE.encrypt('charge', OpenSSL::PKey::RSA.generate(2048).public_key,
        alg: 'RSA-OAEP-256', enc: 'A256GCM')

      expect { opener.signed(other) }.to raise_error(FranceConnectError, /indéchiffrable/)
    end

    # Refused before decrypting, not after: the point is never to run an
    # algorithm we did not choose — and here the one we chose is the `alg` of the
    # key this deployment publishes, since it is that declaration FranceConnect+
    # encrypts under.
    it 'refuses a key management algorithm other than the one we publish' do
      sealed = sealed_for_procedure(claims, alg: 'RSA-OAEP')

      expect { opener.signed(sealed) }
        .to raise_error(FranceConnectError, %r{RSA-OAEP/A256GCM.*RSA-OAEP-256/A256GCM})
    end

    # The first segment of a JWE is its header, and a header is an object: `W10`
    # is `[]`, which would raise on the first lookup rather than be refused.
    it 'refuses a sealed token whose header is not an object' do
      expect { opener.signed("W10.#{'x.' * 3}y") }.to raise_error(FranceConnectError, /objet/)
    end

    it 'refuses anything that is not a sealed token at all' do
      expect { opener.signed('ceci.nest.pas.un.jwe') }.to raise_error(FranceConnectError)
    end
  end

  describe '#claims' do
    it 'gives back what the token carries once its signature checks out' do
      expect(opener.open(sealed_for_procedure(claims))).to include('sub' => 'un-pseudonyme')
    end

    # « The JWT Claims Set … is a JSON object » (RFC 7519 §4). The gem verifies
    # `exp`, `iss` and `aud` by indexing the payload before anything of ours sees
    # it, so this one crashes inside `JWT.decode` unless it is caught there.
    it 'refuses a claims set that is not an object' do
      sealed = encrypt_for_procedure(
        JWT.encode(%w[ni un ni objet], france_connect_signing_key, 'ES256',
          kid: JWT::JWK.new(france_connect_signing_key).export[:kid]),
      )

      expect { opener.open(sealed) }.to raise_error(FranceConnectError)
    end

    it 'refuses a signature no published key verifies' do
      foreign = sealed_for_procedure(claims, key: OpenSSL::PKey::EC.generate('prime256v1'))

      expect { opener.open(foreign) }.to raise_error(FranceConnectError, /Signature/)
    end

    it 'verifies what the caller names, and refuses what does not match' do
      expect { opener.open(sealed_for_procedure(claims.merge('iss' => 'ailleurs')), iss: 'ici', verify_iss: true) }
        .to raise_error(FranceConnectError, /Signature/)
    end

    # The key set is read inside `JWT.decode`, through the callback, and the JWT
    # gem lets what a loader raises travel out untranslated: a JWKS answered as
    # a maintenance page would otherwise be a `JSON::ParserError` reaching a
    # caller that has no reason to expect one.
    it 'refuses a key set that does not read as JSON' do
      stub_request(:get, FranceConnectStubs::JWKS_URL).to_return(body: '<html>maintenance</html>')

      expect { opener.open(sealed_for_procedure(claims)) }.to raise_error(FranceConnectError)
    end

    # FranceConnect+ renews its signing keys, and a reader holding a stale set
    # has to read it again rather than refuse a key it has simply not seen.
    it 'reads the key set again when the token names a key it does not hold' do
      rotated = OpenSSL::PKey::EC.generate('prime256v1')
      sealed = sealed_for_procedure(claims, key: rotated)
      stub_request(:get, FranceConnectStubs::JWKS_URL)
        .to_return({ body: france_connect_key_set.to_json }, { body: france_connect_key_set(rotated).to_json })

      expect(opener.open(sealed)).to include('sub' => 'un-pseudonyme')
    end
  end
end
