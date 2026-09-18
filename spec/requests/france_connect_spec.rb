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

    # What the operator actually reads once the redirection has been followed:
    # the alert of the demonstration's home page, title and reason together.
    def alert = response.parsed_body.css('.fr-alert').text.squish

    # A departure, and the `state` it drew: the return is then one this session
    # accounts for, and the refusal under test is the one the endpoint answers
    # rather than the guard in front of it.
    def departure_of_a_real_identification
      stub_code_list
      stub_demonstration_requirements
      depart_from_demo_home(stub_france_connect)
    end

    it 'holds the identity and hands the operator to the form' do
      identify_demo_user

      expect(response).to redirect_to(admin_demo_documents_path)
      expect(session[:demo_identity].symbolize_keys).to include(family_name: 'Sørensen')
    end

    # CA5: the return is addressed to the FranceConnect+ the departure was made
    # on, all the way through — the code exchanged there, the UserInfo read
    # there, the `iss` checked against that issuer.
    it 'exchanges the code and reads the UserInfo where the departure was made, and nowhere else' do
      identify_demo_user(instance: real_france_connect)

      expect(response).to redirect_to(admin_demo_documents_path)
      expect(a_request(:post, "#{FranceConnectStubs::REAL_ISSUER}/token")).to have_been_made
      expect(a_request(:get, "#{FranceConnectStubs::REAL_ISSUER}/userinfo")).to have_been_made
      expect(a_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)).not_to have_been_made
      expect(a_request(:get, FranceConnectStubs::USERINFO_ENDPOINT)).not_to have_been_made
    end

    # L'autre sens, les deux déclarés : ce que la carte du faux ouvre ne peut pas
    # plus atteindre le vrai que l'inverse.
    it 'exchanges and reads the UserInfo on the fake when the departure was made there, the real declared too' do
      stub_real_france_connect
      identify_demo_user

      expect(response).to redirect_to(admin_demo_documents_path)
      expect(a_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)).to have_been_made
      expect(a_request(:get, FranceConnectStubs::USERINFO_ENDPOINT)).to have_been_made
      expect(a_request(:post, "#{FranceConnectStubs::REAL_ISSUER}/token")).not_to have_been_made
      expect(a_request(:get, "#{FranceConnectStubs::REAL_ISSUER}/userinfo")).not_to have_been_made
    end

    it 'holds which FranceConnect+ attested the identity, so the sign-out knows whose session to end' do
      identify_demo_user(instance: real_france_connect)

      expect(session[:demo_identity].symbolize_keys).to include(france_connect: 'real')
    end

    # The issuer is compared to the one this departure was made on, never to
    # whichever of the two the token names: an ID Token from the other portal
    # attests an authentication nobody here asked for.
    it 'refuses an ID Token bearing the issuer of the other FranceConnect+' do
      stub_code_list
      stub_demonstration_requirements
      identify_demo_user(instance: real_france_connect, iss: FranceConnectStubs::ISSUER)

      expect(response).to redirect_to(admin_demo_root_path)
      expect(session[:demo_identity]).to be_nil
    end

    # Et symétriquement : l'issuer attendu est celui du départ, quel qu'il soit.
    it 'refuses an ID Token bearing the issuer of the real one when the departure was made on the fake' do
      stub_code_list
      stub_demonstration_requirements
      stub_real_france_connect
      identify_demo_user(iss: FranceConnectStubs::REAL_ISSUER)

      expect(response).to redirect_to(admin_demo_root_path)
      expect(session[:demo_identity]).to be_nil
    end

    # A session written when the deployment still declared that FranceConnect+,
    # or a departure forged: there is no correspondent to present the code to,
    # and choosing one would be choosing for the session.
    it 'refuses a return whose departure named a FranceConnect+ no longer declared' do
      stub_code_list
      stub_demonstration_requirements
      departure = depart_from_demo_home(stub_real_france_connect)
      undeclare_france_connect('real')

      get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: departure.fetch('state') }

      expect(response).to redirect_to(admin_demo_root_path)
      expect(a_request(:post, "#{FranceConnectStubs::REAL_ISSUER}/token")).not_to have_been_made
      expect(session[:demo_identity]).to be_nil
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
      stub_demonstration_requirements
      stub_france_connect

      get '/demo/franceconnect/retour_connexion',
        params: { error: 'invalid_acr', error_description: 'acr_value is not valid' }
      follow_redirect!

      expect(response.parsed_body.css('.fr-alert').text).to include('invalid_acr', 'acr_value is not valid')
      expect(session[:demo_identity]).to be_nil
    end

    # The alert adds no punctuation of its own, so a sentence of this repository
    # carries its full stop in its translation and a text the portal sent
    # carries none.
    describe 'the full stop of the reason shown' do
      before do
        stub_code_list
        stub_demonstration_requirements
        stub_france_connect
      end

      it 'ends a refusal the portal did not explain with a single full stop' do
        get '/demo/franceconnect/retour_connexion', params: { error: 'access_denied' }
        follow_redirect!

        expect(alert).to include("FranceConnect+ a refusé l'identification (access_denied) : sans autre explication.")
        expect(alert).not_to include('explication..')
      end

      it 'adds nothing behind the explanation the portal sent' do
        get '/demo/franceconnect/retour_connexion',
          params: { error: 'access_denied', error_description: 'User cancelled' }
        follow_redirect!

        expect(alert).to end_with('User cancelled')
      end

      it 'shows a sentence of this repository with the one full stop it carries' do
        get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: 'un-etat-invente' }
        follow_redirect!

        expect(alert).to end_with('Ce retour ne correspond à aucune identification demandée depuis ce navigateur.')
      end
    end

    # What the sandbox answered on 2026-09-17, and what nothing read: the
    # operator must find it on the screen and in the log, the flash being
    # unreadable after the fact.
    describe 'a refusal FranceConnect+ motivates on /token' do
      let(:refusal) do
        { error: 'invalid_client_metadata',
          error_description: 'client JSON Web Key Set failed to be refreshed (fetch failed)',
          error_uri: 'https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-erreurs/' \
                     '?code=Y044D511&id=4074082d-7095-4067-99d7-ebb795041b72' }
      end

      before do
        allow(Rails.logger).to receive(:warn)
        departure = departure_of_a_real_identification

        stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
          .to_return(status: 400, body: refusal.to_json)

        get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: departure.fetch('state') }
      end

      it 'shows the status, the error, the description and the address, and holds nothing' do
        follow_redirect!

        expect(alert).to include('400', 'invalid_client_metadata',
          'client JSON Web Key Set failed to be refreshed (fetch failed)',
          'Y044D511', '4074082d-7095-4067-99d7-ebb795041b72')
        expect(session[:demo_identity]).to be_nil
      end

      it 'ends on the address FranceConnect+ gave, with no full stop added behind it' do
        follow_redirect!

        expect(alert).to end_with('id=4074082d-7095-4067-99d7-ebb795041b72')
      end

      it 'journalises the same reason' do
        expect(Rails.logger).to have_received(:warn).with(/invalid_client_metadata.*Y044D511/)
      end
    end

    # `/userinfo` refuses a token it does not know the same way, and the fake
    # FranceConnect+ of the end-to-end suite answers exactly this.
    it 'relays a refusal motivated on /userinfo' do
      departure = departure_of_a_real_identification

      stub_france_connect_tokens(france_connect_id_token_claims(nonce: departure.fetch('nonce')))
      stub_request(:get, FranceConnectStubs::USERINFO_ENDPOINT)
        .to_return(status: 401, body: { error: 'invalid_token' }.to_json)

      get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: departure.fetch('state') }
      follow_redirect!

      expect(alert).to include('401', 'invalid_token')
    end

    # A gateway between the two: nothing of RFC 6749 §5.2 to read, and the
    # status and the address are what the reason falls back on.
    it 'names the status and the address when the refusal is motivated by nothing' do
      departure = departure_of_a_real_identification

      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
        .to_return(status: 502, body: '<html><body>Bad Gateway</body></html>')

      get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: departure.fetch('state') }

      expect(response).to redirect_to(admin_demo_root_path)
      follow_redirect!
      expect(alert).to include('502', FranceConnectStubs::TOKEN_ENDPOINT)
    end

    # The authorization code lives thirty seconds and is single use, and the
    # request log writes the query string in clear: `state` is what the support
    # of FranceConnect asks for, the code is what nobody may read back.
    describe 'what the request log keeps of the return address' do
      it 'filters the authorization code and leaves the state readable' do
        stub_code_list
        stub_france_connect

        get '/demo/franceconnect/retour_connexion', params: { code: 'un-code-a-usage-unique', state: 'un-etat' }

        expect(request.filtered_path).to include('code=[FILTERED]', 'state=un-etat')
        expect(request.filtered_path).not_to include('un-code-a-usage-unique')
      end
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
