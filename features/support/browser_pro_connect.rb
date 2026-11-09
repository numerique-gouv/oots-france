require Rails.root.join('spec/support/pro_connect_stubs')

# The two legs of ProConnect the browser itself walks — the authorization
# endpoint and the end of session — served by the suite, as
# `BrowserFranceConnect` serves the one of FranceConnect+, and for its reason:
# `OpenidDiscovery` rebuilds every endpoint on the issuer's origin, so the
# issuer has to be an address of the server Capybara runs. Everything the
# application asks for itself is doubled — the discovery document, the JWKS and
# `/userinfo` by `spec/support/pro_connect_stubs.rb`, `/token` by
# `browser_pro_connect_stubs.rb` — and no call leaves the machine.
class BrowserProConnect
  MOUNT = '/faux-proconnect'.freeze
  AUTHORIZE = "#{MOUNT}/authorize".freeze
  SESSION_END = "#{MOUNT}/session/end".freeze

  CODE = 'un-code-du-navigateur'.freeze

  def initialize(app)
    @app = app
    @lock = Mutex.new
  end

  def call(env)
    asked = Rack::Utils.parse_query(env['QUERY_STRING'])

    case env['PATH_INFO']
    when AUTHORIZE then authorize(asked)
    when SESSION_END then end_session(asked)
    else @app.call(env)
    end
  end

  # The `nonce` of the departure, which the `/token` double signs into the ID
  # Token when the application calls it.
  def nonce = @lock.synchronize { @nonce }

  # What ProConnect does when it declines: it sends the browser back with
  # `error` in place of `code`. For the next departure only.
  def refuse_next = @lock.synchronize { @refusing = true }

  # How many times the browser was sent to the end of session since the
  # scenario began.
  def session_ends = @lock.synchronize { @session_ends }

  def reset
    @lock.synchronize do
      @refusing = false
      @session_ends = 0
    end
  end

  private

  def authorize(asked)
    refusing = @lock.synchronize do
      @nonce = asked['nonce']
      @refusing.tap { @refusing = false }
    end
    outcome = refusing ? { error: 'access_denied', error_description: 'refus du faux' } : { code: CODE }

    back(asked.fetch('redirect_uri'), **outcome, state: asked.fetch('state'))
  end

  def end_session(asked)
    @lock.synchronize { @session_ends += 1 }

    back(asked.fetch('post_logout_redirect_uri'), state: asked.fetch('state'))
  end

  # Only the path of the declared address is kept: it is built on
  # `ProConnectStubs::CONSOLE_URL`, which the browser cannot reach, and the
  # application runs on the server the browser is already talking to.
  def back(address, **parameters)
    [302, { 'location' => "#{URI.parse(address).path}?#{URI.encode_www_form(parameters)}" }, []]
  end
end

BROWSER_PRO_CONNECT = BrowserProConnect.new(Capybara.app)
Capybara.app = BROWSER_PRO_CONNECT

Before { BROWSER_PRO_CONNECT.reset }
