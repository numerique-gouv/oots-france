require 'rails_helper'

RSpec.describe EbmsHeaderBuilder do
  subject(:header) { described_class.new(**attributes).render }

  let(:attributes) do
    {
      action: EbmsAction::EXECUTE_QUERY_REQUEST,
      recipient: AccessPoint.new(id: 'AP_DE_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'),
      original_sender: EbmsIdentity.new(id: '00000000000002', type_id: IdentifierScheme::FRENCH),
      final_recipient: EbmsIdentity.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
      payload_id: 'cid:1a2b3c4d-0000-4000-8000-000000000000@oots.eu',
      conversation_id: 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24',
      exchange_id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      sender: AccessPoint.new(id: 'AP_FR_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'),
      clock: frozen_clock,
      uuid: sequential_uuids,
    }
  end

  it 'renders the header as the reference message has it' do
    expect(header).to be_equivalent_xml_to(reference_header('requete'))
  end

  # R-EDM-ebMS-018: exactly four, and R-EDM-ebMS-019 names them. A fifth —
  # a `ConversationId` property, which the header carries in
  # `eb:CollaborationInfo` instead — would be a FATAL violation.
  it 'carries the four message properties the rules name, and no other' do
    names = Nokogiri::XML(header)
      .xpath('//eb:MessageProperties/eb:Property/@name',
        'eb' => 'http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/')
      .map(&:value)

    expect(names).to contain_exactly('originalSender', 'finalRecipient', 'ExchangeId', 'SpecificationId')
  end

  # Chapter 4.4 has every message of one exchange reuse its `ExchangeId`, so the
  # builder is given one and never draws its own.
  it 'writes the exchange identifier it was given' do
    expect(header).to include('<eb:Property name="ExchangeId">7c9e6679-7425-40de-944b-e07fc1f90ae7</eb:Property>')
  end

  it 'declares the RegRep body as a payload' do
    expect(header).to include('<eb:Property name="MimeType">application/x-ebrs+xml</eb:Property>')
  end

  it 'declares no second payload when there is no attachment' do
    expect(header.scan('<eb:PartInfo').size).to eq(1)
  end

  it 'declares the attachment as a second payload when there is one' do
    rendered = described_class.new(
      **attributes, attachment: Attachment.new('cid:1111@pdf.oots.fr', 'JVBERi0='),
    ).render

    expect(rendered.scan('<eb:PartInfo').size).to eq(2)
    expect(rendered).to include('<eb:Property name="MimeType">application/pdf</eb:Property>')
  end

  describe 'the corners of the exchange' do
    it 'refuses to build a header whose original sender has no usable identity' do
      incomplete = EbmsIdentity.new(id: '00000000000002', type_id: nil)

      expect { described_class.new(**attributes, original_sender: incomplete) }
        .to raise_error(ConfigurationError, /L'émetteur d'origine \(C1\)/)
    end

    it 'refuses to build a header whose final recipient has no usable identity' do
      incomplete = EbmsIdentity.new(id: nil, type_id: IdentifierScheme::FRENCH)

      expect { described_class.new(**attributes, final_recipient: incomplete) }
        .to raise_error(ConfigurationError, /Le destinataire final \(C4\)/)
    end
  end

  describe 'the exchange identifier' do
    # Chapter 4.4 has every message of one exchange reuse it, so a builder that
    # drew its own would break the correlation the preview depends on: there is
    # no default, and a caller that names none cannot build a header at all.
    it 'refuses to build a header that names no exchange' do
      expect { described_class.new(**attributes.except(:exchange_id)) }.to raise_error(ArgumentError)
    end

    # A provider answers under the identifier it received: that is what ties
    # the two legs of one exchange together.
    it 'reuses the one it received, as a provider does' do
      rendered = described_class.new(**attributes, exchange_id: 'reçu-88888888').render

      expect(rendered).to include('<eb:Property name="ExchangeId">reçu-88888888</eb:Property>')
    end
  end

  it 'escapes a name that would otherwise close its own attribute' do
    hostile = EbmsIdentity.new(id: 'a"><eb:Injecté/><eb:x y="', type_id: IdentifierScheme::FRENCH)
    rendered = described_class.new(**attributes, original_sender: hostile).render

    expect(rendered).not_to include('<eb:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end

  def frozen_clock = instance_double(Clock, now: '2026-08-06T10:00:00.000Z')

  # Starts at 1: the message mints the payload identifier first — it is the one
  # hard-coded above as `payload_id` — and the header draws the next ones. Made
  # explicit because a generator starting at 0 hands the header the very value
  # the payload already carries, and the two then look like one identifier.
  def sequential_uuids
    compteur = 0
    instance_double(UuidGenerator).tap do |generator|
      allow(generator).to receive(:next) { format('1a2b3c4d-0000-4000-8000-%012d', compteur += 1) }
    end
  end
end
