require 'rails_helper'

RSpec.describe EvidenceRequestParser do
  subject(:request) { RetrievedMessageParser.new(real_envelope('requete')).body }

  it 'reads the procedure the request is made under' do
    expect(request.procedure_code).to eq(ProcedureCode::SYSTEM_CHECK)
  end

  # A procedure code is a string, and `00` is one of them. A reader that guessed
  # types would turn it into the number 0 and no longer match anything.
  it 'keeps a numeric-looking procedure code as text' do
    expect(request.procedure_code).to be_a(String)
  end

  it 'reads the identifier the answer must echo' do
    expect(request.request_id).to start_with('urn:uuid:')
  end

  it 'reads whom the evidence is about' do
    expect(request.beneficiary)
      .to have_attributes(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')
  end

  # The requester's token did not carry one, and the element is simply absent
  # from the message rather than present and empty.
  it 'leaves the eIDAS identifier unset when the request carried none' do
    expect(request.beneficiary.eidas_identifier).to be_nil
  end

  it 'reads the evidence type asked for, with its distribution format' do
    expect(request.evidence_type.id).to be_present
    expect(request.evidence_type.distribution_format).to eq(EvidenceType::PDF)
  end

  describe 'the requester' do
    # OOTS-France travels in the same collection, classified IP. Answering the
    # platform instead of the requester would address the wrong party.
    it 'is the agent classified ER, not the intermediary platform' do
      expect(request.requester.id).not_to eq('OOTSFRANCE')
    end

    it 'carries the scheme its identifier belongs to' do
      expect(request.requester.type_id).to be_present
    end

    it 'yields a valid ebMS identity, so the answer can be addressed' do
      expect(request.requester.ebms_identity).to be_valid
    end
  end

  describe 'what it refuses' do
    # Each of these must raise UnreadableMessageError and not a bare
    # TypeError, which no `rescue` on the path recognises: the correspondent
    # would be left with no answer at all, instead of the EDM:ERR:0003 the TDD
    # prescribe.
    it 'refuses a request whose procedure slot is missing' do
      amputated = with_body { |body| body.sub(%r{<rim:Slot name="Procedure">.*?</rim:Slot>}m, '') }

      expect { amputated.procedure_code }.to raise_error(UnreadableMessageError, /Procedure/)
    end

    it 'refuses a request whose procedure slot is present but empty' do
      emptied = with_body { |body| body.sub(/(<rim:Slot name="Procedure">.*?<rim:Value>)[^<]*/m, '\\1') }

      expect { emptied.procedure_code }.to raise_error(UnreadableMessageError, /vide/)
    end

    it 'refuses a request with no agent classified ER' do
      demoted = with_body { |body| body.gsub('>ER<', '>IP<') }

      expect { demoted.requester }.to raise_error(UnreadableMessageError, /ER/)
    end
  end

  # The body travels base64-encoded inside the envelope, so a fixture cannot be
  # edited in place: it has to be decoded, altered, and encoded back. Editing
  # the envelope string directly changes nothing at all — silently.
  def with_body
    envelope = real_envelope('requete')
    document = Nokogiri::XML(envelope)
    value = document.xpath('//payload/value').first
    value.content = Base64.strict_encode64(yield(Base64.decode64(value.text)))

    RetrievedMessageParser.new(document.to_xml).body
  end
end
