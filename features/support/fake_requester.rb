# The French service provider, which this deployment does not play.
#
# It publishes the keys that authenticate the beneficiary token it signs, takes
# delivery of the evidence, and serves as the return address. A small Rack app
# rather than a stub: the application really fetches its key set over HTTP, and
# really posts the evidence to it.
class FakeRequester
  # What the last delivery carried: the bytes, and the two identifiers chapter
  # 4.4 §4.3.2 defines. Both are kept, because a fake that
  # took delivery of anything would prove only that a POST was made — and the
  # question these scenarios ask is whether a service provider can tell which of
  # its users this document answers.
  attr_reader :received_evidence, :received_delivery

  def initialize
    @signing_key = OpenSSL::PKey::EC.generate('prime256v1')
    @received_evidence = nil
    @received_delivery = nil
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

    @server.mount_proc('/oots/document') { |request, response| take_delivery(request, response) }

    @server.mount_proc('/oots/callback') { |_request, response| response.status = 200 }
  end

  # Refused when it names no exchange, as a service provider with two users in
  # flight has to refuse it: nothing would tell it whose document this is.
  def take_delivery(request, response)
    delivery = Rack::Utils.parse_nested_query(request.query_string.to_s)

    return response.status = 400 if delivery['echange'].to_s.empty?

    @received_evidence = request.body
    @received_delivery = delivery
    response.status = 200
  end
end
