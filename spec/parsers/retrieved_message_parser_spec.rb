require 'rails_helper'

# Read against envelopes captured from a real Domibus, not against ones written
# by hand: see `spec/fixtures/README.md` for why that distinction matters here.
RSpec.describe RetrievedMessageParser do
  describe 'an incoming request' do
    subject(:message) { described_class.new(real_envelope('requete')) }

    it 'reads the ebMS action' do
      expect(message.action).to eq(EbmsAction::EXECUTE_QUERY_REQUEST)
    end

    # Against the literal values the envelope carries, and never against each
    # other: chapter 4.4 keeps the two apart, and the header puts them in two
    # different places — the conversation in `eb:CollaborationInfo`, the
    # exchange in a `eb:MessageProperties` property. Reading one where the other
    # stands is the mistake this repository just spent a branch correcting, and
    # only a fixed value catches it.
    it 'reads the conversation the exchange belongs to' do
      expect(message.conversation_id).to eq('1589c463-ccb7-4c0e-8044-c7198d844c16')
    end

    it 'reads the exchange the message is one of' do
      expect(message.exchange_id).to eq('1647038b-7eaf-4711-b738-d5d83f96fa7b')
    end

    it 'reads the sender, which is where the answer goes' do
      expect(message.sender).to be_a(AccessPoint).and(be_valid)
    end

    # Chapter 4.8 asks the log for « MIME type and full content of first MIME
    # part », and `retention_downloaded="0"` gives it one chance to take them.
    it 'reads the first MIME part, type as declared and bytes as sent' do
      expect(message.first_part).to have_attributes(
        mime_type: 'application/x-ebrs+xml',
        content: a_string_including('QueryRequest'),
      )
    end

    it 'hands the body to the request parser' do
      expect(message.body).to be_a(EvidenceRequestParser)
    end

    # The origin a timeout of chapter 4.4 is counted from, and the only clock
    # both sides share: our own reception says when we took the message in hand.
    it 'reads the instant the sending gateway stamped' do
      expect(message.sent_at).to eq(Time.zone.parse('2026-08-11T09:22:22.000Z'))
    end
  end

  describe 'an incoming response with evidence' do
    subject(:message) { described_class.new(real_envelope('reponseAvecPieceJointe')) }

    it 'hands the body to the response parser' do
      expect(message.body).to be_a(EvidenceResponseParser)
    end

    it 'decodes the evidence, which is a PDF' do
      expect(message.evidence.content).to start_with('%PDF')
    end

    # Chapter 4.8 asks the response flow for « MIME type and MIME content
    # identifier » of evidence referenced by a `rim:RepositoryItemRef`. The
    # reference is the `href` of the `eb:PartInfo`, and the body points at the
    # very same `cid:`.
    it 'names the part that carried it, as the header declared it' do
      expect(message.evidence).to have_attributes(
        mime_type: 'application/pdf',
        content_id: 'cid:802edbd4-fdfb-4345-84bd-0b7f17549075@pdf.oots.fr',
      )
    end
  end

  describe 'an incoming error' do
    subject(:message) { described_class.new(real_envelope('erreurObjetIntrouvable')) }

    it 'hands the body to the error parser' do
      expect(message.body).to be_a(ErrorResponseParser)
    end

    it 'reads the EDM code, the invariant of the exchange' do
      expect(message.body.code).to eq('EDM:ERR:0004')
    end
  end

  describe 'what it refuses' do
    it 'refuses an envelope that is not XML' do
      expect { described_class.new('pas du xml <') }
        .to raise_error(UnreadableMessageError, /Enveloppe SOAP illisible/)
    end

    it 'refuses an envelope with no ebMS header' do
      expect { described_class.new('<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"/>') }
        .to raise_error(UnreadableMessageError, /Pas d'entête ebMS/)
    end

    # Without it there is no counting the interval of chapter 4.4, and a request
    # answered as though it were fresh is what that interval exists to prevent.
    it 'refuses an envelope whose timestamp it cannot read' do
      document = Nokogiri::XML(real_envelope('requete'))
      document.xpath('//*[local-name()="Timestamp"]').first.content = ''

      expect { described_class.new(document.to_xml).sent_at }
        .to raise_error(UnreadableMessageError, /Horodatage illisible/)
    end

    it 'refuses an action it does not know, rather than guessing' do
      unknown = real_envelope('requete').sub('ExecuteQueryRequest', 'SomethingElse')

      expect { described_class.new(unknown).body }
        .to raise_error(UnreadableMessageError, /Action ebMS inconnue/)
    end
  end

  # The prefix bound to the ebMS namespace differs from one Domibus response to
  # another — `ns3:` here, `ns5:` there — and one envelope binds `ns5:` to two
  # different namespaces at once. Reading by URI is the only thing that holds.
  it 'reads a header whose namespace prefix differs from the usual one' do
    renamed = real_envelope('requete').gsub('ns5:', 'nsX:').gsub('xmlns:ns5=', 'xmlns:nsX=')

    expect(described_class.new(renamed).action).to eq(EbmsAction::EXECUTE_QUERY_REQUEST)
  end

  # `R-EDM-REQ-C073` and its counterpart for the response require an address on
  # the agent classified `EP`, and require nothing of it but the country: that is
  # where the country the response came from is read.
  it 'reads the country the provider answered from' do
    message = described_class.new(real_envelope('reponseAvecPieceJointe'))

    expect(message.body.provider_country).to eq('FR')
  end

  # By position and not by type. On a response `R-EDM-ebMS-032` asks for the
  # RegRep document first at warning severity only, so a correspondent can put
  # something else there and break no fatal rule: recording what they declared
  # is what makes the discrepancy visible, and correcting it would hide it.
  describe 'a message whose first part declares another type' do
    subject(:message) do
      described_class.new(real_envelope('requete').sub('application/x-ebrs+xml', 'application/pdf'))
    end

    it 'reads it as declared' do
      expect(message.first_part.mime_type).to eq('application/pdf')
      expect(message.first_part.content).to include('QueryRequest')
    end
  end

  describe 'a message that declares no part at all' do
    subject(:message) { envelope_without('requete', '//eb:PayloadInfo/eb:PartInfo') }

    it 'refuses rather than invent one' do
      expect { message.first_part }.to raise_error(UnreadableMessageError, /aucune partie MIME/)
    end
  end

  describe 'a message announcing a part it does not carry' do
    subject(:message) { envelope_without('requete', '//ws:retrieveMessageResponse/payload') }

    it 'refuses rather than hand back nothing' do
      expect { message.first_part }.to raise_error(UnreadableMessageError, /annoncée mais absente/)
    end
  end

  # `attribute` resolves a missing attribute to nil, so an unguarded lookup would
  # compare nil to nil and match the first payload that declares no identifier —
  # handing back another part's bytes as if they were the one announced. In an
  # evidentiary log a plausible wrong value is worse than none: the absence shows,
  # the error does not.
  describe 'a message whose first part announces no payload at all' do
    subject(:message) do
      document = Nokogiri::XML(real_envelope('requete'))
      document.at_xpath('//eb:PayloadInfo/eb:PartInfo', OotsNamespaces::NAMESPACES).remove_attribute('href')
      document.at_xpath('//ws:retrieveMessageResponse/payload', OotsNamespaces::NAMESPACES)
        .remove_attribute('payloadId')

      described_class.new(document.to_xml)
    end

    it 'refuses rather than hand back whichever payload declares no identifier' do
      expect { message.first_part }.to raise_error(UnreadableMessageError, /ne désigne aucune charge/)
    end
  end

  # Guarded where the payload it designates is concerned, and deliberately not
  # here: a part that declares no type still arrived, and the journal records
  # the gap rather than refusing the bytes over it.
  describe 'a message whose first part declares no type' do
    subject(:message) do
      document = Nokogiri::XML(real_envelope('requete'))
      document.at_xpath("//eb:PartInfo/eb:PartProperties/eb:Property[@name='MimeType']",
        OotsNamespaces::NAMESPACES).remove

      described_class.new(document.to_xml)
    end

    it 'hands back the content under no type at all' do
      expect(message.first_part).to have_attributes(mime_type: nil, content: a_string_including('QueryRequest'))
    end
  end

  # No chapter fixes an encoding — 4.7.2 profiles `MimeType` and `CompressionType`,
  # and not the `CharacterSet` property the AS4 profile recommends — and chapter
  # 4.8 asks for the content whole. What arrived is archived, well formed or not.
  describe 'a first part that is not encoded in UTF-8' do
    subject(:message) { envelope_with_body('requete') { "<query:QueryRequest>\xE9</query:QueryRequest>" } }

    it 'hands back the bytes as they came, without transcoding them' do
      content = message.first_part.content

      expect(content.bytes).to include(0xE9)
      expect(content.encoding).to eq(Encoding::UTF_8)
    end
  end

  # The reading goes past Nokogiri on purpose: bytes nobody can parse are the
  # ones an auditor most needs, and the gateway has already destroyed them.
  describe 'a message whose body is not XML at all' do
    subject(:message) { envelope_with_body('requete') { 'pas du tout du XML' } }

    it 'still hands back the bytes' do
      expect(message.first_part.content).to eq('pas du tout du XML')
      expect { message.body }.to raise_error(UnreadableMessageError)
    end
  end
end
