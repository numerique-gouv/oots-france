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

  # The rules of chapter 4.6 a reader settles on the report alone, and the
  # cardinalities chapter 4.5.3 fixes that no FATAL assertion executes. None of
  # them refuses anything: the chapter assigns the duty of validating to nobody,
  # and no error path runs from a portal back to a provider — the journal names
  # the rule and the exchange settles as it would have.
  describe 'the business rules it confronts an error report to' do
    # The captured report is conformant, so anything reported here is a reader
    # inventing a breach rather than a correspondent committing one.
    it 'finds nothing to say about the report a real gateway delivered' do
      expect(error.violations).to be_empty
    end

    it 'finds nothing to say about the same report on the 1.2 line' do
      expect(earlier_line_report.violations).to be_empty
    end

    describe 'the envelope' do
      # `-S001` and `-S002` are asserted of `/node()` apart, so a document
      # opening on a `query:QueryRequest` breaks the first alone: its namespace
      # is the very one the second asks for.
      it 'names the rule requiring the root element, and not the one requiring its namespace' do
        broken = rules_broken_by { |body| body.gsub('query:QueryResponse', 'query:QueryRequest') }

        expect(broken).to include('R-EDM-ERR-S001')
        expect(broken).not_to include('R-EDM-ERR-S002')
      end

      it 'names the rule requiring the namespace of the root, and not the one requiring its name' do
        broken = rules_broken_by do |body|
          body.sub('urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0', 'urn:example:query')
        end

        expect(broken).to include('R-EDM-ERR-S002')
        expect(broken).not_to include('R-EDM-ERR-S001')
      end

      it 'names the rule requiring each slot a report leaves out' do
        ErrorEnvelopeConformance::REQUIRED_SLOTS.each do |name, rule|
          expect(rules_broken_by { |body| body.sub(slot(name), '') }).to include(rule)
        end
      end

      # The rules count slots rather than look one up, so two of a name break
      # them as surely as none.
      it 'names the same rule when a report carries one of those slots twice' do
        doubled = rules_broken_by { |body| body.sub(slot('SpecificationIdentifier')) { |found| found * 2 } }

        expect(doubled).to include('R-EDM-ERR-S009')
      end

      # `C001` is judged against the line of the exchange and not the one the
      # report announces, as `R-EDM-RESP-C002` is: a correspondent that drifts
      # is then visible instead of self-justifying.
      it 'names the rule fixing the version when the report announces another line than the exchange' do
        expect(error.violations(expected: EdmSpecification::V1_2).map(&:rule)).to contain_exactly('R-EDM-ERR-C001')
      end

      it 'names the rule requiring the status of a failure' do
        expect(rules_broken_by { |body| body.sub('ResponseStatusType:Failure', 'ResponseStatusType:Success') })
          .to include('R-EDM-ERR-S006')
      end

      it 'names the rule forbidding an object list' do
        expect(rules_broken_by { |body| body.sub('<rs:Exception', '<rim:RegistryObjectList/><rs:Exception') })
          .to include('R-EDM-ERR-S007')
      end

      # `-S008` is asserted of every report and `C011` of one announcing a
      # failure: a report carrying no exception breaks both, the captured one
      # announcing exactly that status.
      it 'names both rules requiring an exception' do
        expect(rules_broken_by { |body| body.sub(exception_element, '') })
          .to include('R-EDM-ERR-S008', 'R-EDM-ERR-C011')
      end

      it 'names the rule closing the list of slots a report may carry' do
        expect(rules_broken_by { |body| body.sub('<rs:Exception', "#{named_slot('Foo')}<rs:Exception") })
          .to include('R-EDM-ERR-S017')
      end

      it 'names the rule shaping the identifier of the request answered' do
        expect(rules_broken_by { |body| body.sub('requestId="urn:uuid:', 'requestId="') })
          .to include('R-EDM-ERR-S004')
      end

      it 'names the rule shaping the identifier of the report itself' do
        expect(rules_broken_by { |body| body.sub('>ebbd2e86', '>urn:uuid:ebbd2e86') })
          .to include('R-EDM-ERR-C002')
      end

      # `-S004` hangs on the attribute itself, so a report carrying none leaves
      # it silent — and `C025` is what then asks for the one exception type
      # chapter 4.5.3 reserves for a report correlating no request.
      it 'names the rule reserving one exception type to a report answering no request' do
        broken = rules_broken_by { |body| body.sub(/ requestId="[^"]*"/, '') }

        expect(broken).to include('R-EDM-ERR-C025')
        expect(broken).not_to include('R-EDM-ERR-S004')
      end

      it 'says nothing of a report answering no request whose exception is an invalid request' do
        broken = uncorrelated_invalid_request

        expect(broken).not_to include('R-EDM-ERR-C025', 'R-EDM-ERR-S004')
      end

      # Chapter 4.5.3 §2 alone: `-S012` counts this slot under `CAUTION`, so no
      # FATAL rule says a report is missing it, and the detail names the table.
      it 'names the chapter requiring the requester slot where no rule does' do
        expect(rules_broken_by { |body| body.sub(slot('EvidenceRequester'), '') })
          .to include(ErrorEnvelopeConformance::REQUESTER_SLOT_REQUIRED)
      end

      it 'exempts from it the report whose exception is an invalid request' do
        expect(uncorrelated_invalid_request).not_to include(ErrorEnvelopeConformance::REQUESTER_SLOT_REQUIRED)
      end

      it 'names the chapter holding that slot to one' do
        doubled = rules_broken_by { |body| body.sub(slot('EvidenceRequester')) { |found| found * 2 } }

        expect(doubled).to include(ErrorEnvelopeConformance::REQUESTER_SLOT_SINGLE)
      end
    end

    describe 'the exception' do
      it 'names the rule requiring each attribute it leaves out' do
        {
          ' xsi:type="rs:ObjectNotFoundExceptionType"' => 'R-EDM-ERR-C012',
          ' message="Object not found"' => 'R-EDM-ERR-C016',
          ' code="EDM:ERR:0004"' => 'R-EDM-ERR-C026',
        }.each do |attribute, rule|
          expect(rules_broken_by { |body| body.sub(attribute, '') }).to include(rule)
        end
      end

      it 'names the rule holding the type to the code list' do
        expect(rules_broken_by { |body| body.sub('rs:ObjectNotFoundExceptionType', 'rs:FooExceptionType') })
          .to include('R-EDM-ERR-C013')
      end

      it 'names the rule holding the code to the code list' do
        expect(rules_broken_by { |body| body.sub('EDM:ERR:0004', 'EDM:ERR:0009') }).to include('R-EDM-ERR-C017')
      end

      # `C014` strikes one value out of the `ErrorSeverity` list: the one the
      # DSD error response uses, which this transaction may not.
      it 'names the rule striking out the severity of a directory error' do
        expect(rules_broken_by { |body| body.sub(EdmException::ERROR, ErrorExceptionConformance::ADDITIONAL_INPUT) })
          .to include('R-EDM-ERR-C014')
      end

      it 'names the rule holding an ordinary error to the ordinary severity' do
        expect(rules_broken_by { |body| body.sub(EdmException::ERROR, EdmException::PREVIEW_REQUIRED) })
          .to include('R-EDM-ERR-C015')
      end

      # That rule's context filters on `@code != 'EDM:ERR:0002'`, which XPath
      # answers false of an exception carrying no code at all.
      it 'leaves that rule silent on an exception carrying no code' do
        broken = rules_broken_by { |body| body.sub(' code="EDM:ERR:0004"', '') }

        expect(broken).to include('R-EDM-ERR-C026')
        expect(broken).not_to include('R-EDM-ERR-C015')
      end

      it 'names the rule requiring the timestamp slot' do
        expect(rules_broken_by { |body| body.sub(slot('Timestamp'), '') }).to include('R-EDM-ERR-S013')
      end

      it 'names the rule shaping the timestamp' do
        expect(rules_broken_by { |body| body.sub('2026-08-11T09:22:24.301Z', 'hier') })
          .to include('R-EDM-ERR-C018')
      end

      # The two contexts the Schematron gives these rules, read apart: `-S013`
      # hangs on `rs:Exception` with no ancestor named, where `C026` is written
      # from `query:QueryResponse` down. A document opening on something else
      # keeps the first and opens the second nowhere.
      it 'keeps the rule that names no ancestor where the root is not a query response' do
        broken = rules_broken_by do |body|
          body.gsub('query:QueryResponse', 'query:QueryRequest')
            .sub(slot('Timestamp'), '').sub(' code="EDM:ERR:0004"', '')
        end

        expect(broken).to include('R-EDM-ERR-S013')
        expect(broken).not_to include('R-EDM-ERR-C026')
      end

      it 'names the rule closing the list of slots an exception may carry' do
        expect(rules_broken_by { |body| with_exception_slots(body, preview_method_slot) })
          .to include('R-EDM-ERR-S027')
      end

      # The 1.2 line admits that slot, `PreviewMethod` being what 2.0 retired.
      it 'leaves that rule silent on the line whose exception may carry a preview method' do
        broken = earlier_line_rules_broken_by { |body| with_exception_slots(body, preview_method_slot) }

        expect(broken).not_to include('R-EDM-ERR-S027')
      end
    end

    describe 'the preview an exception may ask for' do
      it 'names the rule requiring a secure address, and it alone' do
        expect(authorised_preview('http://apercu.example').violations.map(&:rule))
          .to contain_exactly('R-EDM-ERR-C019')
      end

      # `C022` is applied whole, as chapter 4.6 publishes it: the severity its
      # assertion tests, and the exception type its sentence names beside it.
      it 'names the rule tying the preview slot to the severity' do
        expect(rules_broken_by { |body| with_exception_slots(body, preview_location) })
          .to include('R-EDM-ERR-C022')
      end

      it 'names it again where the severity is right and the exception type is not' do
        broken = rules_broken_by do |body|
          with_exception_slots(body, preview_location)
            .sub(EdmException::ERROR, EdmException::PREVIEW_REQUIRED)
        end

        expect(broken).to include('R-EDM-ERR-C022')
      end

      it 'says nothing of a preview asked for by an authorisation error of the right severity' do
        expect(authorised_preview.violations.map(&:rule)).not_to include('R-EDM-ERR-C022')
      end

      it 'names the rule holding the language of a description to the code list' do
        expect(rules_broken_by { |body| with_exception_slots(body, preview_description('xx')) })
          .to include('R-EDM-ERR-C020')
      end

      it 'names the rule holding the method of a 1.2 report to three verbs' do
        broken = earlier_line_rules_broken_by do |body|
          with_exception_slots(body, preview_method_slot('PATCH'))
        end

        expect(broken).to include('R-EDM-ERR-C021')
      end

      it 'names the rule requiring a method beside a preview location on that line' do
        broken = earlier_line_rules_broken_by { |body| with_exception_slots(body, preview_location) }

        expect(broken).to include('R-EDM-ERR-S031')
      end

      it 'names neither of those two on the line that retired the slot' do
        broken = rules_broken_by { |body| with_exception_slots(body, preview_location) }

        expect(broken).not_to include('R-EDM-ERR-C021', 'R-EDM-ERR-S031')
      end

      it 'names the chapter holding a preview slot to one' do
        doubled = rules_broken_by do |body|
          with_exception_slots(body, "#{preview_location}#{preview_location}")
        end

        expect(doubled).to include(ErrorExceptionConformance::PREVIEW_SLOT_SINGLE)
      end
    end

    describe 'the shape of its slots' do
      it 'names the rule typing each slot value' do
        {
          'SpecificationIdentifier' => 'R-EDM-ERR-S018', 'EvidenceResponseIdentifier' => 'R-EDM-ERR-S019',
          'ErrorProvider' => 'R-EDM-ERR-S020', 'EvidenceRequester' => 'R-EDM-ERR-S021',
          'Timestamp' => 'R-EDM-ERR-S022',
        }.each do |name, rule|
          expect(rules_broken_by { |body| body.sub(slot(name)) { |found| found.sub(/xsi:type="[^"]*"/, 'xsi:type="rim:FooType"') } })
            .to include(rule)
        end
      end

      # The assertions compare `substring-after(@xsi:type, ':')`, so the prefix
      # decides nothing — as `OotsNamespaces` says it cannot.
      it 'says nothing of a slot value whose type carries another prefix' do
        expect(rules_broken_by { |body| body.sub('rim:DateTimeValueType', 'foo:DateTimeValueType') })
          .not_to include('R-EDM-ERR-S022')
      end

      it 'names the rules typing the preview slots' do
        broken = rules_broken_by do |body|
          with_exception_slots(body,
            preview_location.sub('rim:StringValueType', 'rim:FooType') +
              preview_description.sub('rim:InternationalStringValueType', 'rim:FooType'))
        end

        expect(broken).to include('R-EDM-ERR-S023', 'R-EDM-ERR-S024')
      end

      it 'names the rule typing the preview method of a 1.2 report' do
        broken = earlier_line_rules_broken_by do |body|
          with_exception_slots(body, preview_method_slot('GET').sub('rim:StringValueType', 'rim:FooType'))
        end

        expect(broken).to include('R-EDM-ERR-S025')
      end

      it 'names the rule requiring a value in every slot' do
        expect(rules_broken_by { |body| body.sub(%r{<rim:SlotValue[^>]*>.*?</rim:SlotValue>}m, '') })
          .to include('R-EDM-ERR-S028')
      end

      it 'names the rule requiring content in every slot value' do
        expect(rules_broken_by { |body| body.sub(%r{(<rim:SlotValue[^>]*>).*?(</rim:SlotValue>)}m, '\1\2') })
          .to include('R-EDM-ERR-S029')
      end
    end

    describe 'the two agents it names' do
      it 'names the rule requiring the scheme of each identifier' do
        expect(rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(/ schemeID="[^"]*"/, '') } })
          .to include('R-EDM-ERR-C003')
      end

      # `C003` asserts the attribute and nothing more, so one written empty
      # satisfies it and falls to `C004`, which compares the value.
      it 'lets an empty scheme satisfy that rule and fall to the one comparing it' do
        broken = rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(/ schemeID="[^"]*"/, ' schemeID=""') } }

        expect(broken).not_to include('R-EDM-ERR-C003')
        expect(broken).to include('R-EDM-ERR-C004')
      end

      it 'names the rule holding the scheme of the error provider to the two forms the TDD admit' do
        expect(rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(/schemeID="[^"]*"/, 'schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:ZZ"') } })
          .to include('R-EDM-ERR-C004')
      end

      it 'names the rule holding the scheme of the requester to the same two forms' do
        expect(rules_broken_by { |body| body.sub(requester_agent) { |found| found.sub(/schemeID="[^"]*"/, 'schemeID="SIRET"') } })
          .to include('R-EDM-ERR-C010')
      end

      it 'names the rule requiring the scheme of the requester identifier' do
        expect(rules_broken_by { |body| body.sub(requester_agent) { |found| found.sub(/ schemeID="[^"]*"/, '') } })
          .to include('R-EDM-ERR-C009')
      end

      it 'names the rule striking the requesting classification out of an error report' do
        expect(rules_broken_by { |body| body.sub('<sdg:Classification>ERRP</sdg:Classification>', '<sdg:Classification>ER</sdg:Classification>') })
          .to include('R-EDM-ERR-C008')
      end

      it 'names both rules on a classification written empty' do
        expect(rules_broken_by { |body| body.sub('<sdg:Classification>ERRP</sdg:Classification>', '<sdg:Classification></sdg:Classification>') })
          .to include('R-EDM-ERR-C007', 'R-EDM-ERR-C008')
      end

      it 'says nothing of the requester carrying the classification the provider may not' do
        broken = rules_broken_by do |body|
          body.sub(requester_agent) { |found| found.sub('</sdg:Agent>', '<sdg:Classification>ER</sdg:Classification></sdg:Agent>') }
        end

        expect(broken).not_to include('R-EDM-ERR-C007', 'R-EDM-ERR-C008')
      end

      it 'names the rule requiring the address of the error provider on the 2.0 line' do
        expect(rules_broken_by { |body| body.sub('<sdg:AdminUnitLevel1>FR</sdg:AdminUnitLevel1>', '') })
          .to include('R-EDM-ERR-C024')
      end

      # That rule anchors on the address in 1.2.5, where an agent naming none
      # breaks nothing: what the table of chapter 4.5.3 §3.1 says is then what
      # the detail names.
      it 'names the chapter and not that rule where a 1.2 report names no address at all' do
        broken = earlier_line_rules_broken_by { |body| body.sub(%r{<sdg:Address>.*?</sdg:Address>}m, '') }

        expect(broken).to include(ErrorAgentConformance::PROVIDER_ADDRESS_SINGLE)
        expect(broken).not_to include('R-EDM-ERR-C024')
      end

      it 'names that rule and not the chapter where a 2.0 report names none' do
        broken = rules_broken_by { |body| body.sub(%r{<sdg:Address>.*?</sdg:Address>}m, '') }

        expect(broken).to include('R-EDM-ERR-C024')
        expect(broken).not_to include(ErrorAgentConformance::PROVIDER_ADDRESS_SINGLE)
      end

      it 'names the rule holding the country to the code list' do
        expect(rules_broken_by { |body| body.sub('<sdg:AdminUnitLevel1>FR</sdg:AdminUnitLevel1>', '<sdg:AdminUnitLevel1>ZZ</sdg:AdminUnitLevel1>') })
          .to include('R-EDM-ERR-C005')
      end

      # `C006` is published FATAL by the 4.6 of both tags though the 1.2.5
      # Schematron does not execute it: the chapter is what applies, the
      # doctrine `docs/versions_tdd.md` holds.
      it 'names the rule holding the territory to the NUTS list on either line' do
        territory = '<sdg:AdminUnitLevel2>ZZ9</sdg:AdminUnitLevel2>'
        inserted = ->(body) { body.sub('</sdg:AdminUnitLevel1>', "</sdg:AdminUnitLevel1>#{territory}") }

        expect(rules_broken_by { |body| inserted.call(body) }).to include('R-EDM-ERR-C006')
        expect(earlier_line_rules_broken_by { |body| inserted.call(body) }).to include('R-EDM-ERR-C006')
      end

      it 'names the rule requiring the language of each name' do
        expect(rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(/ lang="[^"]*"/, '') } })
          .to include('R-EDM-ERR-C031')
      end

      # `C031` and `C029` are the same assertion published twice, the slot
      # fixing the identifier: the provider's name above, the requester's here.
      it 'names the rule requiring the language of a requester name' do
        expect(rules_broken_by { |body| body.sub(requester_agent) { |found| found.sub(/ lang="[^"]*"/, '') } })
          .to include('R-EDM-ERR-C029')
      end

      it 'names the rule holding the language of a requester name to the code list' do
        expect(rules_broken_by { |body| body.sub(requester_agent) { |found| found.sub(/ lang="[^"]*"/, ' lang="xx"') } })
          .to include('R-EDM-ERR-C028')
      end

      # `C028` and `C030` are that same assertion published twice, as `C029` and
      # `C031` are the pair above: the requester's name there, the provider's
      # here.
      it 'names the rule holding the language of a provider name to the code list' do
        expect(rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(/ lang="[^"]*"/, ' lang="xx"') } })
          .to include('R-EDM-ERR-C030')
      end

      # The other half of `C004` and `C010`, one assertion holding two things:
      # `string-length(.) < 256` measures the identifier element, so a scheme
      # the rule admits does not exempt the value it carries.
      it 'names the rule when an identifier the scheme admits runs past 256 characters' do
        overlong = 'x' * AgentConformance::MAXIMUM_IDENTIFIER_LENGTH

        expect(rules_broken_by { |body| body.sub('>00000000000001<', ">#{overlong}<") })
          .to include('R-EDM-ERR-C004')
      end

      # `C023` and `-S026` are word for word the same assertion on the same
      # context, and both are named: each is a rule the chapter publishes under
      # its own identifier.
      it 'names both rules counting the agent of the error provider slot' do
        doubled = rules_broken_by { |body| body.sub(provider_agent) { |found| found * 2 } }

        expect(doubled).to include('R-EDM-ERR-C023', 'R-EDM-ERR-S026')
      end

      it 'names the chapter counting the agent of the requester slot, which no rule counts' do
        doubled = rules_broken_by { |body| body.sub(requester_agent) { |found| found * 2 } }

        expect(doubled).to include(ErrorAgentConformance::REQUESTER_AGENT_SINGLE)
      end

      # Every context of the four rules is the element or below, so an agent
      # carrying no identifier and no name breaks none of them.
      it 'names the chapter and no rule where the error provider carries no identifier' do
        broken = rules_broken_by { |body| body.sub(%r{<sdg:Identifier[^>]*>00000000000001</sdg:Identifier>}, '') }

        expect(broken).to include('TDD 4.5.3 §3.1: ErrorProvider agent identifier required')
        expect(broken).not_to include('R-EDM-ERR-C003', 'R-EDM-ERR-C004')
      end

      it 'names the chapter and no rule where it carries no name' do
        broken = rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(%r{<sdg:Name.*?</sdg:Name>}m, '') } }

        expect(broken).to include('TDD 4.5.3 §3.1: ErrorProvider agent name required')
        expect(broken).not_to include('R-EDM-ERR-C031', 'R-EDM-ERR-C030')
      end
    end

    describe 'the two rules that walk the whole document' do
      it 'names the rule measuring every wording' do
        expect(rules_broken_by { |body| body.sub(provider_agent) { |found| found.sub(%r{(<sdg:Name[^>]*>).*?(</sdg:Name>)}m, '\1X\2') } })
          .to include('R-EDM-ERR-C027')
      end

      # The context of that rule lists twenty-three element names in 1.2.5 and
      # twenty-one in 2.0.1, `sdg:JurisdictionContext` being one of the two it
      # lost.
      it 'measures a jurisdiction context on the earlier line and not on the later one' do
        inserted = ->(body) { body.sub('<sdg:Classification>', '<sdg:JurisdictionContext>X</sdg:JurisdictionContext><sdg:Classification>') }

        expect(earlier_line_rules_broken_by { |body| inserted.call(body) }).to include('R-EDM-ERR-C027')
        expect(rules_broken_by { |body| inserted.call(body) }).not_to include('R-EDM-ERR-C027')
      end

      # The disjunction of `C027` asks one character of the locator designator
      # and two of the twenty others — so that element alone can be reported as
      # empty rather than as too short, which is the other sentence.
      it 'measures the locator designator against one character and not two' do
        locator = ->(value) { "<sdg:LocatorDesignator>#{value}</sdg:LocatorDesignator>" }
        inserted = ->(body, value) { body.sub('<sdg:AdminUnitLevel1>', "#{locator.call(value)}<sdg:AdminUnitLevel1>") }

        expect(rules_broken_by { |body| inserted.call(body, '') }).to include('R-EDM-ERR-C027')
        expect(rules_broken_by { |body| inserted.call(body, 'X') }).not_to include('R-EDM-ERR-C027')
      end

      it 'names the rule forbidding two wordings of one language side by side' do
        doubled = rules_broken_by do |body|
          body.sub(provider_agent) { |found| found.sub(%r{<sdg:Name.*?</sdg:Name>}m) { |name| name * 2 } }
        end

        expect(doubled).to include('R-EDM-ERR-S030')
      end
    end

    # `-S003`, `-S012`, `-S014` and `-S015` are `CAUTION`, as no rule a response
    # in success breaks is ever named under that role either.
    it 'never names a rule the chapter publishes as a caution' do
      broken = rules_broken_by do |body|
        with_exception_slots(body.sub(/ requestId="[^"]*"/, '').sub(slot('EvidenceRequester'), ''),
          preview_description + preview_description)
      end

      expect(broken).not_to include('R-EDM-ERR-S003', 'R-EDM-ERR-S012', 'R-EDM-ERR-S014', 'R-EDM-ERR-S015')
    end

    def report(&) = envelope_with_body('erreurObjetIntrouvable', &).body

    def rules_broken_by(&) = report(&).violations.map(&:rule)

    def earlier_line_report(&) = earlier_line_envelope('erreurObjetIntrouvable', &).body

    def earlier_line_rules_broken_by(&) = earlier_line_report(&).violations.map(&:rule)

    # A report answering no request at all, whose exception is the one type
    # chapter 4.5.3 reserves for that case — which is what exempts it from
    # `C025` and from the requester slot at once.
    def uncorrelated_invalid_request
      rules_broken_by do |body|
        body.sub(/ requestId="[^"]*"/, '').sub(slot('EvidenceRequester'), '')
          .sub('rs:ObjectNotFoundExceptionType', 'rs:InvalidRequestExceptionType')
      end
    end

    # The one shape `C022` admits of a preview: an authorisation error of the
    # severity the rule names.
    def authorised_preview(address = 'https://apercu.example/espace')
      report do |body|
        with_exception_slots(body, preview_location(address))
          .sub('rs:ObjectNotFoundExceptionType', EdmException::AUTHORIZATION.type)
          .sub('EDM:ERR:0004', EdmException::AUTHORIZATION.code)
          .sub(EdmException::ERROR, EdmException::PREVIEW_REQUIRED)
      end
    end

    # A slot added to the exception, and never in place of the one that is
    # there: the timestamp opens the only element these mutations can anchor on.
    def with_exception_slots(body, slots) = body.sub(slot_opening('Timestamp'), "#{slots}#{slot_opening('Timestamp')}")

    def slot_opening(name) = %(<rim:Slot name="#{name}">)

    def slot(name) = %r{<rim:Slot name="#{name}">.*?</rim:Slot>}m

    def exception_element = %r{<rs:Exception.*?</rs:Exception>}m

    # The agent each slot carries, told apart by where it sits and not by what
    # it holds: `\K` drops everything matched before it, so the block receives
    # the agent alone — the shape `Fixtures::PROVIDER_AGENT` has.
    def provider_agent = %r{<rim:Slot name="ErrorProvider">.*?\K<sdg:Agent>.*?</sdg:Agent>}m

    def requester_agent = %r{<rim:Slot name="EvidenceRequester">.*?\K<sdg:Agent>.*?</sdg:Agent>}m

    def named_slot(name)
      %(<rim:Slot name="#{name}"><rim:SlotValue xsi:type="rim:StringValueType"><rim:Value>x</rim:Value></rim:SlotValue></rim:Slot>)
    end

    def preview_location(address = 'https://apercu.example/espace')
      %(<rim:Slot name="PreviewLocation"><rim:SlotValue xsi:type="rim:StringValueType"><rim:Value>#{address}</rim:Value></rim:SlotValue></rim:Slot>)
    end

    def preview_description(language = 'FR')
      %(<rim:Slot name="PreviewDescription"><rim:SlotValue xsi:type="rim:InternationalStringValueType"><rim:Value><rim:LocalizedString xml:lang="#{language}" value="x"/></rim:Value></rim:SlotValue></rim:Slot>)
    end

    def preview_method_slot(verb = 'GET')
      %(<rim:Slot name="PreviewMethod"><rim:SlotValue xsi:type="rim:StringValueType"><rim:Value>#{verb}</rim:Value></rim:SlotValue></rim:Slot>)
    end
  end

  def envelope_with_preview(location)
    document = Nokogiri::XML(built_envelope('erreurAutorisationRequise'))
    value = document.xpath('//payload/value').first
    body = Base64.decode64(value.text).sub(/(<rim:Slot name="PreviewLocation">.*?<rim:Value>)[^<]*/m, "\\1#{location}")
    value.content = Base64.strict_encode64(body)

    document.to_xml
  end
end
