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

  # FranceConnect+ requires a declared address to answer, and returns a user to
  # both of them before this application knows who they are.
  describe 'GET /demo/franceconnect/retour_connexion' do
    before { sign_in }

    it 'holds the identity and hands the operator to the form' do
      identify_demo_user

      expect(response).to redirect_to(admin_demo_demande_path)
      expect(session[:demo_identity].symbolize_keys).to include(family_name: 'Sørensen')
    end

    # An authorization code is single use: leaving in the history a page that
    # carries one invites replaying it, so nothing is ever rendered here.
    it 'redirects rather than renders, whichever way it goes' do
      stub_code_list
      stub_france_connect

      get '/demo/franceconnect/retour_connexion', params: { error: 'access_denied' }

      expect(response).to redirect_to(admin_demo_root_path)
    end

    it 'relays the refusal FranceConnect+ came back with, and holds nothing' do
      stub_code_list
      stub_france_connect

      get '/demo/franceconnect/retour_connexion',
        params: { error: 'invalid_acr', error_description: 'acr_value is not valid' }
      follow_redirect!

      expect(response.parsed_body.css('.fr-alert').text).to include('invalid_acr', 'acr_value is not valid')
      expect(session[:demo_identity]).to be_nil
    end

    # No session of this application asked for it: a code replayed from a
    # history, or one obtained elsewhere.
    it 'refuses a return no departure of this session accounts for' do
      stub_code_list
      stub_france_connect

      get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: 'un-etat-invente' }

      expect(response).to redirect_to(admin_demo_root_path)
      expect(session[:demo_identity]).to be_nil
    end
  end

  # A page, where the other return is a redirection: the user arrives with no
  # session left on either side, and there is nothing to send them on to.
  describe 'GET /demo/franceconnect/retour_deconnexion' do
    it 'answers with a page, to a caller with no session' do
      get '/demo/franceconnect/retour_deconnexion'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
    end

    it 'names what the page is for after a sign-out' do
      get '/demo/franceconnect/retour_deconnexion'

      expect(response.body).to include(I18n.t('france_connect.retour_deconnexion.title'))
    end

    # RG10: the `state` is what says this arrival answers a sign-out this
    # browser asked for. Without it the page still answers — FranceConnect+
    # requires a declared address to — but it attests nothing.
    it 'says it attests nothing when the state answers no sign-out of this browser' do
      get '/demo/franceconnect/retour_deconnexion', params: { state: 'un-etat-invente' }

      expect(response.parsed_body.css('main').text).to include("n'atteste donc rien")
    end
  end
end
