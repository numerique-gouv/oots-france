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

    # `R-EDM-REQ-S034` type ce slot-là comme `S035` type son jumeau : le
    # `rim:AnyValueType` de l'exemple ci-dessus est ce que la règle demande, et
    # rien d'autre ne le satisfait.
    it 'refuses the slot declared a collection, under R-EDM-REQ-S034' do
      collected = about_an_organisation { |slot| slot.sub('rim:AnyValueType', 'rim:CollectionValueType') }

      expect { collected.validate! }.to refusing('R-EDM-REQ-S034')
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

    it 'refuses a request announcing another version of the data model' do
      dated = with_body { |body| body.sub(EdmSpecification.preferred.identifier, 'oots-edm:v1.0') }

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

  # Chapter 4.6 on the obligations a request invokes. `R-EDM-REQ-S011` counts
  # the slot; the five others fire on the elements a requirement carries, so
  # nothing counts the requirements themselves and a requirement carrying no
  # identifier at all breaks no assertion.
  describe 'the requirements the request invokes' do
    # Scoped to the slot rather than applied to the whole body: `sdg:Identifier`
    # also names the beneficiary and every agent, and `sdg:Name` names the
    # agents too — a substitution over the message would judge those instead.
    def with_requirements(&)
      with_body { |body| body.sub(%r{<rim:Slot name="Requirements">.*?</rim:Slot>}m, &) }
    end

    def identified_by(value)
      with_requirements do |slot|
        slot.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, "<sdg:Identifier>#{value}</sdg:Identifier>")
      end
    end

    # Through a block, so that a backslash in a wording is a backslash: `sub`
    # reads `\1` and `\&` in a replacement string as references.
    def worded(*wordings)
      with_requirements { |slot| slot.sub(%r{<sdg:Name.*?</sdg:Name>}m) { wordings.join } }
    end

    def besides(requirement)
      with_requirements { |slot| slot.sub(%r{<sdg:Requirement>.*?</sdg:Requirement>}m) { |first| first + requirement } }
    end

    def alongside(requirement)
      with_requirements do |slot|
        slot.sub(%r{<rim:Element.*?</rim:Element>}m) do |first|
          %(#{first}<rim:Element xsi:type="rim:AnyValueType">#{requirement}</rim:Element>)
        end
      end
    end

    def requirement_named(id)
      %(<sdg:Requirement><sdg:Identifier>#{id}</sdg:Identifier><sdg:Name lang="DA">Andet krav</sdg:Name></sdg:Requirement>)
    end

    it 'accepts the requirement the real request carries' do
      expect(request.validate!).to be(request)
    end

    # `R-EDM-REQ-S037` fires on the `rim:Element` itself, which is there — it
    # came out of the collection. That is what separates it from `C008`, whose
    # own context node is the one missing when a requirement carries no
    # identifier, and which is therefore silent where this one refuses.
    it 'refuses a collection element carrying no requirement, under R-EDM-REQ-S037' do
      emptied = with_requirements { |slot| slot.sub(%r{<sdg:Requirement>.*?</sdg:Requirement>}m, '') }

      expect { emptied.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S037')))
    end

    # Nothing counts the requirements — `S011` counts the slot — so two of them
    # are conformant, and each is judged on its own. A reader that stopped at
    # the first would serve the second unexamined.
    describe 'a request naming two obligations' do
      it 'accepts them when both conform' do
        doubled = besides(requirement_named('https://sr.acc.oots.tech.ec.europa.eu/requirements/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))

        expect(doubled.validate!).to be(doubled)
      end

      it 'judges the second as much as the first' do
        doubled = besides(requirement_named('urn:uuid:f8a6a284-34e9-42c7-9733-63b5c4f4aa42'))

        expect { doubled.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end
    end

    # `besides` puts the second requirement in the same `rim:Element`; these put
    # it in an element of its own. The two are different loops — `slot_elements`
    # walks the collection, `all(element, './sdg:Requirement')` walks inside one
    # — and a regression collapsing the outer one would survive the tests above.
    describe 'a collection naming its obligations in separate elements' do
      it 'accepts them when both conform' do
        spread = alongside(requirement_named('https://sr.acc.oots.tech.ec.europa.eu/requirements/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))

        expect(spread.validate!).to be(spread)
      end

      it 'judges the requirement of the second element' do
        spread = alongside(requirement_named('urn:uuid:f8a6a284-34e9-42c7-9733-63b5c4f4aa42'))

        expect { spread.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end
    end

    describe 'the identifier of a requirement' do
      it 'refuses one that is not a Semantic Repository URL, under R-EDM-REQ-C008' do
        expect { identified_by('urn:uuid:f8a6a284-34e9-42c7-9733-63b5c4f4aa42').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end

      # The assertion carries no `i` flag and spells the UUID `[a-f0-9]`, where
      # `R-EDM-REQ-S004` on the request's own identifier matches case-insensitively.
      it 'refuses a UUID written in upper case' do
        expect { identified_by('https://sr.oots.tech.ec.europa.eu/requirements/F8A6A284-34E9-42C7-9733-63B5C4F4AA42').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end

      it 'names the requirement whose identifier is there and empty' do
        expect { identified_by('').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C008', message: /« vide »/)))
      end

      it 'accepts the acceptance environment, whose midfix the rule provides for' do
        accepted = identified_by('https://sr.acc.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42')

        expect(accepted.validate!).to be(accepted)
      end

      # The assertion escapes the point of the optional midfix and no other, so
      # every remaining `.` matches any character — a hyphen included. Copied
      # from the Schematron rather than tightened: `Requirement::IDENTIFIER`,
      # which escapes them, would refuse what a FATAL rule admits.
      it 'accepts a host the unescaped points of the rule let through' do
        hyphenated = identified_by('https://sr-oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42')

        expect(hyphenated.validate!).to be(hyphenated)
      end

      # The context of `R-EDM-REQ-C008` is the identifier itself: absent, it
      # triggers no assertion at all, and inventing a refusal would name a rule
      # the request did not break.
      it 'says nothing of a requirement carrying no identifier' do
        amputated = with_requirements { |slot| slot.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, '') }

        expect(amputated.validate!).to be(amputated)
      end
    end

    # `R-EDM-REQ-C010` and `C094` assert the attribute is there, `C009` and
    # `C093` compare it to the code list — the same pair `C109` and `C108`
    # apply to an agent's name, under four other identifiers.
    # `R-EDM-REQ-S037` asserts `sdg:Requirement` and nothing of what it holds,
    # so an empty one satisfies it — as it satisfies `S038`, whose count of
    # named children equals a count of none. Nothing else has a context to fire
    # on. The silence is the rules', not an oversight, and it is pinned so that
    # closing it later is a decision rather than an accident.
    it 'says nothing of a requirement carrying neither identifier nor wording' do
      hollow = with_requirements { |slot| slot.sub(%r{<sdg:Requirement>.*?</sdg:Requirement>}m, '<sdg:Requirement/>') }

      expect(hollow.validate!).to be(hollow)
    end

    describe 'the language a wording names' do
      # The sentence is asserted beside the rule, and not for thoroughness:
      # `REQUIREMENT_WORDINGS` says which row of `AgentConformance::RULES` an
      # element is read under, so a table pointing `sdg:Name` at the
      # description's row would name the wrong element in the sentence an
      # operator reads in the journal. Asserting both pins the mapping, where
      # asserting the rule alone pins only half of it.
      it 'refuses a name carrying no lang, under R-EDM-REQ-C010' do
        expect { worded('<sdg:Name>Proof of diploma</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C010', message: /Le nom d'une exigence/)))
      end

      it 'refuses a name whose lang is not a code of the list, under R-EDM-REQ-C009' do
        expect { worded('<sdg:Name lang="en">Proof of diploma</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C009')))
      end

      # The context of `C009` is the attribute node, whose value is not
      # normalised: ` EN ` satisfies `C010`, which normalises, and breaks the
      # comparison that follows it.
      it 'refuses a lang padded with blanks, which the rule before it accepts' do
        expect { worded('<sdg:Name lang=" EN ">Proof of diploma</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C009')))
      end

      it 'refuses a description carrying no lang, under R-EDM-REQ-C094' do
        described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Description>Awarded by a tertiary institution</sdg:Description>')

        expect { described.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C094', message: /La description d'une exigence/)))
      end

      it 'refuses a description whose lang is not a code of the list, under R-EDM-REQ-C093' do
        described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Description lang="xx">Awarded by a tertiary institution</sdg:Description>')

        expect { described.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C093')))
      end

      # `RequirementType` makes `sdg:Description` `0..n`: the fixture carries
      # none, and one that names its language is served. Tested on the
      # accepting side too, where a row of `REQUIREMENT_WORDINGS` naming the
      # wrong key would otherwise go unnoticed — the refusals above would still
      # fire, under the right rule, with the wrong sentence.
      it 'accepts a description whose lang is a code of the list' do
        described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Description lang="DA">Bevis for eksamensbevis</sdg:Description>')

        expect(described.validate!).to be(described)
      end

      # Every wording is judged, and not the first alone: chapter 4.5.1 makes
      # `sdg:Name` `1..n`, and each rule fires per wording — two on the element,
      # two on its `lang`.
      it 'accepts a requirement worded in two languages' do
        bilingual = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Name lang="DA">Bevis for eksamensbevis</sdg:Name>')

        expect(bilingual.validate!).to be(bilingual)
      end

      it 'judges the second wording as much as the first' do
        bilingual = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Name lang="da">Bevis for eksamensbevis</sdg:Name>')

        expect { bilingual.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C009')))
      end
    end

    # `R-EDM-REQ-S038` closes the list of what a requirement may carry:
    # `count(sdg:Name) + count(sdg:Identifier) + count(sdg:Description) = count(child::*)`.
    # The assertion, and not its message — which reads that the requirement
    # « MUST contain » the three, where the test requires none of them.
    describe 'the elements a requirement carries' do
      def carrying(element)
        with_requirements { |slot| slot.sub('</sdg:Name>') { "</sdg:Name>#{element}" } }
      end

      it 'refuses one carrying an sdg:ReferenceFramework, under R-EDM-REQ-S038' do
        framework = '<sdg:ReferenceFramework>Directive 2005/36/CE</sdg:ReferenceFramework>'

        expect { carrying(framework).validate! }.to refusing('R-EDM-REQ-S038')
      end

      it 'refuses one carrying an sdg:EvidenceTypeList' do
        expect { carrying('<sdg:EvidenceTypeList/>').validate! }.to refusing('R-EDM-REQ-S038')
      end

      # What the message of the rule would refuse and its test admits, which is
      # the requirement the real request carries: an identifier, a name, and no
      # description at all.
      it 'accepts one carrying an identifier and a name and no description' do
        expect(request.validate!).to be(request)
      end

      # Only the names are closed, not how many of each: the assertion counts
      # every `sdg:Name` on its left-hand side.
      it 'accepts one carrying a second name' do
        bilingual = carrying('<sdg:Name lang="DA">Bevis for eksamensbevis</sdg:Name>')

        expect(bilingual.validate!).to be(bilingual)
      end
    end

    # `R-EDM-REQ-C092` reaches a requirement's wordings too, its context naming
    # `sdg:Name` and `sdg:Description` among twenty-one others and no ancestor,
    # where `require_requirement_wordings` judges their language alone.
    it 'refuses a description of one character, under R-EDM-REQ-C092' do
      described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
        '<sdg:Description lang="EN">B</sdg:Description>')

      expect { described.validate! }.to refusing('R-EDM-REQ-C092')
    end
  end

  # Chapter 4.6 on the classifications of provider a request invokes.
  # `R-EDM-REQ-S014` counts the slot under `CAUTION`, so a request carrying none
  # is one nothing refuses — which is the request really received. The three rules applied here fire below the slot: on each element
  # of the collection, on each `@schemeID` and on each `@lang`.
  describe 'the provider classifications the request invokes' do
    # The real request carries no such slot, so the specs write one. Its
    # identifier is a Semantic Repository URL of the shape `R-EDM-REQ-C097`
    # fixes, that rule being one this reader does not apply, and the elements
    # follow the order `InformationConceptType` sequences them in.
    def classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/FR/Municipality',
                       descriptions: '<sdg:Description lang="EN">French municipality</sdg:Description>')
      <<~XML
        <sdg:EvidenceProviderClassification>
          <sdg:Identifier schemeID="#{identifier}">FR-MUNICIPALITY</sdg:Identifier>
          #{descriptions}
        </sdg:EvidenceProviderClassification>
      XML
    end

    # Les deux types sont paramétrables parce que `R-EDM-REQ-S031` et `S032` les
    # fixent : le slot est une collection, chacun de ses `rim:Element` une valeur
    # quelconque. Les valeurs par défaut sont celles que les règles demandent, et
    # tous les exemples de ce bloc les prennent — les deux qui en changent
    # prouvent que la règle refuse le reste.
    def with_classifications(*elements, type: 'rim:CollectionValueType', element_type: 'rim:AnyValueType')
      collection = elements.map { |element| %(<rim:Element xsi:type="#{element_type}">#{element}</rim:Element>) }

      with_body do |body|
        body.sub('<rim:Slot name="EvidenceRequester">', <<~XML)
          <rim:Slot name="EvidenceProviderClassification">
            <rim:SlotValue xsi:type="#{type}"
                           collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
              #{collection.join}
            </rim:SlotValue>
          </rim:Slot>
          <rim:Slot name="EvidenceRequester">
        XML
      end
    end

    # `R-EDM-REQ-S014` is a `CAUTION`: its absence is refused nowhere, which is
    # why the slot is read through `optional_slot_elements` and stays out of
    # `REQUIRED_SLOTS`.
    it 'accepts a request carrying no such slot, which is the one really received' do
      expect(request.validate!).to be(request)
    end

    it 'accepts a classification the rules admit' do
      expect(with_classifications(classification).validate!).to be_truthy
    end

    it 'refuses the slot declared an any value, under R-EDM-REQ-S031' do
      expect { with_classifications(classification, type: 'rim:AnyValueType').validate! }
        .to refusing('R-EDM-REQ-S031')
    end

    it 'refuses a collection element declared a collection, under R-EDM-REQ-S032' do
      expect { with_classifications(classification, element_type: 'rim:CollectionValueType').validate! }
        .to refusing('R-EDM-REQ-S032')
    end

    # `R-EDM-REQ-S041` fires on the `rim:Element` itself, which is there — it
    # came out of the collection — exactly as `S037` does over `Requirements`.
    it 'refuses a collection element carrying no classification, under R-EDM-REQ-S041' do
      expect { with_classifications('').validate! }.to refusing('R-EDM-REQ-S041')
    end

    # `InformationConceptType` sets no upper bound, so one `rim:Element` may
    # carry several classifications and each is judged on its own. Distinct from
    # the case below, which puts each classification in an element of its own:
    # this one alone exercises the inner walk.
    it 'judges a second classification carried by the same element' do
      doubled = with_classifications(
        classification + classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/US/County')
      )

      expect { doubled.validate! }.to refusing('R-EDM-REQ-C098')
    end

    # Nothing counts the classifications, `S014` counting the slot: each
    # element is judged on its own, so a reader stopping at the first would
    # serve the second unexamined.
    it 'judges a second element as much as the first' do
      doubled = with_classifications(classification, classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/US/County'))

      expect { doubled.validate! }.to refusing('R-EDM-REQ-C098')
    end

    # `R-EDM-REQ-C098` reads the country between the codelist prefix and the
    # next `/`, and compares it to the countries taking part in OOTS — a far
    # shorter list than the one `C015` holds an address to.
    describe 'the country its identifier names' do
      it 'accepts a country taking part in OOTS' do
        expect(with_classifications(classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/DE/Municipality')).validate!)
          .to be_truthy
      end

      it 'refuses one that does not, under R-EDM-REQ-C098' do
        expect { with_classifications(classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/US/County')).validate! }
          .to refusing('R-EDM-REQ-C098')
      end

      # The comparison carries no `i` flag, as `C016` and `C021` carry none: the
      # segment is compared as it is written.
      it 'refuses a country written in lower case' do
        expect { with_classifications(classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/fr/Municipality')).validate! }
          .to refusing('R-EDM-REQ-C098')
      end

      # `oots` is admitted on an agent's identifier « for testing purposes » and
      # by no rule here: the `OOTS_Country-CodeList` this one compares to does
      # not publish it.
      it 'refuses the literal oots, which the agent rules admit' do
        expect { with_classifications(classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/oots/Municipality')).validate! }
          .to refusing('R-EDM-REQ-C098')
      end

      # `substring-after` seeks the prefix wherever it sits, so the environment
      # midfix of an acceptance URL crosses it unseen.
      it 'accepts an acceptance URL, whose midfix the rule never sees' do
        expect(with_classifications(classification(identifier: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FR/Municipality')).validate!)
          .to be_truthy
      end

      # The case that separates `substring-before` from `String#partition`:
      # XPath yields the empty string when the separator is absent, where
      # `partition(…).first` yields the whole of what precedes it. Read with
      # `partition`, this identifier would hand back `FR` and be served.
      it 'refuses an identifier ending at the country, with no segment after it' do
        expect { with_classifications(classification(identifier: 'https://sr.oots.tech.ec.europa.eu/codelists/FR')).validate! }
          .to refusing('R-EDM-REQ-C098')
      end

      # The context of the rule is the `@schemeID` attribute: absent, no
      # assertion fires at all. Nothing requires one unconditionally either —
      # `C099` narrows its own context to `sdg:Identifier[@schemeID]`, and
      # `C096`, which does assert the attribute, first narrows itself to a
      # classification whose `sdg:Type` is `codelist`. Neither is applied here.
      it 'accepts an identifier carrying no schemeID' do
        classified = classification.sub(/ schemeID="[^"]*"/, '')

        expect(with_classifications(classified).validate!).to be_truthy
      end

      # Present and empty, the attribute is a context node: the assertion fires,
      # and the country it reads out is empty too.
      it 'refuses a schemeID written empty, under R-EDM-REQ-C098' do
        expect { with_classifications(classification(identifier: '')).validate! }.to refusing('R-EDM-REQ-C098')
      end
    end

    # `R-EDM-REQ-C021`, whose context is the `@lang` attribute of each
    # `sdg:Description`. `C022`, which requires that attribute, is not applied
    # here — `docs/reste_à_faire.md` records the partiality.
    describe 'the language its description names' do
      it 'accepts a code the list publishes' do
        expect(with_classifications(classification).validate!).to be_truthy
      end

      it 'refuses a code it does not, under R-EDM-REQ-C021' do
        described = classification(descriptions: '<sdg:Description lang="ZZ">Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      # The comparison carries no `i` flag, and the list publishes upper case.
      it 'refuses a published code written in lower case' do
        described = classification(descriptions: '<sdg:Description lang="en">French municipality</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      # Written empty, the attribute is there and is a context node: the
      # assertion fires, and the empty string is no code of the list.
      it 'refuses a lang written empty, under R-EDM-REQ-C021' do
        described = classification(descriptions: '<sdg:Description lang="">Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      # The case that proves `C022` is not applied: its context is the element
      # and it would refuse this, where `C021`'s context is the attribute that
      # is not there. A reader reusing `require_language` would refuse it too.
      it 'accepts a description carrying no lang at all' do
        described = classification(descriptions: '<sdg:Description>Commune</sdg:Description>')

        expect(with_classifications(described).validate!).to be_truthy
      end

      # `InformationConceptType` makes `sdg:Description` `0..n`, and each
      # attribute is a context of its own: the second is judged as the first is.
      it 'judges a second description as much as the first' do
        described = classification(descriptions: '<sdg:Description lang="EN">French municipality</sdg:Description>' \
                                                 '<sdg:Description lang="fr">Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      it 'accepts a classification describing itself in no language at all' do
        expect(with_classifications(classification(descriptions: '')).validate!).to be_truthy
      end

      # `R-EDM-REQ-C092` reaches this description as it reaches every other
      # wording: its context names `sdg:Description` and no ancestor at all,
      # where `require_classification_languages` judges the language alone.
      it 'refuses a description of one character, under R-EDM-REQ-C092' do
        described = classification(descriptions: '<sdg:Description lang="EN">C</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C092')
      end
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

  # Chapter 4.6 on the RegRep shape of the slots: nineteen FATAL rules, all of
  # one form — `substring-after(@xsi:type, ':')` compared to a single local
  # name. The prefix is therefore not judged, and the context is the
  # `rim:SlotValue` of a slot that is there, its presence being counted by the
  # rules `REQUIRED_SLOTS` carries.
  describe 'the RegRep type the slots declare' do
    # `nil` takes the attribute away, where a value replaces it. `bound` binds
    # the prefix `x` on the element itself, so that a document naming a type
    # under an unusual prefix still parses.
    def slot_typed(name, type, bound: nil)
      declared = type.nil? ? '' : %( xsi:type="#{type}")
      declared += %( xmlns:x="#{bound}") if bound

      with_body { |body| body.sub(slot(name)) { |found| found.sub(/ xsi:type="[^"]*"/, declared) } }
    end

    def element_typed(name, type)
      with_body do |body|
        body.sub(slot(name)) { |found| found.sub(/<rim:Element xsi:type="[^"]*"/, %(<rim:Element xsi:type="#{type}")) }
      end
    end

    it 'accepts the types the real request declares' do
      expect(request.validate!).to be(request)
    end

    it 'refuses an EvidenceProvider slot declared a collection, under R-EDM-REQ-S030' do
      expect { slot_typed('EvidenceProvider', 'rim:CollectionValueType').validate! }.to refusing('R-EDM-REQ-S030')
    end

    it 'refuses a Requirements slot declared an any value, under R-EDM-REQ-S026' do
      expect { slot_typed('Requirements', 'rim:AnyValueType').validate! }.to refusing('R-EDM-REQ-S026')
    end

    it 'refuses a collection element declared a collection, under R-EDM-REQ-S027' do
      expect { element_typed('Requirements', 'rim:CollectionValueType').validate! }.to refusing('R-EDM-REQ-S027')
    end

    # The slots of `query:Query` are typed by rules of their own, and the walk
    # reads them under that element rather than under the request.
    it 'refuses a NaturalPerson slot declared a collection, under R-EDM-REQ-S035' do
      expect { slot_typed('NaturalPerson', 'rim:CollectionValueType').validate! }.to refusing('R-EDM-REQ-S035')
    end

    # `substring-after` yields the empty string when the separator is missing,
    # and an absent attribute leaves nothing to search at all: neither matches
    # the name the rule asks for.
    it 'refuses a slot value declaring no type at all, under R-EDM-REQ-S020' do
      expect { slot_typed('SpecificationIdentifier', nil).validate! }.to refusing('R-EDM-REQ-S020')
    end

    it 'refuses a type written without a prefix, which the rule reads as empty' do
      expect { slot_typed('EvidenceProvider', 'AnyValueType').validate! }.to refusing('R-EDM-REQ-S030')
    end

    # The rule compares what follows the colon and nothing else, so a prefix
    # bound to anything at all satisfies it. Refusing this would refuse what a
    # FATAL rule admits, which is the mistake this whole reading exists to
    # avoid.
    it 'accepts a type under a prefix bound to something other than rim' do
      served = slot_typed('EvidenceProvider', 'x:AnyValueType', bound: OotsNamespaces::NAMESPACES.fetch('sdg'))

      expect(served.validate!).to be(served)
    end

    # Une ligne de table jamais exercée est une transcription jamais vérifiée,
    # et transcrire est tout ce que ces trois tables font. Chaque ligne a donc
    # son exemple, sous l'identifiant que la règle porte dans le Schematron —
    # écrit ici à la main, jamais lu dans la table, sans quoi une ligne écrite à
    # l'envers se vérifierait elle-même. Le type accepté, lui, est prouvé par
    # l'exemple d'ouverture, que la requête réelle satisfait.
    {
      'SpecificationIdentifier' => %w[rim:BooleanValueType R-EDM-REQ-S020],
      'IssueDateTime' => %w[rim:StringValueType R-EDM-REQ-S021],
      'Procedure' => %w[rim:BooleanValueType R-EDM-REQ-S022],
      'PossibilityForPreview' => %w[rim:StringValueType R-EDM-REQ-S024],
      'ExplicitRequestGiven' => %w[rim:StringValueType R-EDM-REQ-S025],
      'Requirements' => %w[rim:AnyValueType R-EDM-REQ-S026],
      'EvidenceRequester' => %w[rim:AnyValueType R-EDM-REQ-S028],
      'EvidenceProvider' => %w[rim:CollectionValueType R-EDM-REQ-S030],
    }.each do |name, (wrong, rule)|
      it "refuses a #{name} slot declared #{wrong}, under #{rule}" do
        expect { slot_typed(name, wrong).validate! }.to refusing(rule)
      end
    end

    { 'NaturalPerson' => 'R-EDM-REQ-S035', 'EvidenceRequest' => 'R-EDM-REQ-S033' }.each do |name, rule|
      it "refuses a #{name} slot of query:Query declared a collection, under #{rule}" do
        expect { slot_typed(name, 'rim:CollectionValueType').validate! }.to refusing(rule)
      end
    end

    { 'Requirements' => 'R-EDM-REQ-S027', 'EvidenceRequester' => 'R-EDM-REQ-S029' }.each do |name, rule|
      it "refuses a rim:Element of #{name} declared a collection, under #{rule}" do
        expect { element_typed(name, 'rim:CollectionValueType').validate! }.to refusing(rule)
      end
    end

    # Les quatre slots que la requête réelle ne porte pas. Chacun a besoin de ses
    # deux moitiés : le refus prouve que la règle est appliquée sous le bon
    # identifiant, l'acceptation que le type attendu est celui que la règle
    # demande — un refus seul passerait quel que soit le type inscrit dans la
    # table.
    describe 'the slots the real request does not carry' do
      # Écrits avant d'être jugés : le contexte de chaque règle est le
      # `rim:SlotValue` d'un slot présent, donc un slot absent ne déclenche rien.
      # L'ancre dit sous quel élément il se pose — `query:QueryRequest` pour les
      # deux premiers, `query:Query` pour les deux derniers.
      def slot_written(name, type, content, before: '<rim:Slot name="EvidenceRequester">')
        written = %(<rim:Slot name="#{name}"><rim:SlotValue xsi:type="#{type}">#{content}</rim:SlotValue></rim:Slot>)

        with_body { |body| body.sub(before) { "#{written}#{before}" } }
      end

      {
        'PreviewLocation' => ['R-EDM-REQ-S023', 'rim:StringValueType',
                              '<rim:Value>https://example.si/apercu</rim:Value>',
                              '<rim:Slot name="EvidenceRequester">'],
        'ReturnLocation' => ['R-EDM-REQ-S061', 'rim:StringValueType',
                             '<rim:Value>https://example.si/retour</rim:Value>',
                             '<rim:Slot name="EvidenceRequester">'],
        'AuthorizedRepresentative' => ['R-EDM-REQ-S036', 'rim:AnyValueType',
                                       '<sdg:Person><sdg:FamilyName>Novak</sdg:FamilyName></sdg:Person>',
                                       '<rim:Slot name="NaturalPerson">'],
        'AuthorizedRepresentativeLegalPerson' => ['R-EDM-REQ-S055', 'rim:AnyValueType',
                                                  '<sdg:LegalPerson><sdg:LegalName>Novak d.o.o.</sdg:LegalName></sdg:LegalPerson>',
                                                  '<rim:Slot name="NaturalPerson">'],
      }.each do |name, (rule, expected, content, before)|
        it "accepts a #{name} slot declared #{expected}" do
          written = slot_written(name, expected, content, before:)

          expect(written.validate!).to be(written)
        end

        it "refuses one declared a collection, under #{rule}" do
          written = slot_written(name, 'rim:CollectionValueType', content, before:)

          expect { written.validate! }.to refusing(rule)
        end
      end
    end
  end

  # `R-EDM-REQ-S052` and `S053`, whose common context is a `rim:SlotValue`
  # declaring itself `rim:CollectionValueType` — the attribute compared whole,
  # prefix included, where the nineteen rules above compare its local name
  # alone. No ancestor narrows that context: every slot value is reached.
  describe 'what a RegRep collection must carry' do
    def collection(name, &) = with_body { |body| body.sub(slot(name), &) }

    it 'refuses one carrying no element at all, under R-EDM-REQ-S052' do
      emptied = collection('Requirements') { |found| found.sub(%r{<rim:Element.*?</rim:Element>}m, '') }

      expect { emptied.validate! }.to refusing('R-EDM-REQ-S052')
    end

    it 'refuses one declaring no collectionType, under R-EDM-REQ-S053' do
      untyped = collection('EvidenceRequester') { |found| found.sub(/\s*collectionType="[^"]*"/, '') }

      expect { untyped.validate! }.to refusing('R-EDM-REQ-S053')
    end

    # The rule admits the `Set` of the RegRep list and no other collection.
    it 'refuses one declared a Bag' do
      bagged = collection('EvidenceRequester') do |found|
        found.sub(/collectionType="[^"]*"/, 'collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Bag"')
      end

      expect { bagged.validate! }.to refusing('R-EDM-REQ-S053')
    end

    # The two readings of `@xsi:type` told apart, on a slot value that breaks
    # both of these rules and satisfies `R-EDM-REQ-S026`: the local name is the
    # one that rule asks for, and the qualified name is not the one this context
    # selects. A reader unifying the two comparisons refuses this request.
    it 'accepts one whose prefix keeps it out of the context of these two rules' do
      served = collection('Requirements') do |found|
        found.sub(/ xsi:type="[^"]*"/,
          %( xsi:type="x:CollectionValueType" xmlns:x="#{OotsNamespaces::NAMESPACES.fetch('rim')}"))
          .sub(/\s*collectionType="[^"]*"/, '')
          .sub(%r{<rim:Element.*?</rim:Element>}m, '')
      end

      expect(served.validate!).to be(served)
    end
  end

  # `R-EDM-REQ-C092` (FATAL), one rule and one walk: every wording the request
  # carries is at least two characters once normalised — one for the two
  # elements the test excepts by name — and the twenty-one element names its
  # context lists are reached wherever they sit. The readers that visit some of
  # them keep their own sentence and run first; this is the net under everywhere
  # they do not go.
  describe 'the length of the wordings' do
    def titled(value) = with_body { |body| body.sub(/(<sdg:Title lang="FR">)[^<]*/) { "#{Regexp.last_match(1)}#{value}" } }

    it 'refuses a title of the requested evidence type, under R-EDM-REQ-C092' do
      expect { titled('X').validate! }.to refusing('R-EDM-REQ-C092')
    end

    # Le test demande `> 1`, donc deux caractères passent et un seul non. Épinglé
    # à la frontière : sans cet exemple, un lecteur qui demanderait trois
    # caractères refuserait ce qu'un État membre a le droit d'envoyer, et rien ne
    # le dirait.
    it 'accepts a title of exactly two characters' do
      served = titled('XX')

      expect(served.validate!).to be(served)
    end

    # Nothing reads this element in `validate!` at all: `NaturalPerson` measures
    # it where the subject is read, and refuses it naming no rule.
    it 'refuses a place of birth of one character' do
      born = with_body { |body| body.sub('</sdg:DateOfBirth>', '</sdg:DateOfBirth><sdg:PlaceOfBirth>P</sdg:PlaceOfBirth>') }

      expect { born.validate! }.to refusing('R-EDM-REQ-C092')
    end

    # The disjunction of the test names `sdg:LocatorDesignator` and
    # `sdg:StringValue` and asks a single character of those two alone: a street
    # number one character long is conformant.
    def designated(value)
      with_requester_agent do |agent|
        agent.sub('<sdg:AdminUnitLevel1>', "<sdg:LocatorDesignator>#{value}</sdg:LocatorDesignator><sdg:AdminUnitLevel1>")
      end
    end

    it 'accepts a locator designator of one character' do
      numbered = designated('7')

      expect(numbered.validate!).to be(numbered)
    end

    # L'autre des deux, sans quoi rien ne dirait qu'il est bien dans la table :
    # le contexte de la règle ne porte aucun ancêtre, donc l'endroit où
    # l'élément se trouve ne change rien à ce qu'elle en demande.
    it 'accepts a string value of one character' do
      valued = with_body do |body|
        body.sub('</sdg:DateOfBirth>', '</sdg:DateOfBirth><sdg:StringValue>7</sdg:StringValue>')
      end

      expect(valued.validate!).to be(valued)
    end

    # Un caractère au minimum, donc zéro est refusé — et sous une autre phrase
    # que les dix-neuf autres éléments, « fait moins de deux caractères » n'ayant
    # aucun sens pour ceux-là. C'est le seul exemple qui atteint cette phrase.
    it 'refuses a locator designator written empty, saying it is empty' do
      expect { designated('').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError)
          .and(having_attributes(detail: 'R-EDM-REQ-C092', message: /est vide/)))
    end

    # The names of the agent classified `ER` are what this walk must leave
    # alone: `R-EDM-ERR-C027` measures them in the error response exactly as
    # `C092` measures them here, so a refusal that travelled back would be
    # signed into a message breaking a FATAL rule of its own. Every one of them,
    # and not the first alone.
    describe 'the names of the requesting agent' do
      let(:second) { with_second_requester_name('<sdg:Name lang="EN">A</sdg:Name>') }

      it 'says nothing of a second name of one character' do
        expect(second.validate!).to be_truthy
      end

      it 'refuses that second name where the requester is read, under R-EDM-REQ-C092' do
        expect { second.requester }.to refusing('R-EDM-REQ-C092')
      end
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

  # What a rule of chapter 4.6 refuses, said once: the identifier travels in the
  # `detail` of the failure, which is what reaches the `EDM:ERR:0003` and the
  # journal alike.
  def refusing(rule)
    raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: rule)))
  end

  # The agent classified `ER` alone, `Fixtures::REQUESTER_AGENT` saying why.
  def with_requester_agent(&) = envelope_with_requester_agent(&).body

  # `nil` removes the attribute, where an empty string writes it blank:
  # `R-EDM-REQ-C011` asserts its presence and `C012` judges its value.
  def with_requester_scheme(scheme) = with_requester_agent { |agent| replace_scheme(agent, scheme) }

  def with_requester_id(id) = with_requester_agent { |agent| replace_id(agent, id) }

  def without_requester_identifier = with_requester_agent { |agent| remove_identifier(agent) }

  # The slot itself, and not the agent it carries: `R-EDM-REQ-S012` counts it
  # among the children of `query:QueryRequest`, `R-EDM-REQ-S015` its counterpart
  # `EvidenceRequest` among those of `query:Query`.
  def without_requester_slot = without_slot('EvidenceRequester')

  # The slot as `R-EDM-REQ-S028`, `S029`, `S052` and `S053` require it — a
  # collection, declaring its type, carrying an element — and carrying no
  # `sdg:Agent`: what `S039` alone refuses.
  def without_any_agent
    with_body do |body|
      body.sub(slot('EvidenceRequester')) do
        '<rim:Slot name="EvidenceRequester"><rim:SlotValue xsi:type="rim:CollectionValueType" ' \
          'collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">' \
          '<rim:Element xsi:type="rim:AnyValueType"/></rim:SlotValue></rim:Slot>'
      end
    end
  end

  def with_doubled_requester_slot = with_doubled_slot('EvidenceRequester')

  def without_evidence_request = without_slot('EvidenceRequest')

  def with_doubled_evidence_request = with_doubled_slot('EvidenceRequest')

  # Both halves of a rule that counts, written once: `spec/parsers/evidence_response_parser_spec.rb`
  # cuts its own slots out the same way.
  def slot(name) = %r{<rim:Slot name="#{name}">.*?</rim:Slot>}m

  def without_slot(name) = with_body { |body| body.sub(slot(name), '') }

  def with_doubled_slot(name) = with_body { |body| body.sub(slot(name)) { |found| found * 2 } }

  def with_requester_name(name) = with_requester_agent { |agent| replace_name(agent, name) }

  def with_second_requester_name(second) = with_requester_agent { |agent| add_name(agent, second) }

  def with_requester_language(value) = with_requester_agent { |agent| replace_language(agent, value) }

  def with_requester_country(code)
    with_requester_agent do |agent|
      agent.sub(/(<sdg:AdminUnitLevel1>)[^<]*/) { "#{Regexp.last_match(1)}#{code}" }
    end
  end

  # `AddressType` puts `AdminUnitLevel2` after `AdminUnitLevel1`, and the real
  # request carries no such element: it is added rather than substituted.
  def with_requester_territory(code)
    with_requester_agent do |agent|
      agent.sub(%r{(</sdg:AdminUnitLevel1>)}) { "#{Regexp.last_match(1)}<sdg:AdminUnitLevel2>#{code}</sdg:AdminUnitLevel2>" }
    end
  end

  # The real request names no identifier for its beneficiary, so one is added
  # here. Its value is of the shape `R-EDM-REQ-C040` fixes, that rule being a
  # different one from the two under test.
  def with_beneficiary_identifier(attributes)
    identifier = "<sdg:Identifier#{attributes}>FR/DE/A2635542Y</sdg:Identifier>"
    identifier = yield(identifier) if block_given?

    with_body { |body| body.sub('</sdg:LevelOfAssurance>', "</sdg:LevelOfAssurance>#{identifier}") }
  end

  # An element added under an agent, after its `sdg:Name`: what
  # `R-EDM-REQ-S040` and `S043` count as one child too many.
  # Through a block, and `sub` on a literal rather than on a pattern: in a
  # replacement string `sub` reads `\1` and `\&` as backreferences, and the
  # element comes from the caller.
  def agent_carrying(agent, element) = agent.sub('</sdg:Name>') { "</sdg:Name>#{element}" }

  # The agent beside the requester alone, `Fixtures::PLATFORM_AGENT` saying why.
  def with_platform_agent(&) = envelope_with_platform_agent(&).body

  # `nil` removes the element rather than emptying it: `R-EDM-REQ-C013`
  # normalises, so the two must be told apart by what is written.
  def with_platform_classification(value)
    with_platform_agent do |agent|
      agent.sub(%r{<sdg:Classification>[^<]*</sdg:Classification>},
        value.nil? ? '' : "<sdg:Classification>#{value}</sdg:Classification>")
    end
  end

  # `nil` removes the attribute, where an empty string writes it blank:
  # `R-EDM-REQ-C011` asserts its presence and `C012` judges its value.
  def with_platform_scheme(scheme) = with_platform_agent { |agent| replace_scheme(agent, scheme) }

  def with_platform_id(id) = with_platform_agent { |agent| replace_id(agent, id) }

  def without_platform_identifier = with_platform_agent { |agent| remove_identifier(agent) }

  def with_platform_name(name) = with_platform_agent { |agent| replace_name(agent, name) }

  def without_platform_name = with_platform_agent { |agent| remove_name(agent) }

  def with_second_platform_name(second) = with_platform_agent { |agent| add_name(agent, second) }

  def with_platform_language(value) = with_platform_agent { |agent| replace_language(agent, value) }

  # The platform of the real request declares no address, `R-EDM-REQ-C073`
  # requiring one of the agent classified `ER` alone: this one is added where
  # `AgentType` puts it, between the name and the classification.
  def with_platform_address(address)
    with_platform_agent do |agent|
      agent.sub(%r{(<sdg:Name[^>]*>[^<]*</sdg:Name>)}) { "#{Regexp.last_match(1)}#{address}" }
    end
  end

  def with_platform_country(code)
    with_platform_address("<sdg:Address><sdg:AdminUnitLevel1>#{code}</sdg:AdminUnitLevel1></sdg:Address>")
  end

  # The country beside it, `AddressType` sequencing the two: a territory alone
  # would be judged all the same — `C016`'s context is its own element — but an
  # address shaped as the schema shapes it is what a correspondent sends.
  def with_platform_territory(code)
    with_platform_address(
      "<sdg:Address><sdg:AdminUnitLevel1>DE</sdg:AdminUnitLevel1><sdg:AdminUnitLevel2>#{code}</sdg:AdminUnitLevel2></sdg:Address>"
    )
  end

  # The agent of the `EvidenceProvider` slot alone, `Fixtures::PROVIDER_AGENT`
  # saying why it is reached through its slot.
  def with_provider_agent(&) = envelope_with_provider_agent(&).body

  def without_provider_agent = with_provider_agent { '' }

  def with_provider_scheme(scheme) = with_provider_agent { |agent| replace_scheme(agent, scheme) }

  def with_provider_id(id) = with_provider_agent { |agent| replace_id(agent, id) }

  def without_provider_identifier = with_provider_agent { |agent| remove_identifier(agent) }

  def with_provider_name(name) = with_provider_agent { |agent| replace_name(agent, name) }

  def without_provider_name = with_provider_agent { |agent| remove_name(agent) }

  def with_second_provider_name(second) = with_provider_agent { |agent| add_name(agent, second) }

  def with_provider_language(value) = with_provider_agent { |agent| replace_language(agent, value) }

  # A second `sdg:Agent` under the same slot value, beside the one the request
  # designates. The block, where a spec passes one, alters the **first** agent,
  # so that what the reader designates can be told from what it merely judges.
  def beside_the_provider(**)
    with_provider_agent { |agent| (block_given? ? yield(agent) : agent) + second_provider_agent(**) }
  end

  # Conformant to the four rules that reach it by default, so that each example
  # breaks the one it names and no other.
  def second_provider_agent(identifier: %(<sdg:Identifier schemeID="#{IdentifierScheme::EAS_PREFIX}0009">AUTRE</sdg:Identifier>),
                            name: '<sdg:Name lang="EN">Another provider</sdg:Name>', classification: '')
    "<sdg:Agent>#{identifier}#{name}#{classification}</sdg:Agent>"
  end

  # A third agent in the collection, beside the two the real request carries:
  # what proves the walk judges each of the agents the requester is not, and
  # not the first of them.
  def with_third_agent(agent)
    with_body do |body|
      body.sub(%r{(<rim:Slot name="EvidenceRequester">.*?)(</rim:SlotValue>)}m) do
        "#{Regexp.last_match(1)}<rim:Element xsi:type=\"rim:AnyValueType\">#{agent}</rim:Element>#{Regexp.last_match(2)}"
      end
    end
  end

  # The substitutions the three agents take, written once: only the agent they
  # are applied to differs.
  def replace_id(agent, id) = agent.sub(/(<sdg:Identifier[^>]*>)[^<]*/) { "#{Regexp.last_match(1)}#{id}" }

  def remove_identifier(agent) = agent.sub(%r{<sdg:Identifier[^>]*>[^<]*</sdg:Identifier>}, '')

  def replace_name(agent, name) = agent.sub(/(<sdg:Name[^>]*>)[^<]*/) { "#{Regexp.last_match(1)}#{name}" }

  def remove_name(agent) = agent.sub(%r{<sdg:Name[^>]*>[^<]*</sdg:Name>}, '')

  def add_name(agent, second) = agent.sub(%r{<sdg:Name[^>]*>[^<]*</sdg:Name>}) { |first| "#{first}#{second}" }

  # `nil` removes the attribute rather than writing it blank: `R-EDM-REQ-C011`
  # and `C017` assert its presence, `C012` and `C018` judge its value.
  def replace_scheme(agent, scheme)
    agent.sub(/ schemeID="[^"]*"/, scheme.nil? ? '' : %( schemeID="#{scheme}"))
  end

  # `nil` removes the attribute rather than emptying it: `R-EDM-REQ-C109`
  # normalises, so the two must be told apart by what is written and not by
  # what is read.
  def replace_language(agent, value)
    agent.sub(/<sdg:Name lang="[^"]*">/, value.nil? ? '<sdg:Name>' : %(<sdg:Name lang="#{value}">))
  end
  # RG10 and RG11 of OOTS-200. `R-EDM-REQ-C001` fixes a different literal on
  # each line, and the version the message is read in — the ebMS property where
  # the header carries one, the slot otherwise — is what says which literal
  # applies.
  describe 'the version the request declares' do
    it 'accepts the older literal from a request read on the 1.2 line' do
      expect { earlier_line_envelope.body.validate! }.not_to raise_error
    end

    # `ReturnLocation` is a slot 2.0.1 alone defines — the name appears nowhere
    # in the 1.2.5 Schematron — so `R-EDM-REQ-S061`, which types it there, types
    # nothing on the earlier line. The pair is what proves it: the very
    # declaration the 2.0 line refuses passes on the 1.2 one.
    def returning(envelope_of)
      envelope_of.call do |body|
        body.sub('<rim:Slot name="EvidenceRequester">') do
          '<rim:Slot name="ReturnLocation"><rim:SlotValue xsi:type="rim:AnyValueType">' \
            '<rim:Value>https://example.si/retour</rim:Value></rim:SlotValue></rim:Slot>' \
            '<rim:Slot name="EvidenceRequester">'
        end
      end
    end

    it 'types no ReturnLocation on the 1.2 line, the slot being of 2.0 alone' do
      expect { returning(method(:earlier_line_envelope)).body.validate! }.not_to raise_error
    end

    it 'refuses that same declaration on the 2.0 line, under R-EDM-REQ-S061' do
      expect { returning(method(:with_body)).validate! }.to refusing('R-EDM-REQ-S061')
    end

    # The other face of `R-EDM-REQ-S022` on this line, and the one an accepted
    # request cannot prove: a slot typed as 2.0 types it — the very shape the
    # 2.0 table imposed on 1.2 correspondents — has to be refused here, or the
    # row is a transcription nothing exercises.
    it 'refuses a Procedure declared as the 2.0 line types it, under R-EDM-REQ-S022' do
      written = earlier_line_envelope do |body|
        body.sub('xsi:type="rim:InternationalStringValueType"', 'xsi:type="rim:StringValueType"')
      end

      expect { written.body.validate! }.to refusing('R-EDM-REQ-S022')
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

    # CA11: the header announced 2.0 and the body says 1.2. Refused under the
    # rule of the line the header named, which is also the line the exception
    # response goes back in.
    it 'refuses a request whose header announces 2.0 and whose slot says 1.2' do
      contradicting = envelope_with_body('requete') do |body|
        body.sub(EdmSpecification::V2_0.identifier, EdmSpecification::V1_2.identifier)
      end

      expect { contradicting.body.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
    end

    # A message with no property announces itself in its slot alone, so a slot
    # France cannot read is what makes the two disagree there: the version falls
    # back on the preferred one, and the refusal is worded in it.
    it 'refuses a request announcing, in its slot alone, a version France does not speak' do
      dated = earlier_line_envelope do |body|
        body.sub(EdmSpecification::V1_2.identifier, 'oots-edm:v1.0')
      end

      expect { dated.body.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C001')))
      expect(dated.specification).to eq(EdmSpecification.preferred)
    end
  end
end
