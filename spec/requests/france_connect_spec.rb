require 'rails_helper'

# The three addresses declared to FranceConnect+. What they must prove is not
# what they display but that they answer at all, and answer to a caller holding
# no session: FranceConnect+ fetches the key set as any anonymous client would,
# and returns a user to the two pages before this application knows them.
RSpec.describe 'The addresses the demonstration procedure declares to FranceConnect+' do
  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwk) { JWT::JWK.new(rsa).export(include_private: true).transform_keys(&:to_s) }

  before { allow(Settings).to receive(:france_connect_private_key_jwk).and_return(jwk) }

  describe 'GET /demo/franceconnect/cles_publiques' do
    it 'serves the key set as JSON, to a caller with no session' do
      get '/demo/franceconnect/cles_publiques'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
    end

    # The point of the route: FranceConnect+ encrypts an ID Token for what it
    # reads here, and this application must be able to open it.
    it 'serves a key FranceConnect+ can actually encrypt for' do
      get '/demo/franceconnect/cles_publiques'

      published = JWT::JWK.new(response.parsed_body['keys'].first)
      encrypted = JWE.encrypt('secret', published.verify_key, alg: 'RSA-OAEP-256', enc: 'A256GCM')

      expect(JWE.decrypt(encrypted, rsa)).to eq('secret')
    end

    it 'never serves a private member' do
      get '/demo/franceconnect/cles_publiques'

      expect(response.parsed_body['keys'].first.keys).not_to include(*PublicKeySet::SECRET_MEMBERS)
      expect(response.body).not_to include(jwk['d'])
    end

    # Two correspondents, two keys: FranceConnect+ must never be handed the key
    # a French service provider encrypts the beneficiary token for. Nothing but
    # this comparison would notice the two routes drifting onto one key.
    it 'publishes a different key from the one the beneficiary token uses' do
      allow(Settings).to receive(:private_key_jwk)
        .and_return(JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048)).export(include_private: true)
          .transform_keys(&:to_s))

      get '/demo/franceconnect/cles_publiques'
      demarche = response.parsed_body['keys'].first

      get '/auth/cles_publiques'

      expect(response.parsed_body['keys'].first['kid']).not_to eq(demarche['kid'])
    end
  end

  # FranceConnect+ requires a declared address to answer; a redirect to the
  # console's login page is what these two would be if they lived under /admin.
  describe 'the two return pages' do
    %w[/demo/franceconnect/retour_connexion /demo/franceconnect/retour_deconnexion].each do |path|
      it "answers #{path} with a page, to a caller with no session" do
        get path

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/html')
      end
    end

    it 'names what the page is for after a sign-in' do
      get '/demo/franceconnect/retour_connexion'

      expect(response.body).to include(I18n.t('france_connect.retour_connexion.title'))
    end

    it 'names what the page is for after a sign-out' do
      get '/demo/franceconnect/retour_deconnexion'

      expect(response.body).to include(I18n.t('france_connect.retour_deconnexion.title'))
    end
  end
end
