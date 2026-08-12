# Checks the detached signature a Common Service puts on its answers.
#
# Chapter 3.6.2 carries it in the `oots-response-sig` header as a JWS with no
# payload, following the JAdES `HttpHeaders` mechanism: what is signed is not
# the body but the `digest` header, which in turn covers the body. Both halves
# therefore have to be checked, and in that order.
#
# This is the only thing attesting that the directory answering is the
# Commission's. The specification places it above the transport on purpose,
# because chapter 3.4 invites a caching proxy that terminates TLS.
class CommonServicesSignature
  SIGNED_HEADER = 'digest'.freeze
  DIGEST_ALGORITHM = 'SHA-256'.freeze
  JADES_MECHANISM = 'http://uri.etsi.org/19182/HttpHeaders'.freeze

  # Chapter 3.6.2 says EdDSA SHOULD be used and ES256 MAY be: the algorithm
  # implemented here is the specification's second choice, and the only one any
  # instance has been observed signing with. An environment moving to the
  # preferred one would be refused outright rather than accepted unchecked.
  ALGORITHM = 'ES256'.freeze
  COORDINATE_SIZE = 32

  def initialize(certificates: nil)
    @certificates = certificates
  end

  def verify!(body:, digest:, signature:)
    reject_unless_digest_covers(body, digest)

    protected_header, payload, encoded = split(signature)
    header = decode_header(protected_header)
    reject_unless_detached(header, payload)

    # The JAdES `HttpHeaders` mechanism signs the header as it travels, in the
    # `name: value` form of Signing HTTP Messages — lowercase, one space. The
    # unspaced form verifies against nothing.
    signed = "#{protected_header}.#{SIGNED_HEADER}: #{digest}"
    return if signing_key(header).verify('SHA256', der(decode(encoded)), signed)

    raise CommonServicesError, "Signature invalide sur la réponse de l'annuaire."
  end

  private

  def reject_unless_digest_covers(body, digest)
    expected = "#{DIGEST_ALGORITHM}=#{Base64.strict_encode64(OpenSSL::Digest.digest('SHA256', body.to_s))}"
    return if digest == expected

    raise CommonServicesError, "L'empreinte annoncée ne couvre pas la réponse de l'annuaire."
  end

  def reject_unless_detached(header, payload)
    raise CommonServicesError, "Algorithme de signature inattendu : #{header['alg']}." if header['alg'] != ALGORITHM

    return if payload.empty? && header['b64'] == false &&
              header.dig('sigD', 'mId') == JADES_MECHANISM && header.dig('sigD', 'pars') == [SIGNED_HEADER]

    raise CommonServicesError, "Signature de l'annuaire non conforme au mécanisme HttpHeaders."
  end

  # The chain travels in `x5c`, leaf first. Verifying it against the trust
  # store is what makes the signature mean anything: a valid signature by an
  # unknown certificate proves only that somebody signed.
  def signing_key(header)
    chain = certificates(header)
    raise CommonServicesError, "La réponse de l'annuaire ne porte aucun certificat." if chain.empty?

    leaf, *intermediates = chain
    return leaf.public_key if store.verify(leaf, intermediates)

    raise CommonServicesError, "Certificat de l'annuaire rejeté par le magasin de confiance : #{store.error_string}."
  end

  # A trust store that cannot be read is a deployment fault, not a directory
  # misbehaving: without this it would surface as a bare OpenSSL error on the
  # first request rather than as something an operator can act on.
  def store
    path = @certificates || Settings.common_services_certificates

    @store ||= OpenSSL::X509::Store.new.tap { |built| built.add_file(path) }
  rescue OpenSSL::X509::StoreError, SystemCallError => e
    raise ConfigurationError, "Magasin de confiance des annuaires illisible (#{path}) : #{e.message}."
  end

  def split(signature)
    parts = signature.to_s.split('.', -1)
    raise CommonServicesError, "En-tête de signature illisible sur la réponse de l'annuaire." if parts.size != 3

    parts
  end

  def decode_header(protected_header)
    JSON.parse(decode(protected_header))
  rescue JSON::ParserError => e
    raise CommonServicesError, "En-tête de signature illisible sur la réponse de l'annuaire : #{e.message}."
  end

  # Everything a correspondent chose arrives here as bytes to be decoded, and
  # every decoder below raises its own class on malformed input. Left to
  # travel, those would escape the structured failures the interactors expect
  # and surface as a 500 — on the one path whose job is to reject.
  def certificates(header)
    Array(header['x5c']).map { |encoded| OpenSSL::X509::Certificate.new(Base64.decode64(encoded)) }
  rescue OpenSSL::X509::CertificateError => e
    raise CommonServicesError, "Certificat illisible dans la réponse de l'annuaire : #{e.message}."
  end

  def decode(value)
    Base64.urlsafe_decode64(value + ('=' * (-value.length % 4)))
  rescue ArgumentError => e
    raise CommonServicesError, "Base64 illisible dans la signature de l'annuaire : #{e.message}."
  end

  # OpenSSL wants an ASN.1 sequence; JWS carries the two coordinates raw.
  def der(raw)
    raise CommonServicesError, "Signature de l'annuaire de taille inattendue." if raw.bytesize != COORDINATE_SIZE * 2

    integers = raw.unpack('a32a32').map { |half| OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(half, 2)) }

    OpenSSL::ASN1::Sequence.new(integers).to_der
  end
end
