require 'rails_helper'

RSpec.describe FranceConnectClient do
  subject(:client) { described_class.new(instance: fake_france_connect) }

  before { stub_france_connect }

  # Every address comes from the discovery document and none is built here:
  # that is what makes the sandbox, the production and the fake a change of
  # configuration rather than of code.
  describe 'what it knows of FranceConnect+' do
    it 'reads the issuer and the key set from the document it publishes' do
      expect(client.issuer).to eq(FranceConnectStubs::ISSUER)
      expect(client.jwks_url).to eq(FranceConnectStubs::JWKS_URL)
    end

    # Three variables separate the fake, the sandbox and the production, and a
    # deployment declares two of them at once: a cached document must be the one
    # its issuer published. Keyed on nothing else, it would serve the fake's
    # endpoints to a client built on the real one, where the check above then
    # refuses them as foreign — and an operator has no way of guessing that a
    # cache is what stands in the way.
    it 'never serves the document of one issuer to a client built on another' do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      real = stub_real_france_connect
      described_class.new(instance: real).authorization_url(state: 's' * 32, nonce: 'n' * 32)

      address = described_class.new(instance: fake_france_connect)
        .authorization_url(state: 's' * 32, nonce: 'n' * 32)

      expect(address).to start_with(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).to have_been_made
    end

    it 'reads the document once and holds it' do
      3.times { client.authorization_url(state: 's' * 32, nonce: 'n' * 32) }

      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).to have_been_made.once
    end

    # The document says which path to call, never which host to call it on: a
    # document naming another host is not the portal's, and following it would
    # carry the `client_secret` and the access token to whoever wrote it.
    it 'refuses an endpoint published outside the issuer it was configured with' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(
        body: discovery_document.merge(token_endpoint: 'https://ailleurs.invalid/token').to_json,
      )

      expect { client.exchange('un-code') }
        .to raise_error(FranceConnectError, /ailleurs\.invalid/)
    end

    # `[A-Za-z0-9._~-]+` matches `..` as happily as `authorize`: without the
    # lookahead of `SEGMENTS`, a document publishing this would pass every check
    # and be normalised out of the base by the HTTP client, carrying the
    # `client_secret` to a path nobody chose.
    it 'refuses a path that climbs out of the base it was configured with' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(
        body: discovery_document.merge(token_endpoint: "#{FranceConnectStubs::ISSUER}/../../ailleurs").to_json,
      )

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError, /ailleurs/)
      expect(a_request(:post, %r{/ailleurs})).not_to have_been_made
    end

    it 'refuses a path carrying anything but plain segments' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(
        body: discovery_document.merge(userinfo_endpoint: "#{FranceConnectStubs::ISSUER}/un%20chemin").to_json,
      )

      expect { client.userinfo('un-jeton') }.to raise_error(FranceConnectError)
    end

    # A maintenance page answered with a 200, a truncated body: every public
    # method of the client goes through the discovery document, so a bare
    # `JSON::ParserError` here would be a 500 on the sign-in, on the return and
    # on the sign-out alike.
    it 'refuses a discovery document that does not read as JSON' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(body: '<html>maintenance</html>')

      expect { client.issuer }.to raise_error(FranceConnectError, /JSON/)
    end

    # A discovery document is a JSON object: anything else would be met three
    # calls later as a `NoMethodError` on a `fetch` nobody could have known
    # would fail.
    it 'refuses a body that reads as JSON but is not an object' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(body: '["ceci", "est", "un", "tableau"]')

      expect { client.issuer }.to raise_error(FranceConnectError, /objet/)
    end

    # Parsed inside the cache block, so a body that does not read never gets
    # written: caching it would serve a passing outage for the whole freshness
    # window, and every identification and every sign-out of the next hour would
    # fail the same way. `CodeListClient` keeps an empty answer out for the same
    # reason, and its spec asks this same question.
    it 'never remembers a discovery document it could not read' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(body: '<html>maintenance</html>')
      allow(Rails.cache).to receive(:write)

      expect { client.issuer }.to raise_error(FranceConnectError)
      expect(Rails.cache).not_to have_received(:write)
    end

    # The third and last way the document has of being unusable, beside the
    # absent endpoint and the unreadable body: a value that is not an address.
    # The three are said in one place, and none of them travels up as it stands
    # to a caller that has no reason to expect it.
    it 'refuses an endpoint that is not an address at all' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL)
        .to_return(body: discovery_document.merge(jwks_uri: 'http://[').to_json)

      expect { client.jwks_url }.to raise_error(FranceConnectError, /jwks_uri/)
    end

    # Named where it is read, rather than left to a bare `KeyError` twenty lines
    # up the stack, which nothing could name.
    it 'refuses a document that publishes no endpoint of that name, and says which' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL)
        .to_return(body: discovery_document.except(:token_endpoint).to_json)

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError, /token_endpoint/)
    end

    it 'calls the path the document publishes, on the host it was configured with' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(
        body: discovery_document.merge(userinfo_endpoint: "#{FranceConnectStubs::ISSUER}/ailleurs").to_json,
      )
      stub_request(:get, "#{FranceConnectStubs::ISSUER}/ailleurs").to_return(body: 'peu importe')

      expect(client.userinfo('un-jeton')).to eq('peu importe')
    end

    # What the ID Token is checked against must be what this deployment was told
    # to talk to, never what the answer said of itself.
    it 'refuses a document announcing an issuer other than the configured one' do
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL)
        .to_return(body: discovery_document.merge(issuer: 'https://ailleurs.invalid').to_json)

      expect { client.issuer }.to raise_error(FranceConnectError, /ailleurs\.invalid/)
    end

    # Declared to FranceConnect+, which refuses an address it was not given:
    # derived from this deployment's own URL and never from the request.
    it 'names the two declared addresses under the procedure URL' do
      expect(client.redirect_uri).to eq('http://oots.test/demo/franceconnect/retour_connexion')
      expect(client.post_logout_redirect_uri).to eq('http://oots.test/demo/franceconnect/retour_deconnexion')
    end
  end

  describe '#authorization_url' do
    subject(:parameters) do
      URI.decode_www_form(URI.parse(client.authorization_url(state: 's' * 32, nonce: 'n' * 32)).query).to_h
    end

    it 'opens the European flow, straight to the country page' do
      expect(parameters).to include('idp_hint' => 'eidas-bridge', 'response_type' => 'code',
        'acr_values' => 'eidas2')
    end

    it 'asks for the minimum data set and the two optional attributes' do
      expect(parameters.fetch('scope').split)
        .to contain_exactly('openid', 'given_name', 'family_name', 'birthdate', 'gender', 'birthplace')
    end

    # No scope covers it: it is the essential-claims mechanism that asks for it,
    # and it is what says the identity came through the eIDAS bridge.
    it 'asks for the authentication method as an essential claim' do
      expect(JSON.parse(parameters.fetch('claims'))).to eq('id_token' => { 'amr' => { 'essential' => true } })
    end

    it 'carries the state and the nonce it is given, and both are 32 characters' do
      expect(parameters.values_at('state', 'nonce')).to eq(['s' * 32, 'n' * 32])
    end

    # A parameter FranceConnect+ does not know is refused outright, without even
    # a redirection: nothing may be added here on a hunch.
    it 'sends nothing FranceConnect+ does not declare' do
      expect(parameters.keys).to contain_exactly('client_id', 'response_type', 'redirect_uri', 'scope',
        'state', 'nonce', 'acr_values', 'claims', 'idp_hint')
    end

    it 'departs from the endpoint the document publishes' do
      expect(client.authorization_url(state: 's', nonce: 'n'))
        .to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
    end
  end

  # `client_secret_post`: the credentials travel in the body, FranceConnect+
  # accepting no `Authorization: Basic` here.
  describe '#exchange' do
    before { stub_france_connect_tokens(france_connect_id_token_claims) }

    it 'presents the code, the redirect address and the credentials in the body' do
      client.exchange('un-code')

      expect(a_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).with do |request|
        URI.decode_www_form(request.body).to_h.then do |body|
          body.values_at('grant_type', 'code', 'client_id', 'client_secret', 'redirect_uri') ==
            ['authorization_code', 'un-code', 'oots-france-demarche', 'secret-de-la-demarche',
             client.redirect_uri]
        end
      end).to have_been_made
    end

    # Ce que le portail lit pour décider si c'est bien nous : présenté au vrai,
    # le secret du faux n'ouvre rien, et un client qui les confondrait enverrait
    # un secret public du dépôt à un correspondant qui n'en veut pas.
    it 'presents the credentials of the FranceConnect+ it was built on, and never the other pair' do
      stub_real_france_connect
      stub_france_connect_tokens(france_connect_id_token_claims, issuer: FranceConnectStubs::REAL_ISSUER)

      described_class.new(instance: real_france_connect).exchange('un-code')

      expect(a_request(:post, "#{FranceConnectStubs::REAL_ISSUER}/token").with do |request|
        URI.decode_www_form(request.body).to_h.values_at('client_id', 'client_secret') ==
          [FranceConnectStubs::REAL_CLIENT_ID, FranceConnectStubs::REAL_CLIENT_SECRET]
      end).to have_been_made
    end

    it 'gives back what the endpoint answered' do
      expect(client.exchange('un-code')).to include('access_token' => 'un-jeton-d-acces')
    end

    # The two the exchange is worth: a caller reaching for `id_token` in a hash
    # that has none would raise a `KeyError` far from here.
    it 'refuses an answer that carries no usable token, and names what is missing' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
        .to_return(body: { access_token: 'un-jeton' }.to_json)

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError, /id_token/)
    end

    # `[]` parses without error and then raises a `TypeError` on the first
    # lookup, three calls away from anything that could name it.
    it 'refuses an answer that reads as JSON but is not an object' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(body: '["un", "tableau"]')

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError, /objet/)
    end

    it 'refuses an answer that is not JSON at all' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(body: 'ceci n\'est pas du JSON')

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError, %r{/token})
    end

    it 'raises on a refusal rather than reading an error as a token' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
        .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError, /invalid_grant/)
    end

    # The refusal the sandbox answered on 2026-09-17: the status and the address
    # are what the HTTP client already said, the three fields are what it dropped.
    it 'relays the refusal in the words FranceConnect+ chose' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(status: 400, body: {
        error: 'invalid_client_metadata',
        error_description: 'client JSON Web Key Set failed to be refreshed (fetch failed)',
        error_uri: 'https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-erreurs/' \
                   '?code=Y044D511&id=4074082d-7095-4067-99d7-ebb795041b72',
      }.to_json)

      expect { client.exchange('un-code') }.to raise_error(FranceConnectError) do |raised|
        expect(raised.message).to include('400', FranceConnectStubs::TOKEN_ENDPOINT,
          'invalid_client_metadata', 'client JSON Web Key Set failed to be refreshed (fetch failed)')
        expect(raised.message).to end_with('id=4074082d-7095-4067-99d7-ebb795041b72')
      end
    end

    # A gateway between the two, a maintenance page: nothing of RFC 6749 §5.2 to
    # read, and the raising of the HTTP client already names the status and the
    # address.
    it 'lets an unmotivated refusal through as the HTTP client raised it' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
        .to_return(status: 502, body: '<html><body>Bad Gateway</body></html>')

      expect { client.exchange('un-code') }.to raise_error(Faraday::Error, /502/) do |raised|
        expect(raised.message).to include(FranceConnectStubs::TOKEN_ENDPOINT)
      end
    end
  end

  describe '#userinfo' do
    it 'presents the access token as a bearer, and hands back the sealed answer' do
      answer = client.userinfo('un-jeton-d-acces')

      expect(a_request(:get, FranceConnectStubs::USERINFO_ENDPOINT)
        .with(headers: { 'Authorization' => 'Bearer un-jeton-d-acces' })).to have_been_made
      expect(answer.split('.').size).to eq(5)
    end
  end

  describe '#end_session_url' do
    subject(:parameters) do
      URI.decode_www_form(URI.parse(client.end_session_url(id_token_hint: 'le-jeton', state: 'l-etat')).query).to_h
    end

    it 'carries the hint, the state and the declared return address' do
      expect(parameters).to eq('id_token_hint' => 'le-jeton', 'state' => 'l-etat',
        'post_logout_redirect_uri' => client.post_logout_redirect_uri)
    end
  end
end
