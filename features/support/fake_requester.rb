# The French service provider, which this deployment does not play.
#
# It publishes the keys that authenticate the beneficiary token it signs, takes
# delivery of the evidence, and serves as the return address. A small Rack app
# rather than a stub: the application really fetches its key set over HTTP, and
# really posts the evidence to it.
class FakeRequester
  attr_reader :received_evidence

  def initialize
    @signing_key = OpenSSL::PKey::EC.generate('prime256v1')
    @received_evidence = nil
  end

  def start(port)
    @server = WEBrick::HTTPServer.new(
      Port: port, BindAddress: '0.0.0.0',
      Logger: WEBrick::Log.new(File::NULL), AccessLog: [],
    )
    mount
    @thread = Thread.new { @server.start }
    self
  end

  # `shutdown` returns before the socket is actually closed: without waiting for
  # the server thread, the next scenario is refused the port, and the failure
  # looks like a flake when it is perfectly deterministic.
  def stop
    @server&.shutdown
    @thread&.join(5)
  end

  # Encrypted for the key **read from the route**, never for one derived here.
  # Deriving it is exactly what let a broken key-publishing route go unnoticed:
  # the test never called it.
  def beneficiary_token(oots_france_url, claims)
    key_set = JSON.parse(Faraday.get("#{oots_france_url}/auth/cles_publiques").body)
    published = JWT::JWK.new(key_set['keys'].first)

    signed = JWT.encode(
      claims.merge('exp' => Time.current.to_i + 600),
      @signing_key, 'ES256', kid: JWT::JWK.new(@signing_key).export[:kid],
    )

    JWE.encrypt(signed, published.verify_key, alg: 'RSA-OAEP-256', enc: 'A256GCM')
  end

  private

  def mount
    @server.mount_proc('/auth/cles_publiques') do |_request, response|
      response['Content-Type'] = 'application/json'
      response.body = { keys: [JWT::JWK.new(@signing_key).export] }.to_json
    end

    @server.mount_proc('/oots/document') do |request, response|
      @received_evidence = request.body
      response.status = 200
    end

    @server.mount_proc('/oots/callback') { |_request, response| response.status = 200 }
  end
end
