require Rails.root.join('spec/support/france_connect_stubs')

# The one leg of the European flow the browser itself walks, and the only one
# WebMock cannot stand in for.
#
# Of the whole exchange with FranceConnect+, a single request leaves the
# browser: the redirection to the authorization endpoint. The discovery
# document, the JWKS, `/token` and `/userinfo` are all asked for by the
# application, in the scenario's own process, so `spec/support/france_connect_stubs.rb`
# answers them exactly as it answers a request spec.
#
# That one leg cannot be sent elsewhere: `FranceConnectClient#endpoint`
# **rebuilds** every address on the origin of `Settings.france_connect_issuer`
# and refuses anything that is not under it. The authorization endpoint is
# therefore on the issuer by construction, and the issuer has to be somewhere
# the browser can reach — which is the server Capybara is already running.
#
# So the issuer becomes an address of that server, and this wraps the
# application to answer the single path underneath it the browser touches.
# Everything else on that origin falls through to the application, which is
# what makes the mounting invisible to every other scenario.
class BrowserFranceConnect
  # Under the application's own origin, so nothing but the issuer setting has to
  # move. No route of `config/routes.rb` begins with it.
  MOUNT = '/faux-franceconnect'.freeze

  AUTHORIZE = "#{MOUNT}/authorize".freeze

  # The authorization code handed back, which the `/token` double then answers
  # for. Its value settles nothing — FranceConnect+ chooses it, and the
  # application only sends it back — so it is fixed rather than generated.
  CODE = 'un-code-du-navigateur'.freeze

  def initialize(app)
    @app = app
    @lock = Mutex.new
  end

  def call(env)
    return @app.call(env) unless env['PATH_INFO'] == AUTHORIZE

    authorize(Rack::Utils.parse_query(env['QUERY_STRING']))
  end

  # The `nonce` of the departure, read off the address the browser was sent to.
  # What the ID Token has to carry for the return to be accepted, and the reason
  # the `/token` double is built at call time: it is this value, and the scenario
  # never chose it.
  def nonce = @lock.synchronize { @nonce }

  private

  # What an identity provider does on this address: it reads the departure and
  # sends the browser back where the departure asked.
  #
  # Only the *path* of `redirect_uri` is kept. The address the procedure
  # declares is built on `Settings.oots_france_url` — `http://oots.test`, which
  # the doubles of the contract are all mounted on and which the browser could
  # not reach — so the return lands on the server the browser is already
  # talking to, which is where the procedure is actually running.
  def authorize(asked)
    @lock.synchronize { @nonce = asked['nonce'] }

    back = URI.parse(asked.fetch('redirect_uri'))
    back.query = URI.encode_www_form(code: CODE, state: asked.fetch('state'))

    [302, { 'location' => "#{back.path}?#{back.query}" }, []]
  end
end

# Wrapped once, at load, and never per scenario: `Capybara.current_session`
# keys its pool on `app.object_id`, so a fresh wrapper each time would boot a
# fresh server each time. `features/support/env.rb` has already required
# `cucumber/rails`, which is what sets `Capybara.app`.
BROWSER_FRANCE_CONNECT = BrowserFranceConnect.new(Capybara.app)
Capybara.app = BROWSER_FRANCE_CONNECT
