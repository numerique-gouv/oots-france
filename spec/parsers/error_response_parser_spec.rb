require 'rails_helper'

RSpec.describe ErrorResponseParser do
  subject(:error) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')).body }

  # The code is the invariant of the end-to-end scenario: it can only come from
  # a message the gateway delivered.
  it 'reads the EDM code' do
    expect(error.code).to eq('EDM:ERR:0004')
  end

  it 'reads the message that accompanies it' do
    expect(error.message).to eq('Object not found')
  end

  # The code distinguishes the eight errors of the TDD, which the message alone
  # conflates — two of them read "Object not found" to a human.
  it 'describes itself by code and message together' do
    expect(error.description).to eq('EDM:ERR:0004 : Object not found')
  end

  it 'is not a request for a preview' do
    expect(error).not_to be_preview_required
  end

  describe 'an authorisation error carrying a preview location' do
    subject(:error) { RetrievedMessageParser.new(envelope).body }

    let(:envelope) { built_envelope('erreurAutorisationRequise') }

    it 'is recognised as a request for a preview' do
      expect(error).to be_preview_required
    end

    it 'reads where to send the user' do
      expect(error.preview_location).to eq('https://previsualisation.example.si/espace?jeton=abc')
    end

    # The two readers part company on an address France will not follow: the
    # journal keeps what arrived — chapter 4.8 has the requester log it, and a
    # refused address is the one a dispute is about — where nothing may act on
    # it. Pinned here rather than only through `AuditTrail`, which is one
    # consumer of a distinction that belongs to the parser.
    it 'declares an unusable address that it refuses to hand out' do
      hostile = RetrievedMessageParser.new(
        envelope_with_preview('javascript:alert(document.domain)'),
      ).body

      expect(hostile.declared_preview_location).to eq('javascript:alert(document.domain)')
      expect(hostile.preview_location).to be_nil
    end

    # `R-EDM-ERR-C022` puts the slot on this severity and on no other, so an
    # ordinary refusal carries none — and reading it must not report the message
    # as malformed, which would drown the warnings that mean it really is.
    it 'names no address, and does not refuse the message, when the slot is absent' do
      ordinary = RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')).body

      expect(ordinary.declared_preview_location).to be_nil
      expect(ordinary.preview_location).to be_nil
    end

    # The type is `rs:AuthorizationExceptionType`, whose prefix is bound in the
    # document and could be anything. The severity says the same thing without
    # that trap, and R-EDM-ERR-C022 is what ties it to the preview slot.
    it 'decides on the severity, never on the prefixed type' do
      renamed = envelope.gsub('rs:AuthorizationExceptionType', 'autre:AuthorizationExceptionType')

      expect(RetrievedMessageParser.new(renamed).body).to be_preview_required
    end
  end

  # R-EDM-ERR-C026 requires the attribute, but nothing guarantees a
  # correspondent obeys, and stumbling on its absence would turn a reportable
  # error into an internal one.
  describe 'an error whose code attribute is missing' do
    subject(:error) { RetrievedMessageParser.new(built_envelope('erreurSansCode')).body }

    it 'reads no code rather than failing' do
      expect(error.code).to be_nil
    end

    it 'falls back on the message alone to describe itself' do
      expect(error.description).to eq('Missing Authorization')
    end
  end

  # `R-EDM-REQ-C073` and its counterpart for the error require an address on the
  # agent classified `ERRP`, and require nothing of it but the country: that is
  # where the country the refusal came from is read.
  it 'reads the country the refusal came from' do
    expect(error.provider_country).to eq('FR')
  end

  def envelope_with_preview(location)
    document = Nokogiri::XML(built_envelope('erreurAutorisationRequise'))
    value = document.xpath('//payload/value').first
    body = Base64.decode64(value.text).sub(/(<rim:Slot name="PreviewLocation">.*?<rim:Value>)[^<]*/m, "\\1#{location}")
    value.content = Base64.strict_encode64(body)

    document.to_xml
  end
end
