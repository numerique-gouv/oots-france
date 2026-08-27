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

  # `R-EDM-REQ-S004` (FATAL). Refused at the read and not among the checks of
  # `validate!`, because `R-EDM-RESP-S004` and `R-EDM-ERR-S004` hold the answer
  # to the same shape: echoing back what was received would have France sign a
  # response that breaks a fatal rule of its own.
  describe 'the identifier of the request' do
    def with_identifier(value)
      with_body { |body| body.sub(/id="urn:uuid:[^"]*"/, value.nil? ? '' : %(id="#{value}")) }
    end

    it 'refuses one that is not a UUID, under R-EDM-REQ-S004' do
      expect { with_identifier('pas-un-uuid').request_id }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S004')))
    end

    it 'refuses one whose groups are not the shape the rule fixes' do
      expect { with_identifier('urn:uuid:cdd87e02-2bdc-4ce6-bdc979e05adae700').request_id }
        .to raise_error(UnreadableMessageError)
    end

    it 'refuses a bare UUID, the `urn:uuid:` prefix being part of the rule' do
      expect { with_identifier('cdd87e02-2bdc-4ce6-bdc9-79e05adae700').request_id }
        .to raise_error(UnreadableMessageError)
    end

    # Nothing in the rules requires the attribute at all, and a request without
    # one leaves the answer nothing to echo — which `R-EDM-RESP-S003` forbids.
    it 'refuses a request carrying no identifier at all' do
      expect { with_identifier(nil).request_id }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S004')))
    end

    # The Schematron matches with the `i` flag, which covers the literal prefix
    # as much as the hexadecimal: both are asserted, so that splitting the
    # pattern in two would be caught.
    it 'accepts one written in upper case, the rule being case-insensitive' do
      expect(with_identifier('urn:uuid:CDD87E02-2BDC-4CE6-BDC9-79E05ADAE700').request_id)
        .to eq('urn:uuid:CDD87E02-2BDC-4CE6-BDC9-79E05ADAE700')
    end

    it 'accepts one whose prefix itself is upper case' do
      expect(with_identifier('URN:UUID:cdd87e02-2bdc-4ce6-bdc9-79e05adae700').request_id)
        .to eq('URN:UUID:cdd87e02-2bdc-4ce6-bdc9-79e05adae700')
    end

    # The rule constrains neither the version nibble nor the variant one. A
    # reader asking for RFC 4122 in full would refuse what the TDD accept.
    it 'accepts one whose version and variant nibbles are anything' do
      expect(with_identifier('urn:uuid:00000000-0000-0000-0000-000000000000').request_id)
        .to eq('urn:uuid:00000000-0000-0000-0000-000000000000')
    end

    # The rules match on `normalize-space()`, so surrounding blanks are licit;
    # echoing them back would not be.
    it 'accepts one padded with blanks, and hands back the trimmed value' do
      expect(with_identifier('  urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700  ').request_id)
        .to eq('urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700')
    end
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

  # `R-EDM-REQ-S016` lets the evidence subject be an organisation, and
  # `R-EDM-REQ-S047` puts an `sdg:LegalPerson` under the slot. The trap the
  # symmetry hides: a natural person is an `sdg:Person` in a request and an
  # `sdg:NaturalPerson` in a response, where an organisation keeps one name.
  describe 'a request whose subject is a legal person' do
    subject(:organisation) { envelope_about_an_organisation.body.beneficiary }

    def about_an_organisation(&)
      envelope_about_an_organisation(legal_person_slot.then(&)).body
    end

    it 'reads the organisation the evidence is about' do
      expect(organisation)
        .to have_attributes(legal_name: 'Établissements Dupont & Fils', eidas_identifier: 'FR/DE/A2635542Y')
    end

    # Bound by URI and never by prefix: the root of the envelope binds
    # `http://data.europa.eu/p4s` to `sdg:`, and a reader matching the prefix
    # would pass every other example here and fail on the first correspondent
    # that chose another one.
    it 'reads it whatever prefix the correspondent bound the namespace to' do
      renamed = about_an_organisation do |slot|
        slot.gsub('<sdg:', '<p4s:').gsub('</sdg:', '</p4s:')
          .sub('<p4s:LegalPerson>', '<p4s:LegalPerson xmlns:p4s="http://data.europa.eu/p4s">')
      end

      expect(renamed.beneficiary.legal_name).to eq('Établissements Dupont & Fils')
    end

    # Nought or more, each naming the scheme `R-EDM-REQ-C054` requires of it, and
    # keyed by that scheme — which is how `LegalPerson` holds them.
    it 'reads the optional identifiers under the scheme each names' do
      expect(organisation.identifiers).to eq('VAT' => 'FR12345678901', 'LEI' => '969500HBOM1RJXTLZ57')
    end

    it 'reads an organisation carrying no optional identifier at all' do
      bare = about_an_organisation { |slot| slot.gsub(%r{<sdg:Identifier .*?</sdg:Identifier>\n}, '') }

      expect(bare.beneficiary.identifiers).to be_empty
    end

    # `R-EDM-REQ-C054` asserts the attribute's presence and nothing else, and the
    # schema admits `maxOccurs="unbounded"`: this request is conformant, so it is
    # read rather than refused. The table keys by scheme, so the last wins — the
    # column loses what `regrep_body` keeps.
    it 'keeps the last of two identifiers naming the same scheme' do
      repeated = about_an_organisation do |slot|
        slot.sub('schemeID="LEI">969500HBOM1RJXTLZ57', 'schemeID="VAT">FR98765432109')
      end

      expect(repeated.beneficiary.identifiers).to eq('VAT' => 'FR98765432109')
    end

    it 'refuses an identifier that names no scheme, which would designate nothing' do
      unscoped = about_an_organisation { |slot| slot.sub(' schemeID="VAT"', '') }

      expect { unscoped.beneficiary }.to raise_error(UnreadableMessageError, /schéma/)
    end

    # `R-EDM-REQ-C055` is FATAL, and the French SIRET is the case it names: it
    # identifies a corner of the exchange, never the subject of an evidence.
    it 'refuses a scheme the code list does not publish, under R-EDM-REQ-C055' do
      siret = about_an_organisation { |slot| slot.sub('schemeID="VAT"', 'schemeID="SIRET"') }

      expect { siret.beneficiary }.to raise_error(UnreadableMessageError, /SIRET/)
    end

    it 'refuses an organisation without a legal name' do
      anonymous = about_an_organisation { |slot| slot.sub(%r{<sdg:LegalName>.*?</sdg:LegalName>}, '') }

      expect { anonymous.beneficiary }.to raise_error(UnreadableMessageError)
    end

    # `R-EDM-REQ-C051`: `XX/YY/Z…Z`, the two codes being the country asserting
    # the identity and the country it is asserted to.
    it 'refuses an eIDAS identifier that is not of the shape the rule fixes' do
      malformed = about_an_organisation { |slot| slot.sub('FR/DE/A2635542Y', 'A2635542Y') }

      expect { malformed.beneficiary }.to raise_error(UnreadableMessageError)
    end

    # `R-EDM-REQ-S016` refuses a request naming both, but the journal is written
    # before anything validates: the organisation is looked for first, so a
    # malformed one raises even though a readable person sat beside it. Frozen
    # here because it is a choice — no order spares both — and because the line
    # of journal then carries no subject at all, `AuditTrail#readable` dropping
    # the field.
    it 'raises on a malformed organisation even beside a readable person' do
      both = with_body do |body|
        body.sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m) do |slot|
          "#{slot}\n<rim:Slot name=\"LegalPerson\"><rim:SlotValue/></rim:Slot>"
        end
      end

      expect { both.beneficiary }.to raise_error(UnreadableMessageError)
    end

    # The rule counts one subject, and this request carries one: what the slot
    # is named changes nothing to what `validate!` accepts.
    it 'is a request France may answer, under R-EDM-REQ-S016' do
      expect(envelope_about_an_organisation.body.validate!).to be_a(described_class)
    end
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

  # Chapter 4.6, on a request that is well formed and still not one France may
  # answer. Each refusal names the rule it applied, which is the whole of what
  # the correspondent will learn.
  describe 'the business rules it checks' do
    it 'accepts the request a real gateway delivered' do
      expect(request.validate!).to be(request)
    end

    EvidenceRequestParser::REQUIRED_SLOTS.each do |name, rule|
      it "refuses a request with no #{name} slot, under #{rule}" do
        amputated = with_body { |body| body.sub(%r{<rim:Slot name="#{name}">.*?</rim:Slot>}m, '') }

        expect { amputated.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: rule)))
      end
    end

    it 'refuses a request declaring the same mandatory slot twice' do
      doubled = with_body do |body|
        body.sub(%r{<rim:Slot name="ExplicitRequestGiven">.*?</rim:Slot>}m) { |slot| slot * 2 }
      end

      expect { doubled.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S010')))
    end

    it 'refuses a request announcing another version of the data model' do
      dated = with_body { |body| body.sub(EdmSpecification::IDENTIFIER, 'oots-edm:v1.0') }

      expect { dated.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
    end

    # The slot is there, so R-EDM-REQ-S005 is satisfied and it is the value that
    # fails. What the message says of it has to hold without one to name.
    it 'refuses a request whose version slot is present but empty' do
      emptied = with_body do |body|
        body.sub(/(<rim:Slot name="SpecificationIdentifier">.*?<rim:Value>)[^<]*/m, '\\1')
      end

      expect { emptied.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
    end

    # R-EDM-REQ-S016: either one or the other, and never both. France models no
    # legal person yet, so the slot is fabricated here — the rule counts slots,
    # not what they contain.
    it 'refuses a request declaring both a natural and a legal person' do
      doubled = with_body do |body|
        body.sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m) do |slot|
          "#{slot}\n<rim:Slot name=\"LegalPerson\"><rim:SlotValue/></rim:Slot>"
        end
      end

      expect { doubled.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S016')))
    end

    it 'refuses a request declaring no evidence subject at all' do
      amputated = with_body { |body| body.sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m, '') }

      expect { amputated.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S016')))
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
  # `R-EDM-REQ-C073` requires an address on the agent classified `ER`, and
  # requires nothing of it but the country: that is where, and nowhere else, a
  # received request names the country that asks.
  it 'reads the country the requester declares' do
    expect(request.requester.address.country).to eq('FR')
  end
end
