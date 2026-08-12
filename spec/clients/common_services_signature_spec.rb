require 'rails_helper'

# The fixtures are real answers captured on the acceptance environment, with
# the signature the Commission put on them: nothing here is hand-made, and a
# change in the mechanism would show up as these examples going red.
RSpec.describe CommonServicesSignature do
  subject(:signature) { described_class.new }

  let(:body_and_headers) { common_services_answer('eb_requirements_fr') }
  let(:body) { body_and_headers.first }
  let(:headers) { body_and_headers.last }

  def verify(body:, digest: headers['digest'], detached: headers['oots-response-sig'])
    signature.verify!(body:, digest:, signature: detached)
  end

  it 'accepts an answer signed by the Commission' do
    expect { verify(body:) }.not_to raise_error
  end

  # The signature covers the `digest` header, and the digest covers the body:
  # skipping the second half would let any body through under a signature that
  # checks out.
  it 'refuses a body the announced digest does not cover' do
    expect { verify(body: "#{body} ") }
      .to raise_error(CommonServicesError, /empreinte annoncée ne couvre pas/)
  end

  it 'refuses an answer carrying no digest at all' do
    expect { verify(body:, digest: nil) }
      .to raise_error(CommonServicesError, /empreinte annoncée ne couvre pas/)
  end

  # A digest recomputed over a substituted body, so the two halves agree with
  # each other but not with what was signed.
  it 'refuses a digest that is coherent with the body but was never signed' do
    forged = '<query:QueryResponse xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"/>'
    digest = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.digest('SHA256', forged))}"

    expect { verify(body: forged, digest:) }.to raise_error(CommonServicesError, /Signature invalide/)
  end

  # The flipped character stays in the base64 alphabet, so the signature keeps
  # its length: the failure is the cryptographic one, and asserting only that
  # would hide a future change sending it down the length check instead.
  it 'refuses a signature whose bytes have been altered' do
    flipped = encoded_signature.sub(/\A./) { |first| first == 'A' ? 'B' : 'A' }

    expect { verify(body:, detached: "#{protected_header}..#{flipped}") }
      .to raise_error(CommonServicesError, /Signature invalide/)
  end

  it 'refuses a signature whose length is not that of ES256' do
    expect { verify(body:, detached: "#{protected_header}..#{Base64.urlsafe_encode64('court', padding: false)}") }
      .to raise_error(CommonServicesError, /taille inattendue/)
  end

  # `Base64.decode64` never raises, so a corrupt entry reaches OpenSSL, which
  # does — and would escape as a 500 rather than a structured refusal.
  it 'refuses a certificate chain it cannot parse' do
    expect { verify(body:, detached: detached_with(x5c: ['pas-un-certificat'])) }
      .to raise_error(CommonServicesError, /Certificat illisible/)
  end

  it 'refuses an answer whose chain is empty' do
    expect { verify(body:, detached: detached_with(x5c: [])) }
      .to raise_error(CommonServicesError, /ne porte aucun certificat/)
  end

  it 'refuses base64 it cannot decode in the signature itself' do
    expect { verify(body:, detached: "#{protected_header}..!!!") }
      .to raise_error(CommonServicesError, /Base64 illisible/)
  end

  it 'refuses a signature carrying its payload instead of pointing at it' do
    header = { alg: 'ES256', b64: true, x5c: [] }
    encoded = Base64.urlsafe_encode64(header.to_json, padding: false)

    expect { verify(body:, detached: "#{encoded}.charge.signature") }
      .to raise_error(CommonServicesError, /mécanisme HttpHeaders/)
  end

  # The four conditions are one `&&`, so a single negative case only ever
  # reaches the first: each of the others needs its own, or removing any of
  # them would go unnoticed.
  it 'refuses a signature whose payload is declared base64-encoded' do
    expect { verify(body:, detached: detached_with(b64: true)) }
      .to raise_error(CommonServicesError, /mécanisme HttpHeaders/)
  end

  # `detached_with` leaves the middle segment empty by default, so without this
  # the first of the four conditions is the one no negative case ever reaches.
  it 'refuses a signature whose middle segment is not empty' do
    expect { verify(body:, detached: detached_with(payload: 'une-charge')) }
      .to raise_error(CommonServicesError, /mécanisme HttpHeaders/)
  end

  it 'refuses a signature signed under another JAdES mechanism' do
    expect { verify(body:, detached: detached_with(sigD: { 'mId' => 'http://ailleurs', 'pars' => ['digest'] })) }
      .to raise_error(CommonServicesError, /mécanisme HttpHeaders/)
  end

  it 'refuses a signature covering headers other than the digest' do
    mechanism = { 'mId' => CommonServicesSignature::JADES_MECHANISM, 'pars' => %w[digest date] }

    expect { verify(body:, detached: detached_with(sigD: mechanism)) }
      .to raise_error(CommonServicesError, /mécanisme HttpHeaders/)
  end

  it 'refuses an algorithm the specification does not admit here' do
    encoded = Base64.urlsafe_encode64({ alg: 'none' }.to_json, padding: false)

    expect { verify(body:, detached: "#{encoded}..") }
      .to raise_error(CommonServicesError, /Algorithme de signature inattendu/)
  end

  it 'refuses an unreadable signature header' do
    expect { verify(body:, detached: 'pas-un-jws') }
      .to raise_error(CommonServicesError, /En-tête de signature illisible/)
  end

  # A valid signature by a certificate nobody trusts proves only that somebody
  # signed. The store is what ties it to the Commission.
  it 'refuses a chain the trust store does not anchor' do
    elsewhere = Tempfile.new(['ailleurs', '.pem'])
    elsewhere.write(unrelated_authority)
    elsewhere.flush

    expect { described_class.new(certificates: elsewhere.path).verify!(body:, **signed_headers) }
      .to raise_error(CommonServicesError, /magasin de confiance/)
  ensure
    elsewhere&.close!
  end

  # One store per environment is what keeps the acceptance root — a distinct
  # certificate, whose CN carries the « test » suffix — from vouching for
  # anything in production: a single combined store would accept this very
  # fixture there.
  it 'refuses an acceptance answer against the production trust store' do
    production = Rails.root.join('config/certificats/services_communs_prod.pem').to_s

    expect { described_class.new(certificates: production).verify!(body:, **signed_headers) }
      .to raise_error(CommonServicesError, /magasin de confiance/)
  end

  it 'names a trust store it cannot read as a deployment fault' do
    empty = Tempfile.new(['vide', '.pem'])

    expect { described_class.new(certificates: empty.path).verify!(body:, **signed_headers) }
      .to raise_error(ConfigurationError, /Magasin de confiance des annuaires illisible/)
  ensure
    empty&.close!
  end

  def signed_headers = { digest: headers['digest'], signature: headers['oots-response-sig'] }

  def protected_header = headers['oots-response-sig'].split('.').first

  def encoded_signature = headers['oots-response-sig'].split('.').last

  # The real protected header, with one field replaced: everything up to the
  # chain stays exactly as the Commission signed it.
  def detached_with(payload: '', **changes)
    decoded = JSON.parse(Base64.urlsafe_decode64(protected_header + ('=' * (-protected_header.length % 4))))
    rebuilt = Base64.urlsafe_encode64(decoded.merge(changes.transform_keys(&:to_s)).to_json, padding: false)

    [rebuilt, payload, encoded_signature].join('.')
  end

  def unrelated_authority
    key = OpenSSL::PKey::RSA.new(2048)

    self_signed(key, OpenSSL::X509::Name.parse('/CN=Autorité sans rapport')).sign(key, OpenSSL::Digest.new('SHA256'))
      .to_pem
  end

  def self_signed(key, name)
    OpenSSL::X509::Certificate.new.tap do |certificate|
      certificate.subject = certificate.issuer = name
      certificate.serial = 1
      certificate.version = 2
      certificate.not_before = 1.day.ago
      certificate.not_after = 1.day.from_now
      certificate.public_key = key.public_key
    end
  end
end
