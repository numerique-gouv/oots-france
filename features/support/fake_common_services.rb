# The Evidence Broker and the Data Service Directory, which no French data
# service is registered with yet.
#
# A real HTTP server rather than a stub, for the reason `FakeRequester` is one:
# the application queries these over HTTP and checks the detached signature
# chapter 3.6.2 puts on the answer. Signing here for real, with a chain the
# application is made to trust, keeps that check exercised end to end instead
# of configured away.
class FakeCommonServices
  # The requirement and the evidence type France really publishes, read from
  # the answers captured in `spec/fixtures/common_services/`: the Evidence
  # Broker returns both. What no directory returns is the Data Service
  # Directory entry naming the access point, and that is the hole this fills —
  # see the Common Services workstream of `docs/reste_à_faire.md`.
  REQUIREMENT = 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000'.freeze
  EVIDENCE_TYPE =
    'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'.freeze

  ANSWERS = {
    EvidenceBrokerClient::REQUIREMENTS_QUERY =>
      { template: 'requirements.xml.erb', parameters: %w[procedure-id country-code] },
    EvidenceBrokerClient::EVIDENCE_TYPES_QUERY =>
      { template: 'evidence_types.xml.erb', parameters: %w[requirement-id country-code] },
    DataServiceDirectoryClient::DATA_SERVICES_QUERY =>
      { template: 'data_services.xml.erb', parameters: %w[evidence-type-classification country-code] },
  }.freeze

  # A directory holding nothing refuses by a named code and never succeeds
  # empty, which is what `CommonServicesResponseParser` relies on.
  REFUSALS = {
    CommonServicesInstance::EVIDENCE_BROKER =>
      { code: 'EB:ERR:0001', message: 'The result set is empty' },
    CommonServicesInstance::DATA_SERVICE_DIRECTORY =>
      { code: 'DSD:ERR:0001', message: 'No Data Services were found based on the given parameters' },
  }.freeze

  def initialize
    @root_key = OpenSSL::PKey::EC.generate('prime256v1')
    @signing_key = OpenSSL::PKey::EC.generate('prime256v1')
    @root = issue('/CN=Faux annuaire OOTS - racine', @root_key, signed_by: @root_key, authority: true)
    @leaf = issue('/CN=Faux annuaire OOTS', @signing_key, signed_by: @root_key, issuer: @root)
  end

  def start
    @server = WEBrick::HTTPServer.new(
      Port: port, BindAddress: '0.0.0.0',
      Logger: WEBrick::Log.new(File::NULL), AccessLog: [],
    )
    publish_trust_store
    mount
    @thread = Thread.new { @server.start }
    self
  end

  # See `FakeRequester#stop`: without waiting for the thread, the next scenario
  # is refused the port.
  def stop
    @server&.shutdown
    @thread&.join(5)
  end

  private

  # One port for both directories, told apart by the path their addresses
  # carry: two ports would double the setup for nothing.
  def port
    published = Settings::COMMON_SERVICES_BASE_URLS.each_key.map { |service| URI.parse(address(service)).port }
    raise "Les deux annuaires simulés doivent partager un port : #{published.inspect}." unless published.uniq.one?

    published.first
  end

  def address(service)
    Settings.common_services_base_url(service) ||
      raise("#{Settings::COMMON_SERVICES_BASE_URLS.fetch(service)} n'est pas renseignée : voir docs/test_e2e.md.")
  end

  def mount
    Settings::COMMON_SERVICES_BASE_URLS.each_key do |service|
      path = "#{URI.parse(address(service)).path.chomp('/')}/#{CommonServicesQuery::SEARCH_PATH}"

      @server.mount_proc(path) { |request, response| answer(service, request.query, response) }
    end
  end

  # The chain has to be trusted the way the Commission's is, and no other way:
  # `CommonServicesSignature` reads this store on every query.
  def publish_trust_store
    store = Rails.root.join(Settings.common_services_certificates)
    store.dirname.mkpath
    store.write(@root.to_pem)
  end

  def answer(service, query, response)
    body = body_for(service, query)
    digest = digest_of(body)

    response['Content-Type'] = CommonServicesSpecification::MEDIA_TYPE
    response['digest'] = digest
    response['oots-response-sig'] = signature(digest)
    response.body = body
  end

  # A query this does not serve, or one missing a parameter it needs, is
  # refused rather than answered anyway: an obliging directory would hide the
  # very requests the scenarios exist to check the application sends.
  def body_for(service, query)
    answer = ANSWERS[query['queryId']]
    return render('refusal.xml.erb', REFUSALS.fetch(service)) if answer.nil?
    return render('refusal.xml.erb', REFUSALS.fetch(service)) if answer[:parameters].any? { |name| query[name].blank? }

    render(answer[:template], locals(query, answer[:parameters]))
  end

  def locals(query, parameters)
    parameters.to_h { |name| [name.tr('-', '_').to_sym, query[name]] }
      .merge(access_point: AccessPoint.sender, provider: EvidenceProvider.french(**Settings.french_provider_identity))
  end

  def render(template, values) = DirectoryAnswer.new(template, values).render

  def digest_of(body)
    "#{CommonServicesSignature::DIGEST_ALGORITHM}=#{Base64.strict_encode64(OpenSSL::Digest.digest('SHA256', body))}"
  end

  def signature(digest)
    header = base64url({
      alg: CommonServicesSignature::ALGORITHM,
      typ: 'jose',
      b64: false,
      crit: %w[b64 sigD],
      sigD: {
        mId: CommonServicesSignature::JADES_MECHANISM,
        pars: [CommonServicesSignature::SIGNED_HEADER],
      },
      x5c: [@leaf, @root].map { |certificate| Base64.strict_encode64(certificate.to_der) },
    }.to_json)

    "#{header}..#{base64url(coordinates(@signing_key.sign('SHA256', signed_input(header, digest))))}"
  end

  # The JAdES `HttpHeaders` mechanism signs the header as it travels, in the
  # `name: value` form: lowercase, colon, one space.
  def signed_input(header, digest) = "#{header}.#{CommonServicesSignature::SIGNED_HEADER}: #{digest}"

  # OpenSSL produces an ASN.1 sequence where a JWS carries the two coordinates
  # raw, each padded to the size of the curve.
  def coordinates(der)
    OpenSSL::ASN1.decode(der).value
      .map { |integer| integer.value.to_s(2).rjust(CommonServicesSignature::COORDINATE_SIZE, "\0") }
      .join
  end

  def base64url(value) = Base64.urlsafe_encode64(value, padding: false)

  def issue(subject, key, signed_by:, issuer: nil, authority: false)
    certificate = OpenSSL::X509::Certificate.new
    certificate.subject = OpenSSL::X509::Name.parse(subject)
    certificate.issuer = issuer&.subject || certificate.subject
    certificate.public_key = OpenSSL::PKey.read(key.public_to_pem)
    describe(certificate)
    extend_with(certificate, issuer, authority)

    certificate.sign(signed_by, OpenSSL::Digest.new('SHA256'))
  end

  # Version 2 is X.509 v3, the only one carrying the extensions below.
  def describe(certificate)
    certificate.version = 2
    certificate.serial = SecureRandom.random_number(1 << 64)
    certificate.not_before = 1.hour.ago
    certificate.not_after = 1.day.from_now
  end

  def extend_with(certificate, issuer, authority)
    factory = OpenSSL::X509::ExtensionFactory.new
    factory.subject_certificate = certificate
    factory.issuer_certificate = issuer || certificate
    constraint = authority ? 'CA:TRUE' : 'CA:FALSE'
    usage = authority ? 'keyCertSign,cRLSign' : 'digitalSignature'

    certificate.add_extension(factory.create_extension('basicConstraints', constraint, true))
    certificate.add_extension(factory.create_extension('keyUsage', usage, true))
    certificate.add_extension(factory.create_extension('subjectKeyIdentifier', 'hash'))
  end
end
