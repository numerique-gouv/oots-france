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

  # `R-EDM-REQ-C036` is FATAL, so a request omitting the level of assurance is
  # not one a correspondent may send — and the journal of article 17 records
  # the subject as it circulated, sex and place of birth included.
  describe 'the identity attributes the slot carries' do
    it 'reads the level of assurance the correspondent asserted' do
      expect(request.beneficiary.level_of_assurance).to eq('High')
    end

    it 'reads the sex and the place of birth when the request carries them' do
      complete = with_body do |body|
        body.sub('<sdg:DateOfBirth>1965-11-25</sdg:DateOfBirth>',
          '<sdg:DateOfBirth>1965-11-25</sdg:DateOfBirth>' \
          '<sdg:PlaceOfBirth>Aarhus</sdg:PlaceOfBirth><sdg:Gender>Female</sdg:Gender>')
      end

      expect(complete.beneficiary).to have_attributes(place_of_birth: 'Aarhus', gender: 'Female')
    end

    it 'refuses a request whose evidence subject declares no level of assurance' do
      amputated = with_body { |body| body.sub(%r{<sdg:LevelOfAssurance>.*?</sdg:LevelOfAssurance>}m, '') }

      expect { amputated.beneficiary }
        .to raise_error(UnreadableMessageError, /Le niveau de garantie/)
    end
  end

  # Two rules that read past the blanks around a value, and not the same blanks:
  # `R-EDM-REQ-C043` matches on `normalize-space(text())`, which trims both
  # ends, where `R-EDM-REQ-C040` carries no `^` but does carry a `$` — anything
  # may precede the identifier, nothing may follow it. So a date is trimmed on
  # both sides and an identifier on its head alone, and a trailing blank on the
  # latter is refused rather than absorbed.
  describe 'the values the rules judge after normalising them' do
    def identified_by(identifier)
      with_body do |body|
        body.sub('<sdg:FamilyName>',
          %(<sdg:Identifier schemeID="eidas">#{identifier}</sdg:Identifier><sdg:FamilyName>))
      end
    end

    def born_on(date)
      with_body do |body|
        body.sub(%r{<sdg:DateOfBirth>.*?</sdg:DateOfBirth>}m, "<sdg:DateOfBirth>#{date}</sdg:DateOfBirth>")
      end
    end

    it 'accepts a date of birth padded with blanks, and reads the trimmed value' do
      expect(born_on("\n    1978-09-09\n  ").beneficiary.date_of_birth).to eq('1978-09-09')
    end

    # The `$` of the rule excludes what the `xs:date` of the schema would admit:
    # a time zone is refused however well-typed it is.
    it 'refuses a date of birth carrying a time zone, which the rule excludes' do
      expect { born_on('1978-09-09Z').beneficiary }.to raise_error(UnreadableMessageError)
    end

    it 'accepts an eIDAS identifier written in lower case, and keeps the case received' do
      expect(identified_by('es/at/02635542Y').beneficiary.eidas_identifier).to eq('es/at/02635542Y')
    end

    it 'keeps the case of one written in upper case just as it was received' do
      expect(identified_by('ES/AT/02635542Y').beneficiary.eidas_identifier).to eq('ES/AT/02635542Y')
    end

    it 'reads an eIDAS identifier preceded by blanks stripped of them' do
      expect(identified_by(' ES/AT/02635542Y').beneficiary.eidas_identifier).to eq('ES/AT/02635542Y')
    end

    # The `$` of the rule anchors the end, so this value breaks `C040`, which is
    # FATAL. Accepting it would be the mirror of the over-strictness this whole
    # reading exists to undo.
    it 'refuses one followed by a blank, which the rule refuses' do
      expect { identified_by('ES/AT/02635542Y ').beneficiary }.to raise_error(UnreadableMessageError)
    end

    # The head anchor France keeps where the rule has none: an identifier
    # preceded by anything but blanks is asserted by no member state.
    it 'refuses an eIDAS identifier preceded by anything at all' do
      expect { identified_by('xxES/AT/02635542Y').beneficiary }.to raise_error(UnreadableMessageError)
    end

    # An element sent present and empty still breaks `R-EDM-REQ-C040`, which is
    # FATAL: stripping normalises what the rule normalises and licenses nothing
    # beyond it.
    it 'still refuses an identifier that arrived present and empty' do
      expect { identified_by('   ').beneficiary }.to raise_error(UnreadableMessageError)
    end
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

    # `R-EDM-REQ-C051` carries the same expression and the same `i` flag as
    # `C040`: the case of the country codes decides nothing on this subject
    # either, and `R-EDM-RESP-C035` echoes it back untouched.
    it 'accepts an identifier whose country codes are written in lower case' do
      lowered = about_an_organisation { |slot| slot.sub('FR/DE/A2635542Y', 'de/fr/123456789') }

      expect(lowered.beneficiary.eidas_identifier).to eq('de/fr/123456789')
    end

    it 'reads one preceded by blanks stripped of them' do
      preceded = about_an_organisation { |slot| slot.sub('FR/DE/A2635542Y', ' FR/DE/A2635542Y') }

      expect(preceded.beneficiary.eidas_identifier).to eq('FR/DE/A2635542Y')
    end

    # `C051` anchors its end exactly as `C040` does: France refuses on this
    # subject what it refuses on the other.
    it 'refuses one followed by a blank' do
      followed = about_an_organisation { |slot| slot.sub('FR/DE/A2635542Y', 'FR/DE/A2635542Y ') }

      expect { followed.beneficiary }.to raise_error(UnreadableMessageError)
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

  # `R-EDM-REQ-C032` counts `sdg:DistributedAs` and asks for one at least, so a
  # correspondent naming several is conformant and reading only the first would
  # silently refuse them. Chapter 4.5.1 §3.5 names the case for a second: « an
  # additional sdg:DistributedAs element may be used to request a human-readable
  # format … for the same sdg:DataServiceEvidenceType ».
  describe 'the distributions the request asks for' do
    def asking_for(*formats)
      distributions = formats.map do |format|
        "<sdg:DistributedAs><sdg:Format>#{format}</sdg:Format></sdg:DistributedAs>"
      end

      with_body { |body| body.sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m) { distributions.join } }
    end

    it 'reads the evidence type asked for, with its distribution format' do
      expect(request.evidence_type.id).to be_present
      expect(request.evidence_type.distribution_formats).to eq([EvidenceType::PDF])
    end

    it 'reads every distribution named, in the order the request wrote them' do
      expect(asking_for('application/xml', EvidenceType::PDF).evidence_type.distribution_formats)
        .to eq(['application/xml', EvidenceType::PDF])
    end

    # `EDM:ERR:0003` and not `EDM:ERR:0007`: the rule is FATAL, so a request
    # naming no distribution is invalid rather than demanding, and what the
    # correspondent gets back names the rule it broke.
    it 'refuses a request asking for no distribution at all, under R-EDM-REQ-C032' do
      expect { asking_for.evidence_type }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C032')))
    end

    # The rule counts the element and not the format inside it: a distribution
    # naming none keeps `C032`, so it is read as the silence it is rather than
    # refused under a rule it does not break.
    it 'keeps a distribution that names no format' do
      nameless = with_body do |body|
        body.sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m, '<sdg:DistributedAs/>')
      end

      expect(nameless.evidence_type.distribution_formats).to eq([nil])
    end
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

  # `R-EDM-REQ-C074` counts the agents classified `ER` and `R-EDM-REQ-S012` the
  # slot that carries them, both in `= 1`. Refused where the requester is read
  # and not among the checks of `validate!`: an `EDM:ERR:0003` names the
  # requester by copying it back, and neither a collection carrying two nor one
  # carrying none leaves an agent to name or to address. The reading has to fail
  # for the journal to record no requester either — a check standing beside
  # would let the first of two agents be logged as though it had been read.
  describe 'the count of requesting agents' do
    # Conformant by every rule the two of the real request satisfy, so that what
    # refuses it is the count and nothing else.
    let(:second_requester) do
      <<~XML
        <sdg:Agent>
          <sdg:Identifier schemeID="#{IdentifierScheme::UNREGISTERED_PREFIX}oots">AUTRE</sdg:Identifier>
          <sdg:Name lang="EN">Another requester</sdg:Name>
          <sdg:Address><sdg:AdminUnitLevel1>DE</sdg:AdminUnitLevel1></sdg:Address>
          <sdg:Classification>ER</sdg:Classification>
        </sdg:Agent>
      XML
    end

    it 'refuses a collection carrying two agents classified ER, under R-EDM-REQ-C074' do
      expect { with_third_agent(second_requester).requester }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C074')))
    end

    it 'refuses one carrying none at all, under the same rule' do
      demoted = with_body { |body| body.gsub('>ER<', '>IP<') }

      expect { demoted.requester }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C074')))
    end

    # `C074` compares raw — `sdg:Classification='ER'` — where `C073` normalises.
    # A second agent classified ` ER ` is therefore not a second requester: it is
    # one of the agents the requester is not, and `C014`, raw too, refuses it
    # with an answer. Both halves are asserted, a reader that normalised here
    # counting two requesters and refusing without answering.
    it 'does not count a classification padded with blanks, which C014 refuses' do
      padded = with_third_agent(second_requester.sub('>ER<', '> ER <'))

      expect(padded.requester.id).to eq('00000000000002')
      expect { padded.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C014')))
    end

    it 'refuses a request carrying no EvidenceRequester slot, under R-EDM-REQ-S012' do
      expect { without_requester_slot.requester }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S012')))
    end

    # `= 1` and not `>= 1`: two slots leave which one carries the requester
    # undecided, where `slot_elements` would silently read the first.
    it 'refuses one carrying the slot twice, under the same rule' do
      expect { with_doubled_requester_slot.requester }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S012')))
    end

    # `R-EDM-REQ-S039`, refused before `C074` counts anything: a collection
    # carrying no agent at all would otherwise be refused for having none
    # classified `ER`, which names a count of agents that are not there. The
    # refusal carries no answer either, for the reason `C074`'s carries none.
    it 'refuses a collection whose elements carry no agent, under R-EDM-REQ-S039' do
      expect { without_any_agent.requester }.to refusing('R-EDM-REQ-S039')
    end

    # The assertion, and not its message: the test is `rim:Element/sdg:Agent` on
    # the slot value, so one element carrying an agent satisfies it where the
    # message reads « each rim:Element … MUST use the 'sdg:Agent' ».
    it 'accepts an element carrying no agent beside one that does' do
      expect(with_third_agent('').validate!).to be_truthy
    end
  end

  # `R-EDM-REQ-C012`, `C092`, `C108` and `C109`, refused where the requester is
  # read rather than among the checks of `validate!`, because an `EDM:ERR:0003`
  # names the requester by copying back the very values these rules judge —
  # `R-EDM-ERR-C010`, `C027`, `C028` and `C029` are FATAL on each of them in
  # the answer. Nothing conformant can carry these refusals, so nothing goes
  # back and the journal holds them alone.
  describe 'the requesting agent an answer would have to name' do
    # `R-EDM-REQ-C011` asserts the attribute's presence and nothing more, so one
    # written empty satisfies it and falls to `C012`, which compares the value —
    # the shape `C041` and `C042` take on the beneficiary's identifier, and
    # `C017` and `C018` on the provider's. The absent element breaks neither,
    # the context of `C011` being the identifier itself: `AgentType` and chapter
    # 4.5.1 §3.2 are what require it, and the refusal names the chapter.
    describe 'the presence of its identifier' do
      it 'refuses an agent carrying no sdg:Identifier at all, under the chapter' do
        expect { without_requester_identifier.requester }.to raise_error(
          an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: AgentConformance::AGENT_IDENTIFIER_REQUIRED)),
        )
      end

      it 'refuses one carrying no schemeID, under R-EDM-REQ-C011' do
        expect { with_requester_scheme(nil).requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C011')))
      end

      it 'refuses an empty schemeID under R-EDM-REQ-C012, not C011' do
        expect { with_requester_scheme('').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      # No assertion refuses this one either: `C012` measures a length no value
      # is too short for. Naming the chapter here would impute a rule the
      # request does not break, so the refusal names none — and comes last, once
      # every rule that could have named one has passed.
      it 'refuses an identifier present and empty, naming no rule at all' do
        expect { with_requester_id('').requester }.to raise_error(
          an_instance_of(UnreadableMessageError).and(having_attributes(detail: nil)),
        )
      end

      # And that refusal comes last: an identifier both empty and naming no
      # scheme breaks `C011`, and a reader that judged the content first would
      # answer for it under no rule at all — losing the one identifier the
      # correspondent could have acted on.
      it 'names C011 on an identifier at once empty and without a scheme' do
        emptied = with_requester_agent { |agent| replace_scheme(replace_id(agent, ''), nil) }

        expect { emptied.requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C011')))
      end
    end

    describe 'the scheme of its identifier' do
      it 'accepts the EAS code the real request carries' do
        expect(request.requester.type_id).to eq('urn:cef.eu:names:identifier:EAS:0009')
      end

      it 'refuses an EAS code the list does not publish, under R-EDM-REQ-C012' do
        expect { with_requester_scheme('urn:cef.eu:names:identifier:EAS:9999').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      it 'refuses a scheme carrying neither prefix' do
        expect { with_requester_scheme('SIRET').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      it 'refuses a prefix followed by no code at all' do
        expect { with_requester_scheme('urn:cef.eu:names:identifier:EAS:').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      # The second branch compares exactly too, `substring-after` yielding the
      # code as written: a reader that upcased it would accept what the rule
      # refuses, on the branch where the codes are countries rather than digits.
      it 'refuses an unregistered country written in lower case' do
        expect { with_requester_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:de').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      # The second branch of the rule: a country of `OOTS_Country-CodeList`,
      # which is not the list `R-EDM-REQ-C015` compares an address to.
      it 'accepts an unregistered scheme naming an OOTS country' do
        expect(with_requester_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:DE').requester.type_id)
          .to eq('urn:oasis:names:tc:ebcore:partyid-type:unregistered:DE')
      end

      # « For testing purposes the code "oots" can be used », which the rule's
      # assertion admits as a third alternative and its table of prefixes does
      # not spell out.
      it 'accepts the literal `oots` the rule admits beside the country codes' do
        expect(with_requester_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots').requester.type_id)
          .to end_with(':oots')
      end

      # A country that is a `CountryIdentificationCode` and not an OOTS one:
      # the two lists must not be confused, this branch reading the shorter.
      it 'refuses an unregistered scheme naming a country outside OOTS' do
        expect { with_requester_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:JP').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end
    end

    # The other half of `R-EDM-REQ-C012`: `string-length(.)`, whose context is
    # `sdg:Identifier`, so the 256 characters are the identifier's and not the
    # scheme's — the prose says otherwise, and applied to the scheme the clause
    # would be dead, the comparison to a code being an exact one.
    describe 'the length of its identifier' do
      it 'accepts one of 255 characters' do
        expect(with_requester_id('9' * 255).requester.id.length).to eq(255)
      end

      it 'refuses one of 256, the rule asking for strictly less' do
        expect { with_requester_id('9' * 256).requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end
    end

    describe 'its name' do
      it 'refuses an agent carrying no name at all' do
        nameless = with_requester_agent { |agent| agent.sub(%r{<sdg:Name.*?</sdg:Name>}m, '') }

        expect { nameless.requester }.to raise_error(
          an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: AgentConformance::AGENT_NAME_REQUIRED)),
        )
      end

      # `R-EDM-REQ-C092` measures `normalize-space(.)` and asks for more than
      # one character, so a single letter and a letter between blanks fail
      # alike — and `R-EDM-ERR-C027` would refuse France's own answer for the
      # same reason.
      it 'refuses a name of one character, under R-EDM-REQ-C092' do
        expect { with_requester_name('R').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C092')))
      end

      it 'refuses one whose only character is padded with blanks' do
        expect { with_requester_name('  R  ').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C092')))
      end

      # The rule asks for `> 1`, so two characters pass and one does not. Pinned
      # at the boundary: the accepted name below is long enough that a reader
      # asking for three would still let it through.
      it 'accepts a name of exactly two characters' do
        expect(with_requester_name('AB').requester.name).to eq('AB')
      end

      it 'keeps a name exactly as it circulated, blanks included' do
        expect(with_requester_name('  Requêteur  ').requester.name).to eq('  Requêteur  ')
      end
    end

    describe 'the language of its name' do
      it 'refuses a name carrying no `lang`, under R-EDM-REQ-C109' do
        expect { with_requester_language(nil).requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C109')))
      end

      # The rule asserts `not(normalize-space(@lang)='')`, so an attribute
      # written empty and one written blank break it as surely as none at all.
      it 'refuses one written empty' do
        expect { with_requester_language('').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C109')))
      end

      it 'refuses one made of blanks alone' do
        expect { with_requester_language('   ').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C109')))
      end

      it 'refuses a code the list does not publish, under R-EDM-REQ-C108' do
        expect { with_requester_language('xx').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end

      # `.=$code` carries no `i` flag, where `R-EDM-REQ-C040` does, and the
      # list publishes upper case. Frozen here because it is the one place the
      # case of a code decides an exchange, and because France writes `FR` and
      # `EN` itself.
      it 'refuses a code written in lower case, the rule comparing exactly' do
        expect { with_requester_language('fr').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end

      # Padded, the value satisfies `C109`, which normalises, and fails `C108`,
      # which does not: the rule that names the refusal is the one that broke.
      it 'refuses a valid code surrounded by blanks, under R-EDM-REQ-C108' do
        expect { with_requester_language(' FR ').requester }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end

      it 'accepts a code the list publishes' do
        expect(with_requester_language('EN').requester.language).to eq('EN')
      end
    end
  end

  # `R-EDM-REQ-C073` and `C015`, refused among the checks of `validate!` and not
  # where the requester is read: `ErrorResponseBuilder#requester_agent` renders
  # neither address nor classification, so nothing of what is refused here
  # travels back inside the `EDM:ERR:0003` that says so.
  describe 'the country of the requesting agent' do
    it 'accepts the request a real gateway delivered' do
      expect(request.validate!).to be(request)
    end

    it 'refuses an agent declaring no address at all, under R-EDM-REQ-C073' do
      homeless = with_requester_agent { |agent| agent.sub(%r{<sdg:Address>.*?</sdg:Address>}m, '') }

      expect { homeless.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C073')))
    end

    # The rule counts the elements whose `normalize-space` is not empty, so one
    # written blank counts for none.
    it 'refuses one whose country element is blank' do
      blank = with_requester_country('   ')

      expect { blank.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C073')))
    end

    # `= 1` and not `>= 1`: two countries leave which one asks undecided, and
    # `AdminUnitLevel1` is where a received request names it at all.
    it 'refuses one declaring two countries' do
      doubled = with_requester_agent do |agent|
        agent.sub(%r{<sdg:AdminUnitLevel1>.*?</sdg:AdminUnitLevel1>}m) { |element| "#{element}#{element}" }
      end

      expect { doubled.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C073')))
    end

    # The rule counts what is left after the blank ones are dropped, so a blank
    # element beside a valid one still counts one and the request stands. This
    # is the case the filter exists for, and nothing else exercises it.
    it 'accepts a blank country element beside a valid one' do
      doubled = with_requester_agent do |agent|
        agent.sub('<sdg:AdminUnitLevel1>FR</sdg:AdminUnitLevel1>',
          '<sdg:AdminUnitLevel1>  </sdg:AdminUnitLevel1><sdg:AdminUnitLevel1>FR</sdg:AdminUnitLevel1>')
      end

      expect(doubled.validate!).to be_a(described_class)
    end

    it 'refuses a code the list does not publish, under R-EDM-REQ-C015' do
      expect { with_requester_country('ZZ').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C015')))
    end

    # The assertion is an `=` with no `i` flag, exactly as `C108`.
    it 'refuses one written in lower case' do
      expect { with_requester_country('fr').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C015')))
    end

    # The list codes Greece `EL` and not `GR`, following the Union's usage: a
    # reader that took ISO 3166-1 alpha-2 unamended would refuse a conformant
    # Greek requester.
    it 'accepts EL, which is how the list codes Greece' do
      expect(with_requester_country('EL').validate!).to be_a(described_class)
    end
  end

  # `R-EDM-REQ-C016`, the territory under the country. Its context is the
  # `sdg:AdminUnitLevel2` element, which the real request does not carry: what
  # requires an address is `C073`, and it asks for the country alone.
  describe 'the territory the requester declares' do
    it 'accepts a request declaring none, which is the one really received' do
      expect(request.validate!).to be(request)
    end

    it 'accepts a code the list publishes' do
      expect(with_requester_territory('FR101').validate!).to be_a(described_class)
    end

    it 'refuses a code it does not, under R-EDM-REQ-C016' do
      expect { with_requester_territory('FR999').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C016')))
    end

    # The assertion carries no `i` flag and no `normalize-space`, where `C073`
    # normalises the country beside it: a territory the list publishes is
    # refused as soon as it is written otherwise.
    it 'refuses a published code written in lower case' do
      expect { with_requester_territory('fr101').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C016')))
    end

    it 'refuses a published code written with spaces around it' do
      expect { with_requester_territory(' FR101 ').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C016')))
    end

    # Written empty, the element is there and is a context node: the assertion
    # fires, and the empty string is no code of the list. That separates it from
    # the element being absent, which the example opening this block serves.
    it 'refuses a territory element written empty, under R-EDM-REQ-C016' do
      expect { with_requester_territory('').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C016')))
    end
  end

  # `R-EDM-REQ-C041` and `C042`, whose context is the identifier itself: a
  # request naming no identifier for its beneficiary breaks neither, chapter 2.1
  # §2.3.1.2 providing for an identity established in the requester's own
  # country. Refused by `validate!` — the answer describes no evidence subject.
  describe 'the scheme of the beneficiary identifier' do
    it 'accepts a request carrying no identifier at all' do
      expect(request.validate!).to be(request)
    end

    it 'accepts one under the fixed value the rule names' do
      expect(with_beneficiary_identifier(' schemeID="eidas"').validate!).to be_a(described_class)
    end

    it 'refuses one naming no scheme, under R-EDM-REQ-C041' do
      expect { with_beneficiary_identifier('').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C041')))
    end

    # `C041` asserts the attribute's presence and nothing more, so an empty one
    # satisfies it and falls to `C042`, which compares the value: the refusal
    # names the rule that actually broke.
    it 'refuses one whose scheme is present and empty, under R-EDM-REQ-C042' do
      expect { with_beneficiary_identifier(' schemeID=""').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C042')))
    end

    # The message of `C042` says `eidas2` « can be used for testing purposes
    # until confirmation of provision of a suitable legal basis », and its
    # assertion admits nothing but `eidas`. France follows the assertion.
    it 'refuses eidas2, which the message admits and the assertion does not' do
      expect { with_beneficiary_identifier(' schemeID="eidas2"').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C042')))
    end

    # The rule fires per element, and the schema admits several: a reader that
    # judged only the first would serve a request the rule refuses.
    it 'refuses a second identifier the first one made look conformant' do
      several = with_beneficiary_identifier(' schemeID="eidas"') do |identifier|
        "#{identifier}<sdg:Identifier schemeID=\"eidas2\">FR/DE/A2635542Y</sdg:Identifier>"
      end

      expect { several.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C042')))
    end
  end

  # The three values `app/templates/evidence_response.v2_0.xml.erb` copies out
  # of the request into the answer France signs. Each is judged at the read by
  # the request rule that judges it, because a FATAL response rule judges it
  # again on the way out: answering a request that broke one would have France
  # sign a message breaking the other.
  describe 'the values the answer echoes' do
    # `R-EDM-REQ-C027` (FATAL), whose twin `R-EDM-RESP-C017` asserts the very
    # same expression over the `sdg:IsConformantTo` of the response.
    describe 'the classification of the evidence type' do
      it 'accepts the one the real request carries' do
        expect(request.validate!).to be(request)
      end

      it 'refuses a URL that is not the Semantic Repository, under R-EDM-REQ-C027' do
        expect { classified_as('https://example.org/types/abc').validate! }.to refusing('R-EDM-REQ-C027')
      end

      # `R-EDM-REQ-C115` judges the same element without the midfix and under
      # `CAUTION`, so an acceptance URL is refused by nothing.
      it 'accepts an environment midfix, C115 alone objecting and only as a caution' do
        acceptance = 'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/' \
                     'oots/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'

        expect(classified_as(acceptance).validate!).to be_a(described_class)
      end

      # The alternation of the rule adds `oots` to the country codes, « for
      # testing purposes and agreed OOTS data models ».
      it 'accepts oots where a country code would sit' do
        expect(classified_as(classification_for('oots')).validate!).to be_a(described_class)
      end

      it 'refuses a country the OOTS_Country code list does not publish' do
        expect { classified_as(classification_for('ZZ')).validate! }.to refusing('R-EDM-REQ-C027')
      end

      # The assertion carries no `i` flag, where `R-EDM-REQ-C019` on a provider
      # classification does: the hexadecimal is lower case or it is refused.
      it 'refuses a UUID written in upper case, the rule being case-sensitive' do
        expect { classified_as(classification_for('DE', uuid: 'CA8AFED6-2DC0-422A-A931-D21C3D8D370E')).validate! }
          .to refusing('R-EDM-REQ-C027')
      end

      # The assertion applies no `normalize-space` before matching, where
      # `R-EDM-REQ-C008` on a requirement identifier does: the two are read as
      # they are written, and this one refuses what it would otherwise trim.
      it 'refuses one padded with blanks, this assertion normalising nothing' do
        expect { classified_as(" #{classification_for('DE')} ").validate! }.to refusing('R-EDM-REQ-C027')
      end
    end

    # `R-EDM-REQ-C029` and `C028` (FATAL), the pair `R-EDM-RESP-C018` reads
    # again over the titles the response copies out.
    describe 'the language of the evidence type titles' do
      it 'refuses a title carrying no lang at all, under R-EDM-REQ-C029' do
        expect { titled('<sdg:Title>Certificate of Birth</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C029')
      end

      it 'refuses one whose lang is present and blank, under the same rule' do
        expect { titled('<sdg:Title lang="  ">Certificate of Birth</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C029')
      end

      it 'refuses a code the LanguageCode list does not publish, under R-EDM-REQ-C028' do
        expect { titled('<sdg:Title lang="xx">Certificate of Birth</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C028')
      end

      # The list publishes upper case and the assertion compares exactly, with
      # no `i` flag: a correspondent writing `fr` breaks a FATAL rule.
      it 'refuses a lower-case code, the comparison being exact' do
        expect { titled('<sdg:Title lang="fr">Acte de naissance</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C028')
      end

      it 'accepts the same code in upper case' do
        expect(titled('<sdg:Title lang="FR">Acte de naissance</sdg:Title>').validate!).to be_a(described_class)
      end

      # The context of both rules is the title and its attribute, and the schema
      # admits `1..n`: a reader judging the first alone would serve a request a
      # FATAL rule refuses.
      it 'refuses a second title the first one made look conformant' do
        several = titled('<sdg:Title lang="EN">Certificate of Birth</sdg:Title>',
          '<sdg:Title lang="xx">Acte de naissance</sdg:Title>')

        expect { several.validate! }.to refusing('R-EDM-REQ-C028')
      end

      it 'reads every title the request carries, keyed by the language it names' do
        several = titled('<sdg:Title lang="EN">Certificate of Birth</sdg:Title>',
          '<sdg:Title lang="FR">Acte de naissance</sdg:Title>')

        expect(several.evidence_type.descriptions)
          .to eq('EN' => 'Certificate of Birth', 'FR' => 'Acte de naissance')
      end
    end

    # No assertion counts the titles — `R-EDM-RESP-S030` bounds the children of
    # `sdg:IsConformantTo` without requiring one — so the floor is the table of
    # chapter 4.5.1 §3.5 and the XSD, and the refusal names them rather than a
    # rule that does not exist.
    describe 'an evidence type carrying no title at all' do
      it 'refuses it under the chapter, which is what gives Title 1..n' do
        expect { titled.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: a_string_starting_with('TDD 4.5.1 §3.5'))))
      end
    end

    # `R-EDM-REQ-C040` and `C051` (FATAL), whose twins `R-EDM-RESP-C028` and
    # `C035` judge the identifier the response copies under `sdg:IsAbout`.
    describe 'the country codes of the eIDAS identifier' do
      it 'accepts a request carrying no identifier at all, the context being the element' do
        expect(request.validate!).to be(request)
      end

      it 'refuses a country the OOTS_Country list does not publish, under R-EDM-REQ-C040' do
        expect { identified_as('ZZ/FR/02635542Y').validate! }.to refusing('R-EDM-REQ-C040')
      end

      it 'refuses one whose second code is unknown just as much as its first' do
        expect { identified_as('FR/ZZ/02635542Y').validate! }.to refusing('R-EDM-REQ-C040')
      end

      # The assertion carries the `i` flag, so lower case is conformant and
      # refusing it would cost an exchange the specification admits.
      it 'accepts codes written in lower case, the rule being case-insensitive' do
        expect(identified_as('es/at/02635542Y').validate!).to be_a(described_class)
      end

      it 'refuses the same unknown country on a legal person, under R-EDM-REQ-C051' do
        expect { about_an_organisation('DE/QQ/123456789').validate! }.to refusing('R-EDM-REQ-C051')
      end

      it 'accepts the identifier the organisation of the suite carries' do
        expect(about_an_organisation('FR/DE/A2635542Y').validate!).to be_a(described_class)
      end
    end

    # The classification of the real request, its country segment replaced:
    # everything else is what the correspondent actually sent.
    def classification_for(country, uuid: 'ca8afed6-2dc0-422a-a931-d21c3d8d370e')
      "https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/#{country}/#{uuid}"
    end

    def classified_as(value)
      with_body do |body|
        body.sub(/(<sdg:EvidenceTypeClassification>)[^<]*/) { "#{Regexp.last_match(1)}#{value}" }
      end
    end

    # Every title of the request at once, and not the first of them: the one a
    # real gateway delivered carries two, `FR` and `EN`. No title at all when
    # called with none — what the floor of chapter 4.5.1 §3.5 refuses.
    def titled(*titles)
      with_body { |body| body.sub(%r{<sdg:Title .*</sdg:Title>}m) { titles.join } }
    end

    # The real request carries no eIDAS identifier for its natural person:
    # `with_beneficiary_identifier` adds one under the scheme `C040`'s context
    # requires, and its block is where the value is chosen.
    def identified_as(identifier)
      with_beneficiary_identifier(' schemeID="eidas"') { |added| added.sub('FR/DE/A2635542Y', identifier) }
    end

    def about_an_organisation(identifier)
      envelope_about_an_organisation(legal_person_slot.sub('FR/DE/A2635542Y', identifier)).body
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
  end

  # `R-EDM-REQ-S001` and `S002`, whose common context is the document element.
  # Refused at the read, and the refusal carries no answer: a document that is
  # not a query request names no requester to address, no identifier to echo and
  # no version to answer in. The journal is its only trace, and what this pair
  # proves is that it names its rule there.
  describe 'the root element of the document' do
    it 'refuses a root that is not a QueryRequest, under R-EDM-REQ-S001' do
      expect { with_body { |body| body.gsub('query:QueryRequest', 'query:QueryResponse') } }
        .to refusing('R-EDM-REQ-S001')
    end

    # The local name is the one thing `S001` reads, so the namespace stays the
    # right one here and `S002` is the rule the next example reaches — swapping
    # the two predicates would show up in this pair and nowhere else.
    it 'refuses a QueryRequest of another namespace, under R-EDM-REQ-S002' do
      expect { with_body { |body| body.sub('urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0', 'urn:example:query') } }
        .to refusing('R-EDM-REQ-S002')
    end
  end

  # Chapter 4.6, on a request that is well formed and still not one France may
  # answer. Each refusal names the rule it applied, which is the whole of what
  # the correspondent will learn.
  describe 'the business rules it checks' do
    it 'accepts the request a real gateway delivered' do
      expect(request.validate!).to be(request)
    end

    # Both halves of every rule of the table: it counts the slot, so a request
    # omitting one and a request carrying it twice break it alike.
    EvidenceRequestParser::REQUIRED_SLOTS.each do |name, rule|
      it "refuses a request with no #{name} slot, under #{rule}" do
        expect { without_slot(name).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: rule)))
      end

      it "refuses a request carrying the #{name} slot twice, under #{rule}" do
        expect { with_doubled_slot(name).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: rule)))
      end
    end

    # The one slot the chapter counts among the children of `query:Query` and
    # not among those of `query:QueryRequest`, which is why it sits outside the
    # table above: counted in the wrong scope, the rule would fire on every
    # request at all.
    it 'refuses a request whose query carries no EvidenceRequest slot, under R-EDM-REQ-S015' do
      expect { without_evidence_request.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S015')))
    end

    it 'refuses one carrying it twice, under the same rule' do
      expect { with_doubled_evidence_request.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S015')))
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

  # Chapter 4.6 again, on the agents of the `EvidenceRequester` collection the
  # requester is not — the intermediary platform of the country that asks. Eight
  # FATAL rules judge them, no context naming a classification, and these
  # refusals do go back: an error response names the requester alone.
  describe 'the agents beside the requester' do
    it 'accepts the platform the real request carries' do
      expect(request.validate!).to be(request)
    end

    describe 'its classification' do
      # `R-EDM-REQ-C013` normalises before asking that it not be empty, so an
      # absent element and a blank one break it alike.
      it 'refuses an agent carrying none, under R-EDM-REQ-C013' do
        expect { with_platform_classification(nil).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C013')))
      end

      it 'refuses one written blank, the rule normalising it' do
        expect { with_platform_classification('   ').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C013')))
      end

      # `C014` compares to the `AgentClassification` list deprived of `EP` and
      # `ERRP`, which its own message forbids this transaction.
      it 'refuses EP, which the code list publishes and the rule excludes' do
        expect { with_platform_classification('EP').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C014')))
      end

      it 'refuses ERRP, excluded by the same clause' do
        expect { with_platform_classification('ERRP').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C014')))
      end

      # `C013` normalises and `C014` does not: the two are told apart by a value
      # the first accepts and the second refuses.
      it 'refuses a padded IP, C013 normalising where C014 compares raw' do
        expect { with_platform_classification(' IP ').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C014')))
      end
    end

    describe 'its identifier' do
      # `C011` asserts the attribute's presence and nothing more.
      it 'refuses one naming no scheme, under R-EDM-REQ-C011' do
        expect { with_platform_scheme(nil).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C011')))
      end

      # Present and empty satisfies `C011` and falls to `C012`, which compares
      # the value — the shape `C041` and `C042` take on the beneficiary.
      it 'refuses an empty scheme under R-EDM-REQ-C012, not C011' do
        expect { with_platform_scheme('').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      it 'refuses a scheme naming no published EAS code, under R-EDM-REQ-C012' do
        expect { with_platform_scheme("#{IdentifierScheme::EAS_PREFIX}9999").validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      # The rule counts on the identifier, its context, and not on the scheme
      # its prose names.
      it 'refuses an identifier of 256 characters, under R-EDM-REQ-C012' do
        expect { with_platform_id('X' * AgentConformance::MAXIMUM_IDENTIFIER_LENGTH).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C012')))
      end

      # The rule reads `string-length(.) < 256`, so 255 passes where 256 does
      # not: both halves of the boundary, as the requester's own specs carry.
      it 'accepts an identifier of 255 characters' do
        expect(with_platform_id('X' * (AgentConformance::MAXIMUM_IDENTIFIER_LENGTH - 1)).validate!).to be_truthy
      end

      it 'accepts the literal oots scheme the rule admits for testing' do
        expect(with_platform_scheme("#{IdentifierScheme::UNREGISTERED_PREFIX}oots").validate!).to be_truthy
      end

      # No assertion carries this absence, both contexts being the element
      # itself; `AgentType` requires it, so the refusal names the chapter.
      it 'refuses an agent carrying no identifier at all' do
        expect { without_platform_identifier.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: AgentConformance::AGENT_IDENTIFIER_REQUIRED)))
      end
    end

    describe 'its name' do
      it 'refuses one of a single character, under R-EDM-REQ-C092' do
        expect { with_platform_name('A').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C092')))
      end

      it 'refuses an agent carrying no name at all' do
        expect { without_platform_name.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: AgentConformance::AGENT_NAME_REQUIRED)))
      end

      it 'refuses a name without a lang attribute, under R-EDM-REQ-C109' do
        expect { with_platform_language(nil).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C109')))
      end

      # `C108` compares to the code list, which publishes upper case, and its
      # assertion carries no `i` flag.
      it 'refuses a lang in lower case, under R-EDM-REQ-C108' do
        expect { with_platform_language('en').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end

      # The value that separates the two rules: `C109` normalises, so a padded
      # attribute satisfies it, and `C108` compares raw, so it does not.
      it 'refuses a padded lang under R-EDM-REQ-C108, C109 normalising it' do
        expect { with_platform_language(' FR ').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end

      # `AgentType` makes `sdg:Name` `1..n`, and the contexts of `C092`, `C109`
      # and `C108` are the name element and its attribute: a reader judging the
      # first alone would serve a request three FATAL rules refuse.
      it 'refuses a second name the first one made look conformant' do
        expect { with_second_platform_name('<sdg:Name lang="FR">A</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C092')))
      end

      it 'refuses a second name whose lang is unpublished' do
        expect { with_second_platform_name('<sdg:Name lang="en">Plateforme</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end
    end

    describe 'its address' do
      # `C073` is what requires an address, and it narrows itself to the agent
      # classified `ER`. The platform of the real request carries none, which
      # the example opening this block already serves; one carrying an address
      # that names no country breaks nothing either, `C015`'s context being the
      # `sdg:AdminUnitLevel1` that is not there.
      it 'accepts an address naming no country' do
        expect(with_platform_address('<sdg:Address/>').validate!).to be_truthy
      end

      it 'accepts a country the code list publishes' do
        expect(with_platform_country('DE').validate!).to be_truthy
      end

      it 'refuses one it does not, under R-EDM-REQ-C015' do
        expect { with_platform_country('ZZ').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C015')))
      end

      # The rule compares exactly, its assertion being an `=` with no `i` flag.
      it 'refuses a country written in lower case' do
        expect { with_platform_country('de').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C015')))
      end

      # `R-EDM-REQ-C016` names no classification either, so the territory of
      # every agent of the collection is judged and not the requester's alone.
      it 'accepts a territory the code list publishes' do
        expect(with_platform_territory('DE300').validate!).to be_truthy
      end

      it 'refuses one it does not, under R-EDM-REQ-C016' do
        expect { with_platform_territory('DE999').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C016')))
      end
    end

    # The walk judges each of the agents the requester is not: the real request
    # carries a single one, so a third is added to tell `each` from `find`.
    describe 'a third agent in the collection' do
      let(:conformant) do
        <<~XML
          <sdg:Agent>
            <sdg:Identifier schemeID="#{IdentifierScheme::UNREGISTERED_PREFIX}oots">AUTRE</sdg:Identifier>
            <sdg:Name lang="EN">Another platform</sdg:Name>
            <sdg:Classification>IP</sdg:Classification>
          </sdg:Agent>
        XML
      end

      it 'accepts one the rules admit' do
        expect(with_third_agent(conformant).validate!).to be_truthy
      end

      it 'refuses one the two before it made look conformant' do
        expect { with_third_agent(conformant.sub('lang="EN"', 'lang="en"')).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C108')))
      end

      # The same proof for `C016`: the requester and the platform before it
      # declare a conformant territory or none at all, so a reader stopping at
      # the first agent would serve this one unexamined.
      it 'refuses one whose territory alone breaks C016' do
        addressed = conformant.sub('<sdg:Classification>',
          '<sdg:Address><sdg:AdminUnitLevel2>ZZ999</sdg:AdminUnitLevel2></sdg:Address><sdg:Classification>')

        expect { with_third_agent(addressed).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C016')))
      end
    end

    # The traversal selects the agents the requester is not, so what OOTS-190
    # left silent on the `ER` stays silent: `validate!` says nothing of its
    # scheme, its name or the language of that name, which an error response
    # would have to copy back.
    describe 'what it leaves to the requester' do
      it 'says nothing of a requesting agent whose name breaks C092' do
        expect(with_requester_name('A').validate!).to be_truthy
      end

      it 'says nothing of a requesting agent whose lang breaks C108' do
        expect(with_requester_language('en').validate!).to be_truthy
      end

      it 'says nothing of a requesting agent whose scheme breaks C012' do
        expect(with_requester_scheme("#{IdentifierScheme::EAS_PREFIX}9999").validate!).to be_truthy
      end
    end

    # `R-EDM-REQ-S040` closes the list of what any agent of the collection may
    # carry — `sdg:Identifier`, `sdg:Name`, `sdg:Address`, `sdg:Classification`
    # and nothing else. Its context is every `sdg:Agent` of the collection, the
    # requester included: it names no classification, where `C073` alone does.
    # The same assertion `S043` makes over the provider, on four names instead
    # of two.
    describe 'the elements an agent of the collection carries' do
      it 'refuses a requester carrying an sdg:ReferenceFramework, under R-EDM-REQ-S040' do
        framed = with_requester_agent { |agent| agent_carrying(agent, '<sdg:ReferenceFramework>x</sdg:ReferenceFramework>') }

        expect { framed.validate! }.to refusing('R-EDM-REQ-S040')
      end

      it 'refuses a platform carrying an sdg:EvidenceTypeList, under the same rule' do
        listed = with_platform_agent { |agent| agent_carrying(agent, '<sdg:EvidenceTypeList/>') }

        expect { listed.validate! }.to refusing('R-EDM-REQ-S040')
      end

      # The namespace is decided by its URI and never by the local name: an
      # `Identifier` of another namespace is not one of the four admitted.
      it 'refuses an admitted name borne by another namespace' do
        foreign = with_platform_agent do |agent|
          agent_carrying(agent, '<x:Identifier xmlns:x="http://example.org/sdg">AUTRE</x:Identifier>')
        end

        expect { foreign.validate! }.to refusing('R-EDM-REQ-S040')
      end

      # Only the names are closed, not how many of each: the assertion counts
      # them all on its left side, and `AgentType` makes `sdg:Name` `1..n`.
      it 'accepts a requester carrying a second name beside its address' do
        bilingual = with_second_requester_name('<sdg:Name lang="EN">French requester</sdg:Name>')

        expect(bilingual.validate!).to be(bilingual)
      end
    end
  end

  # Chapter 4.6 on the agent the `EvidenceProvider` slot carries — the provider
  # the request designates. Five FATAL rules judge it — `S013` counts the slot
  # and is exercised with the other slots of `REQUIRED_SLOTS` — and four of them,
  # `C017`, `C018`, `C111` and `C110`, are word for word the assertions the
  # requesting collection publishes as `C011`, `C012`, `C109` and `C108`. These
  # refusals all go back: an error response names France as the provider, never
  # the one that was received.
  describe 'the designated provider' do
    it 'accepts the one the real request carries' do
      expect(request.validate!).to be(request)
    end

    it 'refuses a slot whose value carries no agent, under R-EDM-REQ-S042' do
      expect { without_provider_agent.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S042')))
    end

    describe 'its identifier' do
      # `C017` asserts the attribute's presence and nothing more — the shape
      # `C011` takes on the requesting collection.
      it 'refuses one naming no scheme, under R-EDM-REQ-C017' do
        expect { with_provider_scheme(nil).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C017')))
      end

      it 'refuses an empty scheme under R-EDM-REQ-C018, not C017' do
        expect { with_provider_scheme('').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C018')))
      end

      it 'refuses a scheme naming no published EAS code, under R-EDM-REQ-C018' do
        expect { with_provider_scheme("#{IdentifierScheme::EAS_PREFIX}9999").validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C018')))
      end

      # `C018` counts on the identifier, its context, and not on the scheme its
      # prose names — the wording `C012` carries too.
      it 'refuses an identifier of 256 characters, under R-EDM-REQ-C018' do
        expect { with_provider_id('X' * AgentConformance::MAXIMUM_IDENTIFIER_LENGTH).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C018')))
      end

      it 'accepts an identifier of 255 characters, the rule reading `< 256`' do
        expect(with_provider_id('X' * (AgentConformance::MAXIMUM_IDENTIFIER_LENGTH - 1)).validate!).to be_truthy
      end

      # The other prefix of the rule: the real request is under
      # `unregistered:oots`, which the opening example already proves accepted,
      # so the case worth writing is the one the fixture does not carry.
      it 'accepts a published EAS code' do
        expect(with_provider_scheme("#{IdentifierScheme::EAS_PREFIX}9930").validate!).to be_truthy
      end

      # No assertion carries this absence, `C017`'s context being the element
      # itself; chapter 4.5.1 §3.3 requires it, so the refusal names it.
      it 'refuses a provider carrying no identifier at all' do
        expect { without_provider_identifier.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: AgentConformance::PROVIDER_IDENTIFIER_REQUIRED)))
      end
    end

    describe 'its name' do
      it 'refuses a provider carrying no name at all' do
        expect { without_provider_name.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: AgentConformance::PROVIDER_NAME_REQUIRED)))
      end

      it 'refuses a name without a lang attribute, under R-EDM-REQ-C111' do
        expect { with_provider_language(nil).validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C111')))
      end

      # `C111` normalises before asking that the attribute not be empty, so one
      # written blank breaks it as much as one absent.
      it 'refuses a lang written blank, the rule normalising it' do
        expect { with_provider_language(' ').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C111')))
      end

      # `C110` compares to the code list, which publishes upper case, and its
      # assertion carries no `i` flag.
      it 'refuses a lang in lower case, under R-EDM-REQ-C110' do
        expect { with_provider_language('en').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C110')))
      end

      # The value that separates the two rules: `C111` normalises, so a padded
      # attribute satisfies it, and `C110` compares raw, so it does not.
      it 'refuses a padded lang under R-EDM-REQ-C110, C111 normalising it' do
        expect { with_provider_language(' FR ').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C110')))
      end

      # `AgentType` makes `sdg:Name` `1..n`, and the contexts of `C111` and
      # `C110` are the name element and its attribute: a reader judging the
      # first alone would serve a request two FATAL rules refuse.
      it 'refuses a second name the first one made look conformant' do
        expect { with_second_provider_name('<sdg:Name lang="en">Fournisseur</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C110')))
      end

      # `R-EDM-REQ-C092` reaches this name too, its context naming `sdg:Name`
      # and no ancestor. The sentence is the provider's own rather than the one
      # the walk over the document says, so that the journal names which agent
      # was refused.
      # Le message, et pas seulement le `detail` : la marche transverse sur les
      # libellés rend le même identifiant, et seule la phrase dit lequel des deux
      # lecteurs a joué — c'est tout l'intérêt d'en donner une propre au
      # fournisseur.
      it 'refuses one of a single character, under R-EDM-REQ-C092' do
        expect { with_provider_name('F').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C092', message: /Le nom du fournisseur désigné/)))
      end
    end

    # `R-EDM-REQ-S043` closes the list of what the designated provider may
    # carry: `count(sdg:Identifier) + count(sdg:Name) = count(child::*)`. Its
    # context is each `sdg:Agent` of the slot value, and it counts none of them.
    describe 'the elements the provider carries' do
      def carrying(element)
        with_provider_agent { |agent| agent.sub('</sdg:Name>') { "</sdg:Name>#{element}" } }
      end

      it 'refuses one carrying an sdg:Classification, under R-EDM-REQ-S043' do
        expect { carrying('<sdg:Classification>EP</sdg:Classification>').validate! }.to refusing('R-EDM-REQ-S043')
      end

      # An address is what `R-EDM-REQ-C073` requires of the agent classified
      # `ER`, and what this one may not carry at all.
      it 'refuses one carrying an sdg:Address' do
        address = '<sdg:Address><sdg:AdminUnitLevel1>SI</sdg:AdminUnitLevel1></sdg:Address>'

        expect { carrying(address).validate! }.to refusing('R-EDM-REQ-S043')
      end

      # Only the names are closed, not how many of each: `AgentType` makes
      # `sdg:Name` `1..n`, and the assertion counts them all on its left side.
      it 'accepts one carrying an identifier and two names' do
        bilingual = carrying('<sdg:Name lang="EN">Test provider</sdg:Name>')

        expect(bilingual.validate!).to be(bilingual)
      end

      # `S042` asserts one agent and nothing refuses a second, which the reader
      # never designates: this rule is where that second one is judged.
      it 'judges a second agent of the same slot value' do
        doubled = beside_the_provider(classification: '<sdg:Classification>EP</sdg:Classification>')

        expect { doubled.validate! }.to refusing('R-EDM-REQ-S043')
      end
    end

    # The agents of the slot the request does not designate. `C017`, `C018`,
    # `C111` and `C110` carry no positional predicate in their contexts —
    # `…/rim:SlotValue/sdg:Agent/sdg:Identifier`, `…/sdg:Name` and its `@lang` —
    # so they reach these as much as the first, and a reader judging the first
    # alone would serve a request four FATAL rules refuse.
    describe 'the agents the slot carries beside it' do
      it 'accepts a conformant second agent' do
        expect(beside_the_provider.validate!).to be_truthy
      end

      # Which one the reader designates, said by a refusal: chapter 4.5.1 §3.3
      # requires an identifier of the agent the slot designates, and the second
      # carrying one changes nothing.
      it 'designates the first agent, whatever the second carries' do
        beheaded = beside_the_provider { |agent| remove_identifier(agent) }

        expect { beheaded.validate! }.to raise_error(an_instance_of(UnreadableMessageError)
          .and(having_attributes(detail: AgentConformance::PROVIDER_IDENTIFIER_REQUIRED)))
      end

      it 'refuses a second identifier naming no scheme, under R-EDM-REQ-C017' do
        expect { beside_the_provider(identifier: '<sdg:Identifier>AUTRE</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C017')
      end

      it 'refuses a second scheme of no published list, under R-EDM-REQ-C018' do
        expect { beside_the_provider(identifier: '<sdg:Identifier schemeID="SIRET">AUTRE</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C018')
      end

      it 'refuses a second name without a lang attribute, under R-EDM-REQ-C111' do
        expect { beside_the_provider(name: '<sdg:Name>Another provider</sdg:Name>').validate! }
          .to refusing('R-EDM-REQ-C111')
      end

      it 'refuses a second lang the list does not publish, under R-EDM-REQ-C110' do
        expect { beside_the_provider(name: '<sdg:Name lang="fr">Un autre fournisseur</sdg:Name>').validate! }
          .to refusing('R-EDM-REQ-C110')
      end

      # The sentence, and not only the `detail`: a second agent is not the one
      # the request designates, and a refusal saying it were would send the
      # correspondent looking at the wrong agent.
      it 'names the agent it refuses as one the request does not designate' do
        expect { beside_the_provider(name: '<sdg:Name>Another provider</sdg:Name>').validate! }
          .to raise_error(UnreadableMessageError, /ne désigne pas/)
      end

      # Nothing requires a second agent to carry an identifier or a name: no
      # assertion says so, and chapter 4.5.1 §3.3 describes the agent the slot
      # designates.
      it 'requires neither an identifier nor a name of it' do
        bare = beside_the_provider(identifier: '', name: '')

        expect(bare.validate!).to be_truthy
      end

      # RG19 again, on the other half of the ticket: the four assertions are
      # published word for word at 1.2.5 too, `C018` differing only by the name
      # of the country list it compares to.
      it 'judges a second agent of the 1.2 line by the very same rule' do
        earlier = earlier_line_envelope do |body|
          body.sub(Fixtures::PROVIDER_AGENT) { |agent| agent + second_provider_agent(identifier: '<sdg:Identifier>AUTRE</sdg:Identifier>') }
        end

        expect { earlier.body.validate! }.to refusing('R-EDM-REQ-C017')
      end
    end
  end

  # The four people a request describes — the subject and its representative,
  # natural or legal — judged by one battery of rules published four times over.
  # None of these values is read for anything but the refusal: France models
  # neither the representative nor the address of a subject.
  describe 'the people the request describes' do
    # Written into the reference request, which names none: every context here
    # is an element of a slot that is *there*, so an absent representative
    # triggers nothing at all.
    def representing(content, name: 'AuthorizedRepresentative', element: 'sdg:Person')
      written = "<rim:Slot name=\"#{name}\"><rim:SlotValue xsi:type=\"rim:AnyValueType\">" \
                "<#{element}>#{content}</#{element}></rim:SlotValue></rim:Slot>"

      with_body { |body| body.sub('<rim:Slot name="NaturalPerson">') { "#{written}<rim:Slot name=\"NaturalPerson\">" } }
    end

    # The least a representative may be and still break no rule: `C058` asks for
    # the level of assurance, and nothing else is required of a person carrying
    # no identifier — `C060`, which would ask for its value, is `WARNING`.
    def represented_by(extra = '') = representing("<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>#{extra}")

    def organisation_representing(extra = '')
      representing('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>' \
                   "<sdg:LegalPersonIdentifier schemeID=\"eidas\">SI/SI/123456</sdg:LegalPersonIdentifier>#{extra}",
        name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')
    end

    # Written into the `sdg:Person` the reference request already names.
    def subject_carrying(extra)
      with_body { |body| body.sub('</sdg:Person>') { "#{extra}</sdg:Person>" } }
    end

    # And the organisation subject, which the reference request does not name:
    # `Fixtures#legal_person_slot` is the conformant one the rest of this file
    # reads, so what an example changes in it is the only thing under test.
    def about_an_organisation(&) = envelope_about_an_organisation(legal_person_slot.then(&)).body

    it 'serves a request naming no representative at all, as the reference one does' do
      expect(request.validate!).to be(request)
    end

    it 'serves one naming a representative that breaks nothing' do
      written = represented_by

      expect(written.validate!).to be(written)
    end

    # The ten country codes, one assertion under ten identifiers — every row of
    # the table, refused and accepted. A row nothing exercises is a row that
    # could name the wrong rule, or point at the wrong element, without anything
    # saying so.
    describe 'the country codes each of them names' do
      def carrying(person, written)
        case person
        when :subject then subject_carrying(written)
        when :legal_subject then about_an_organisation { |slot| slot.sub('</sdg:LegalPerson>') { "#{written}</sdg:LegalPerson>" } }
        when :representative then represented_by(written)
        else organisation_representing(written)
        end
      end

      {
        'R-EDM-REQ-C045' => [:subject, '<sdg:CurrentAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:CurrentAddress>'],
        'R-EDM-REQ-C075' => [:subject, '<sdg:Nationality>%s</sdg:Nationality>'],
        'R-EDM-REQ-C076' => [:subject, '<sdg:CountryOfBirth>%s</sdg:CountryOfBirth>'],
        'R-EDM-REQ-C077' => [:subject, '<sdg:CountryOfResidence>%s</sdg:CountryOfResidence>'],
        'R-EDM-REQ-C056' => [:legal_subject,
                             '<sdg:RegisteredAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:RegisteredAddress>'],
        'R-EDM-REQ-C067' => [:representative,
                             '<sdg:CurrentAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:CurrentAddress>'],
        'R-EDM-REQ-C078' => [:representative, '<sdg:Nationality>%s</sdg:Nationality>'],
        'R-EDM-REQ-C079' => [:representative, '<sdg:CountryOfBirth>%s</sdg:CountryOfBirth>'],
        'R-EDM-REQ-C080' => [:representative, '<sdg:CountryOfResidence>%s</sdg:CountryOfResidence>'],
        # The one row whose element the schema does not admit where the rule
        # looks for it: `sdg:LegalPerson` gets an `sdg:RegisteredAddress` and no
        # `sdg:CurrentAddress`. Transcribed to the letter all the same, so the
        # request that reaches it is one no schema-valid correspondent sends.
        'R-EDM-REQ-C090' => [:legal_representative,
                             '<sdg:CurrentAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:CurrentAddress>'],
      }.each do |rule, (person, written)|
        it "refuses a code the list does not publish, under #{rule}" do
          expect { carrying(person, format(written, 'ZZ')).validate! }.to refusing(rule)
        end

        # Compared exactly, the assertion carrying no `i` flag: the refusal
        # above would pass just as well if the reader accepted nothing at all,
        # and this is what says otherwise.
        it "accepts a published code in the same place, for #{rule}" do
          accepted = carrying(person, format(written, 'SI'))

          expect(accepted.validate!).to be(accepted)
        end
      end
    end

    describe 'the level of assurance each of them declares' do
      it 'refuses a representative carrying none, under R-EDM-REQ-C058' do
        expect { representing('<sdg:FamilyName>Novak</sdg:FamilyName>').validate! }
          .to refusing('R-EDM-REQ-C058')
      end

      it 'refuses one outside the LoA list, under R-EDM-REQ-C059' do
        expect { representing('<sdg:LevelOfAssurance>Medium</sdg:LevelOfAssurance>').validate! }
          .to refusing('R-EDM-REQ-C059')
      end

      it 'refuses an organisation subject carrying none, under R-EDM-REQ-C047' do
        stripped = about_an_organisation { |slot| slot.sub(%r{<sdg:LevelOfAssurance>.*?</sdg:LevelOfAssurance>}, '') }

        expect { stripped.validate! }.to refusing('R-EDM-REQ-C047')
      end

      it 'refuses one outside the list, under R-EDM-REQ-C048' do
        lowered = about_an_organisation { |slot| slot.sub('<sdg:LevelOfAssurance>High', '<sdg:LevelOfAssurance>Medium') }

        expect { lowered.validate! }.to refusing('R-EDM-REQ-C048')
      end
    end

    describe 'the scheme each identifier names' do
      it 'refuses an organisation subject whose identifier names none, under R-EDM-REQ-C052' do
        stripped = about_an_organisation { |slot| slot.sub(' schemeID="eidas"', '') }

        expect { stripped.validate! }.to refusing('R-EDM-REQ-C052')
      end

      it 'refuses one naming another scheme, under R-EDM-REQ-C053' do
        other = about_an_organisation { |slot| slot.sub('schemeID="eidas"', 'schemeID="eidas2"') }

        expect { other.validate! }.to refusing('R-EDM-REQ-C053')
      end

      # And the same pair on the representative, under its own identifiers.
      it 'refuses a representative identifier naming no scheme at all, under R-EDM-REQ-C062' do
        expect { represented_by('<sdg:Identifier>SI/SI/123456</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C062')
      end

      it 'refuses a representative naming another scheme, under R-EDM-REQ-C063' do
        expect { represented_by('<sdg:Identifier schemeID="eidas2">SI/SI/123456</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C063')
      end

      # Which is what empties the `eidas2` branch: `C121`, `C122`, `C123`, `C125`
      # and `C127` narrow their contexts to a representative identified under
      # that very scheme, so none of them is ever reached. The `detail` carries
      # one rule, and this is what proves it is always this one — a
      # representative breaking every rule of that branch at once is refused by
      # `C063` and named by nothing else.
      it 'never names a rule of the eidas2 branch, whose context lies past that refusal' do
        eidas2 = represented_by('<sdg:Identifier schemeID="eidas2">pas-un-identifiant</sdg:Identifier>' \
                                '<sdg:LevelOfAssurance>Low</sdg:LevelOfAssurance>')

        expect { eidas2.validate! }.to refusing('R-EDM-REQ-C063')
      end
    end

    # The legal representative's chain, jumelle for jumelle of the legal
    # subject's: level of assurance, then the scheme of its eIDAS identifier.
    describe 'the organisation representing the subject' do
      def carrying(written)
        representing("<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>#{written}",
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')
      end

      it 'refuses one carrying no level of assurance, under R-EDM-REQ-C082' do
        written = representing('<sdg:LegalPersonIdentifier schemeID="eidas">SI/SI/123456</sdg:LegalPersonIdentifier>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C082')
      end

      it 'refuses one outside the LoA list, under R-EDM-REQ-C083' do
        written = representing('<sdg:LevelOfAssurance>Medium</sdg:LevelOfAssurance>' \
                               '<sdg:LegalPersonIdentifier schemeID="eidas">SI/SI/123456</sdg:LegalPersonIdentifier>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C083')
      end

      it 'refuses an identifier naming no scheme, under R-EDM-REQ-C086' do
        expect { carrying('<sdg:LegalPersonIdentifier>SI/SI/123456</sdg:LegalPersonIdentifier>').validate! }
          .to refusing('R-EDM-REQ-C086')
      end

      it 'refuses one naming another scheme, under R-EDM-REQ-C087' do
        expect { carrying('<sdg:LegalPersonIdentifier schemeID="eidas2">SI/SI/123456</sdg:LegalPersonIdentifier>').validate! }
          .to refusing('R-EDM-REQ-C087')
      end

      it 'serves one that breaks none of the four' do
        written = organisation_representing

        expect(written.validate!).to be(written)
      end
    end

    describe 'the shape of an eIDAS identifier' do
      it 'refuses a representative whose country codes are not published, under R-EDM-REQ-C061' do
        expect { represented_by('<sdg:Identifier schemeID="eidas">ZZ/FR/123456</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C061')
      end

      it 'refuses an organisation representative under R-EDM-REQ-C085' do
        written = representing('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>' \
                               '<sdg:LegalPersonIdentifier schemeID="eidas">ZZ/FR/123456</sdg:LegalPersonIdentifier>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C085')
      end

      # The accept half of `C061`, `C062`, `C063` and `C126` at once: a
      # representative identified under `eidas`, with country codes the list
      # publishes and a sex the eIDAS profile admits, is served.
      it 'serves a representative whose eIDAS identifier is well formed' do
        written = represented_by('<sdg:Identifier schemeID="eidas">SI/SI/123456</sdg:Identifier>' \
                                 '<sdg:Gender>Female</sdg:Gender>')

        expect(written.validate!).to be(written)
      end

      it 'refuses an organisation representative carrying no identifier, under R-EDM-REQ-C084' do
        written = representing('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C084')
      end
    end

    describe 'the optional identifiers of an organisation representative' do
      it 'refuses one naming no scheme, under R-EDM-REQ-C088' do
        expect { organisation_representing('<sdg:Identifier>FR12345678901</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C088')
      end

      # A SIRET identifies an agent of the exchange and never the subject of an
      # evidence: the `IdentifierSchemes` list does not publish it.
      it 'refuses one naming a scheme the list does not publish, under R-EDM-REQ-C089' do
        expect { organisation_representing('<sdg:Identifier schemeID="SIRET">00000000000002</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C089')
      end

      it 'accepts one the list does publish' do
        written = organisation_representing('<sdg:Identifier schemeID="VAT">FR12345678901</sdg:Identifier>')

        expect(written.validate!).to be(written)
      end
    end

    describe 'the date of birth of a representative' do
      it 'refuses one that is not a date, under R-EDM-REQ-C064' do
        expect { represented_by('<sdg:DateOfBirth>hier</sdg:DateOfBirth>').validate! }
          .to refusing('R-EDM-REQ-C064')
      end

      # Anchored at both ends, where `C002` is anchored at neither.
      it 'refuses a timestamp where a date is asked for' do
        expect { represented_by('<sdg:DateOfBirth>1980-01-01T00:00:00Z</sdg:DateOfBirth>').validate! }
          .to refusing('R-EDM-REQ-C064')
      end

      it 'accepts a date written as the rule asks' do
        written = represented_by('<sdg:DateOfBirth>1980-01-01</sdg:DateOfBirth>')

        expect(written.validate!).to be(written)
      end
    end

    describe 'the sex of a representative' do
      def identified_as(gender)
        represented_by("<sdg:Identifier schemeID=\"eidas\">SI/SI/123456</sdg:Identifier>#{gender}")
      end

      it 'refuses a value outside the Gender list, under R-EDM-REQ-C124' do
        expect { represented_by('<sdg:Gender>7</sdg:Gender>').validate! }.to refusing('R-EDM-REQ-C124')
      end

      # `C124` admits the numeric profile; `C126` narrows it to the three eIDAS
      # values once an `eidas` identifier is there — so `1` passes the first and
      # falls on the second.
      it 'refuses the numeric profile under an eidas identifier, under R-EDM-REQ-C126' do
        expect { identified_as('<sdg:Gender>1</sdg:Gender>').validate! }.to refusing('R-EDM-REQ-C126')
      end

      # The assertion is on the *person* and reads `sdg:Gender=('Male',…)`,
      # which an absent element fails: its published sentence only constrains a
      # value, and the assertion is what plays. `docs/carte_des_tdd.md` records
      # the disagreement.
      it 'refuses an eidas representative carrying no sex at all, under the same rule' do
        expect { identified_as('').validate! }.to refusing('R-EDM-REQ-C126')
      end

      # `C124` admits the numeric profile and `C126` does not — but `C126` only
      # has a context once an `eidas` identifier is there. Without one, the
      # numeric value passes: this is the half that proves the two lists are
      # genuinely different, where refusing `7` proves only that both refuse it.
      it 'accepts a numeric sex on a representative naming no identifier' do
        written = represented_by('<sdg:Gender>1</sdg:Gender>')

        expect(written.validate!).to be(written)
      end

      it 'accepts an eidas representative naming one of the three' do
        written = identified_as('<sdg:Gender>Female</sdg:Gender>')

        expect(written.validate!).to be(written)
      end

      # Neither rule exists at the 1.2.5 tag, so a request of that line writes
      # the element as it likes — the pair that proves the predicate guarding
      # them has the polarity it should.
      it 'says nothing of the sex of a representative on the 1.2 line' do
        written = earlier_line_envelope do |body|
          body.sub('<rim:Slot name="NaturalPerson">') do
            '<rim:Slot name="AuthorizedRepresentative"><rim:SlotValue xsi:type="rim:AnyValueType"><sdg:Person>' \
              '<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance><sdg:Gender>7</sdg:Gender>' \
              '</sdg:Person></rim:SlotValue></rim:Slot><rim:Slot name="NaturalPerson">'
          end
        end

        expect(written.body.validate!).to be_a(described_class)
      end
    end

    # `C081` compares the value whole — `or` being the loosest operator of
    # XPath — where `C091` splits on `,\s*`. The pair on one and the same value
    # is what proves the two assertions are read differently, whatever their
    # messages both say about comma-separated values.
    describe 'the procedures a power of representation covers' do
      def scoped(value, person: method(:represented_by))
        person.call('<sdg:SectorSpecificAttribute><sdg:AttributeName>' \
                    'http://data.europa.eu/p4s/attributes/PowerOfRepresentationScope</sdg:AttributeName>' \
                    "<sdg:AttributeValue>#{value}</sdg:AttributeValue></sdg:SectorSpecificAttribute>")
      end

      it 'refuses a comma-separated pair on a natural representative, under R-EDM-REQ-C081' do
        expect { scoped('T1,T3').validate! }.to refusing('R-EDM-REQ-C081')
      end

      it 'accepts that same pair on an organisation representative, which C091 splits' do
        written = scoped('T1,T3', person: method(:organisation_representing))

        expect(written.validate!).to be(written)
      end

      it 'refuses a split value naming a code the list does not publish, under R-EDM-REQ-C091' do
        expect { scoped('T1, Z9', person: method(:organisation_representing)).validate! }
          .to refusing('R-EDM-REQ-C091')
      end

      it 'accepts the system check code, which both admit beside the list' do
        written = scoped('00')

        expect(written.validate!).to be(written)
      end

      # Neither context stops at the URI its message names, so every sectoral
      # attribute is judged — the assertion, and not its message.
      it 'judges an attribute of another URI just the same' do
        written = represented_by('<sdg:SectorSpecificAttribute><sdg:AttributeName>urn:example:autre' \
                                 '</sdg:AttributeName><sdg:AttributeValue>Z9</sdg:AttributeValue>' \
                                 '</sdg:SectorSpecificAttribute>')

        expect { written.validate! }.to refusing('R-EDM-REQ-C081')
      end
    end
  end

  # `R-EDM-REQ-C106`, `C031`, `C030` and `C033`, on the evidence type asked for.
  # None of these values reaches the answer — the response announces the format
  # France served and copies no description — so they are applied for the only
  # reason left: they are FATAL on a value the request carries.
  describe 'the evidence type asked for, in what nothing echoes' do
    def described_as(&) = with_body { |body| body.sub(%r{<sdg:DataServiceEvidenceType.*?</sdg:DataServiceEvidenceType>}m, &) }

    # The context is the evidence type and the test is
    # `not(normalize-space(sdg:Identifier)='')`, so an element that is not there
    # breaks it as much as one written blank — which is the case the schema
    # leaves open, giving `sdg:Identifier` `minOccurs="0"`.
    it 'refuses one carrying no sdg:Identifier, under R-EDM-REQ-C106' do
      stripped = described_as { |type| type.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, '') }

      expect { stripped.validate! }.to refusing('R-EDM-REQ-C106')
    end

    it 'refuses one whose sdg:Identifier is written blank, under the same rule' do
      blank = described_as { |type| type.sub(%r{(<sdg:Identifier>).*?(</sdg:Identifier>)}m, '\\1   \\2') }

      expect { blank.validate! }.to refusing('R-EDM-REQ-C106')
    end

    # `C031` and `C030` are the pair `AgentConformance#require_language` already
    # reads for an agent's name and a requirement's wordings — the same two
    # assertions a seventh time, on the description beside the titles.
    def with_description(description)
      described_as { |type| type.sub('</sdg:DataServiceEvidenceType>') { "#{description}</sdg:DataServiceEvidenceType>" } }
    end

    it 'refuses a description naming no language, under R-EDM-REQ-C031' do
      expect { with_description('<sdg:Description>Acte</sdg:Description>').validate! }
        .to refusing('R-EDM-REQ-C031')
    end

    it 'refuses one naming a language the list does not publish, under R-EDM-REQ-C030' do
      expect { with_description('<sdg:Description lang="xx">Acte</sdg:Description>').validate! }
        .to refusing('R-EDM-REQ-C030')
    end

    # Compared exactly, the assertion carrying no `i` flag where the list
    # publishes upper case — the reading `LanguageCode` holds the reason for.
    it 'refuses a published code written in lower case' do
      expect { with_description('<sdg:Description lang="fr">Acte</sdg:Description>').validate! }
        .to refusing('R-EDM-REQ-C030')
    end

    it 'accepts a description naming a published code as the list publishes it' do
      written = with_description('<sdg:Description lang="FR">Acte de naissance</sdg:Description>')

      expect(written.validate!).to be(written)
    end

    # `C033` is the code list the specification publishes; `EDM:ERR:0007` is
    # what France has no document for. The pair is what keeps them apart: a
    # format outside the list never reaches the second refusal.
    it 'refuses a format the code list does not publish, under R-EDM-REQ-C033' do
      exotic = described_as { |type| type.sub('application/pdf', 'application/foo') }

      expect { exotic.validate! }.to refusing('R-EDM-REQ-C033')
    end

    it 'accepts a published format France happens not to serve' do
      served = described_as { |type| type.sub('application/pdf', 'image/png') }

      expect(served.validate!).to be(served)
    end
  end

  # `R-EDM-REQ-C073` requires an address on the agent classified `ER`, and
  # requires nothing of it but the country: that is where, and nowhere else, a
  # received request names the country that asks.
  it 'reads the country the requester declares' do
    expect(request.requester.address.country).to eq('FR')
  end

  # OOTS-213: the rules of chapter 4.6 whose 1.2.5 form differs from their 2.0.1
  # one, and those the earlier line alone publishes. Everything here is built on
  # `earlier_line_envelope`, which is the real request downgraded in every
  # respect `EdmSpecification` tells the two lines apart by.
  describe 'the rules chapter 4.6 shapes otherwise on the 1.2 line' do
    def earlier(&) = earlier_line_envelope(&).body

    # `R-EDM-REQ-C032` counts `= 1 or = 0` at the 1.2.5 tag — « must occur not
    # more than once » — where 2.0.1 counts `> 0`. So the very request the later
    # line admits, a structured format with a human-readable fallback beside it,
    # is the one the earlier refuses.
    describe 'the distributions the request asks for' do
      # Takes the envelope builder, as the three helpers below do: the pair that
      # proves the rule is read on the line the message declares needs the very
      # same request on both, and a second hand-written copy of it would be free
      # to drift from the first.
      def asking_for(*formats, envelope_of: method(:earlier))
        distributions = formats.map do |format|
          "<sdg:DistributedAs><sdg:Format>#{format}</sdg:Format></sdg:DistributedAs>"
        end

        envelope_of.call { |body| body.sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m) { distributions.join } }
      end

      it 'reads the single distribution a conformant request of that line names' do
        expect(asking_for(EvidenceType::PDF).evidence_type.distribution_formats).to eq([EvidenceType::PDF])
      end

      it 'refuses a second distribution, under R-EDM-REQ-C032' do
        expect { asking_for(EvidenceType::PDF, 'application/xml').evidence_type }.to refusing('R-EDM-REQ-C032')
      end

      # The pair that proves the rule is read on the line the message declares:
      # the 2.0 spec of the block above accepts exactly this request.
      it 'accepts that same pair on the 2.0 line' do
        both = asking_for(EvidenceType::PDF, 'application/xml', envelope_of: method(:with_body))

        expect(both.evidence_type.distribution_formats).to eq([EvidenceType::PDF, 'application/xml'])
      end

      # Asking for none satisfies the 1.2.5 assertion, which counts zero among
      # what it admits: what refuses it is `DataServiceEvidenceTypeType`, where
      # the element is `minOccurs="1"` in the 1.2.0 profile, and chapter 4.5.1
      # §3.5. Hence a `detail` naming the chapter, and not `C032` — a rule this
      # request does not break.
      it 'refuses a request asking for no distribution at all, under the chapter' do
        expect { asking_for.evidence_type }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: EarlierLineConformance::DISTRIBUTION_REQUIRED)))
      end
    end

    # `R-EDM-REQ-C016` is not executed at the 1.2.5 tag — the assertion is
    # absent from `EDM-REQ-C.sch` there, which carries 106 of the 107 rules the
    # 4.6 of that tag publishes — and the chapter publishes it all the same, as
    # FATAL. It is the chapter that is applied, on both lines, so a territory
    # outside `NUTS` is refused in 1.2 exactly as in 2.0.
    it 'refuses a territory outside NUTS on the 1.2 line too, under R-EDM-REQ-C016' do
      declared = earlier do |body|
        body.sub(%r{(</sdg:AdminUnitLevel1>)}) { "#{Regexp.last_match(1)}<sdg:AdminUnitLevel2>FR999</sdg:AdminUnitLevel2>" }
      end

      expect { declared.validate! }.to refusing('R-EDM-REQ-C016')
    end

    # `R-EDM-REQ-C073` hangs off the address in 1.2.5 — `sdg:Agent[…]/sdg:Address`
    # with `count(sdg:AdminUnitLevel1) = 1` — so an agent carrying no address at
    # all opens no context there, and a blank country satisfies a count that
    # does not filter. 2.0.1 anchors the same rule on the agent and counts only
    # the elements `normalize-space` leaves non-empty. The 2.0 form is what is
    # applied on both lines: the chapter requires the country either way, and a
    # reader that let a 1.2 request through without one would have nothing to
    # address the answer to.
    describe 'the country the requester declares' do
      it 'refuses an agent of that line carrying no address, under R-EDM-REQ-C073' do
        without = earlier { |body| body.sub(%r{<sdg:Address>.*?</sdg:Address>}m, '') }

        expect { without.validate! }.to refusing('R-EDM-REQ-C073')
      end

      it 'refuses one whose country is written blank, under the same rule' do
        blank = earlier { |body| body.sub(/(<sdg:AdminUnitLevel1>)[^<]*/) { "#{Regexp.last_match(1)}   " } }

        expect { blank.validate! }.to refusing('R-EDM-REQ-C073')
      end
    end

    # `R-EDM-REQ-C092` lists twenty-three element names at the 1.2.5 tag and
    # twenty-one at the 2.0.1 one, the two extra being `sdg:JurisdictionContext`
    # and `sdg:JurisditionLevel` — spelled thus in the rule. Both belong to
    # `JurisdictionDeterminationType`, whose only home in the 1.2.0 profile is
    # under `sdg:DataServiceEvidenceType`, and `R-EDM-REQ-S045` does not name it
    # among the five children it admits there. So the request that would exercise
    # those two rows is a request `S045` refuses, on the very line that publishes
    # them, and this is what that comes to.
    describe 'the jurisdiction determination the 1.2 profile provides for' do
      def determining(wording, envelope_of)
        determination = "<sdg:EvidenceProviderJurisdictionDetermination>#{wording}" \
                        '</sdg:EvidenceProviderJurisdictionDetermination>'

        envelope_of.call do |body|
          body.sub('</sdg:DataServiceEvidenceType>') { "#{determination}</sdg:DataServiceEvidenceType>" }
        end
      end

      it 'refuses a 1.2 request carrying one, under R-EDM-REQ-S045' do
        described = determining('<sdg:JurisdictionContext lang="FR">Paris</sdg:JurisdictionContext>', method(:earlier))

        expect { described.validate! }.to refusing('R-EDM-REQ-S045')
      end

      # The length of the wording changes nothing: `S045` counts the children of
      # the evidence type and never looks inside them, so the request is refused
      # before `C092` has anything to measure.
      it 'refuses it whatever the wording it carries is worth' do
        described = determining('<sdg:JurisdictionContext lang="FR">X</sdg:JurisdictionContext>', method(:earlier))

        expect { described.validate! }.to refusing('R-EDM-REQ-S045')
      end

      # `S045` is one of the rules the two tags publish word for word, so the
      # line the message declares changes nothing here either — where 2.0 has the
      # further reason that its profile deleted the type outright.
      it 'refuses it on the 2.0 line under the same rule' do
        described = determining('<sdg:JurisdictionContext lang="FR">Paris</sdg:JurisdictionContext>',
          method(:with_body))

        expect { described.validate! }.to refusing('R-EDM-REQ-S045')
      end
    end

    # `R-EDM-REQ-C004` and `C069`, published at the 1.2.5 tag alone. The context
    # of each is the attribute itself, so neither ever requires it — and one
    # written empty is a context node, which falls on the comparison. Compared
    # exactly, both assertions carrying no `i` flag where the list publishes
    # upper case.
    describe 'the languages the request names' do
      def procedure_in(language) = earlier { |body| body.sub('xml:lang="EN"', %(xml:lang="#{language}")) }

      def requested_in(language, envelope_of)
        envelope_of.call { |body| body.sub('<query:QueryRequest', %(<query:QueryRequest xml:lang="#{language}")) }
      end

      it 'refuses a procedure whose localised string names no published code, under R-EDM-REQ-C004' do
        expect { procedure_in('xx').validate! }.to refusing('R-EDM-REQ-C004')
      end

      it 'accepts a published code written as the list publishes it' do
        expect(procedure_in('FR').validate!).to be_a(described_class)
      end

      it 'refuses that same code in lower case, the assertion carrying no i flag' do
        expect { procedure_in('fr').validate! }.to refusing('R-EDM-REQ-C004')
      end

      # The other half of the pair, which `C069` had and `C004` had not: what
      # confines the rule to its line is a one-line predicate, and a slip in its
      # polarity — or the two predicates swapped — would show up here and
      # nowhere else in this file. The slot keeps the `rim:StringValueType` the
      # 2.0 line types it with, `R-EDM-REQ-S022` being what would otherwise
      # refuse the request first and mask the answer.
      it 'says nothing of the language of a localised string on the 2.0 line' do
        localised = with_body do |body|
          body.sub('<rim:Value>00</rim:Value>', '<rim:Value><rim:LocalizedString xml:lang="xx" value="00"/></rim:Value>')
        end

        expect(localised.validate!).to be_a(described_class)
      end

      it 'refuses a request whose own language names no published code, under R-EDM-REQ-C069' do
        expect { requested_in('xx', method(:earlier)).validate! }.to refusing('R-EDM-REQ-C069')
      end

      it 'accepts a published code on the request itself' do
        expect(requested_in('FR', method(:earlier)).validate!).to be_a(described_class)
      end

      it 'refuses that one in lower case too' do
        expect { requested_in('fr', method(:earlier)).validate! }.to refusing('R-EDM-REQ-C069')
      end

      # The 2.0 line publishes no rule of *that* identifier, the language having
      # moved into each distribution — but it does not fall silent on the
      # attribute: `R-EDM-REQ-S059` forbids it outright, so the two lines say
      # opposite things about one and the same `xml:lang`. A published code is
      # refused there exactly as an unpublished one is, the rule reading the
      # attribute's presence and never its value.
      it 'refuses that attribute outright on the 2.0 line, under R-EDM-REQ-S059' do
        expect { requested_in('xx', method(:with_body)).validate! }.to refusing('R-EDM-REQ-S059')
      end

      it 'refuses it on the 2.0 line even where the code is a published one' do
        expect { requested_in('FR', method(:with_body)).validate! }.to refusing('R-EDM-REQ-S059')
      end

      it 'accepts a 2.0 request naming no language of its own at all' do
        expect(request.validate!).to be_a(described_class)
      end
    end

    # `R-EDM-REQ-C035`, `C072` and `C113`, on the `sdg:Transformation` the 1.2.0
    # profile alone gives `EvidenceTypeDistributionType`. `C113` is `CAUTION` and
    # refuses nothing, as `S014` does not.
    describe 'the transformation a distribution asks for' do
      # The data model the transformation names a subset of, which `C072` counts
      # beside it. A method and not a constant: a constant declared in a block
      # leaks into the whole suite.
      def model = 'https://sr.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40'

      def transformed(value, conformance: model, envelope_of: method(:earlier))
        conforms = conformance && "<sdg:ConformsTo>#{conformance}</sdg:ConformsTo>"
        envelope_of.call do |body|
          body.sub('</sdg:DistributedAs>') { "#{conforms}<sdg:Transformation>#{value}</sdg:Transformation></sdg:DistributedAs>" }
        end
      end

      it 'accepts one the semantic repository publishes, beside its data model' do
        expect(transformed("#{model}/subset").validate!).to be_a(described_class)
      end

      # The assertion admits an environment infix — `sr.acc.oots.tech…` — which
      # the prose of chapter 4.5.1 §3.5 does not cite. The expression is copied
      # from the assertion, so what it admits is accepted.
      it 'accepts one carrying an environment infix, as the assertion admits' do
        expect(transformed('https://sr.acc.oots.tech.ec.europa.eu/datamodels/x/y').validate!)
          .to be_a(described_class)
      end

      it 'refuses one naming another host entirely, under R-EDM-REQ-C035' do
        expect { transformed('https://example.org/subset').validate! }.to refusing('R-EDM-REQ-C035')
      end

      it 'refuses one written empty, the element being its own context node' do
        expect { transformed('').validate! }.to refusing('R-EDM-REQ-C035')
      end

      # The alternation sits at the top level of the assertion, so `^` binds the
      # left branch alone: anything at all carrying `distributions/` satisfies
      # the rule. Copied and not tightened, for the reason `C008` is.
      it 'accepts any value carrying distributions/, the alternation being unanchored' do
        expect(transformed('https://example.org/distributions/x').validate!).to be_a(described_class)
      end

      it 'refuses a transformation whose distribution names no data model, under R-EDM-REQ-C072' do
        expect { transformed("#{model}/subset", conformance: nil).validate! }.to refusing('R-EDM-REQ-C072')
      end

      # 2.0.1 publishes no `C035` at all, and keeps `C072` on a context the
      # schema no longer lets a document reach. Neither is applied there.
      it 'says nothing of a transformation on the 2.0 line' do
        described = transformed('https://example.org/subset', conformance: nil, envelope_of: method(:with_body))

        expect(described.validate!).to be_a(described_class)
      end
    end
  end

  # RG10 and RG11 of OOTS-200. `R-EDM-REQ-C001` fixes a different literal on
  # each line, and the version the message is read in — the ebMS property where
  # the header carries one, the slot otherwise — is what says which literal
  # applies.
  describe 'the version the request declares' do
    it 'accepts the older literal from a request read on the 1.2 line' do
      expect { earlier_line_envelope.body.validate! }.not_to raise_error
    end

    # `R-EDM-REQ-S022`: the code sits in the `@value` of a `rim:LocalizedString`
    # on that line, and the `rim:Value` around it carries no text at all — read
    # as 2.0 writes it, a conformant 1.2 request would be refused for a
    # procedure it did name, and answered `EDM:ERR:0003` instead of served.
    it 'reads the procedure a request of the 1.2 line names in its localised string' do
      expect(earlier_line_envelope.body.procedure_code).to eq(ProcedureCode::SYSTEM_CHECK)
    end

    # The same slot, present and saying nothing: `R-EDM-REQ-S007` counts it and
    # is satisfied, so it is the value that fails.
    it 'refuses a request of that line whose localised string names no procedure' do
      unnamed = earlier_line_envelope { |body| body.sub('value="00"', 'value=""') }

      expect { unnamed.body.procedure_code }.to raise_error(UnreadableMessageError)
    end
  end

  # The names of the agent classified `ER`, which `WordingConformance` leaves
  # alone: `R-EDM-ERR-C027` measures them in the error response exactly as
  # `C092` measures them here, so the refusal falls where the requester is read
  # and carries no answer. Every one of them, and not the first alone.
  it 'refuses a second requester name of one character where the requester is read, under R-EDM-REQ-C092' do
    second = with_second_requester_name('<sdg:Name lang="EN">A</sdg:Name>')

    expect(second.validate!).to be(second)
    expect { second.requester }.to refusing('R-EDM-REQ-C092')
  end

  # Each family of rules is judged by its own spec; what is judged here is that
  # `validate!` applies it — one refusal of the family coming out of the parser.
  describe 'the families of rules validate! applies' do
    it 'applies PreviewConformance' do
      expect { received(request_asking_preview('peut-être')).validate! }.to refusing(PreviewConformance::BOOLEAN_SCHEMA)
    end

    it 'applies RequestEnvelopeConformance' do
      expect { with_body { |body| body.sub('LeafClassWithRepositoryItem', 'LeafClass') }.validate! }
        .to refusing('R-EDM-REQ-C024')
    end

    it 'applies RequirementConformance' do
      emptied = with_body { |body| body.sub(%r{(<rim:Slot name="Requirements">.*?)<sdg:Requirement>.*?</sdg:Requirement>}m, '\\1') }

      expect { emptied.validate! }.to refusing('R-EDM-REQ-S037')
    end

    it 'applies ClassificationConformance' do
      expect { with_classifications(classification(type: 'date')).validate! }.to refusing('R-EDM-REQ-C095')
    end

    it 'applies RegRepShapeConformance' do
      expect { with_classifications(classification, type: 'rim:AnyValueType').validate! }.to refusing('R-EDM-REQ-S031')
    end

    it 'applies WordingConformance' do
      expect { with_classifications(classification(descriptions: '<sdg:Description lang="EN">C</sdg:Description>')).validate! }
        .to refusing('R-EDM-REQ-C092')
    end
  end
end
