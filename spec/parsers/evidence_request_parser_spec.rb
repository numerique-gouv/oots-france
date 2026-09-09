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

  # `R-EDM-REQ-C012`, `C092`, `C108` and `C109`, refused where the requester is
  # read rather than among the checks of `validate!`, because an `EDM:ERR:0003`
  # names the requester by copying back the very values these rules judge —
  # `R-EDM-ERR-C010`, `C027`, `C028` and `C029` are FATAL on each of them in
  # the answer. Nothing conformant can carry these refusals, so nothing goes
  # back and the journal holds them alone.
  describe 'the requesting agent an answer would have to name' do
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

  # The agent classified `ER` alone, `Fixtures::REQUESTER_AGENT` saying why.
  def with_requester_agent(&) = envelope_with_requester_agent(&).body

  def with_requester_scheme(scheme)
    with_requester_agent { |agent| agent.sub(/schemeID="[^"]*"/, %(schemeID="#{scheme}")) }
  end

  def with_requester_id(id) = with_requester_agent { |agent| replace_id(agent, id) }

  def with_requester_name(name) = with_requester_agent { |agent| replace_name(agent, name) }

  def with_requester_language(value) = with_requester_agent { |agent| replace_language(agent, value) }

  def with_requester_country(code)
    with_requester_agent do |agent|
      agent.sub(/(<sdg:AdminUnitLevel1>)[^<]*/) { "#{Regexp.last_match(1)}#{code}" }
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
  def with_platform_scheme(scheme)
    with_platform_agent { |agent| agent.sub(/ schemeID="[^"]*"/, scheme.nil? ? '' : %( schemeID="#{scheme}")) }
  end

  def with_platform_id(id) = with_platform_agent { |agent| replace_id(agent, id) }

  def without_platform_identifier
    with_platform_agent { |agent| agent.sub(%r{<sdg:Identifier[^>]*>[^<]*</sdg:Identifier>}, '') }
  end

  def with_platform_name(name) = with_platform_agent { |agent| replace_name(agent, name) }

  def without_platform_name
    with_platform_agent { |agent| agent.sub(%r{<sdg:Name[^>]*>[^<]*</sdg:Name>}, '') }
  end

  def with_second_platform_name(second)
    with_platform_agent do |agent|
      agent.sub(%r{<sdg:Name[^>]*>[^<]*</sdg:Name>}) { |first| "#{first}#{second}" }
    end
  end

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

  # The three substitutions both agents take, written once: only the agent they
  # are applied to differs.
  def replace_id(agent, id) = agent.sub(/(<sdg:Identifier[^>]*>)[^<]*/) { "#{Regexp.last_match(1)}#{id}" }

  def replace_name(agent, name) = agent.sub(/(<sdg:Name[^>]*>)[^<]*/) { "#{Regexp.last_match(1)}#{name}" }

  # `nil` removes the attribute rather than emptying it: `R-EDM-REQ-C109`
  # normalises, so the two must be told apart by what is written and not by
  # what is read.
  def replace_language(agent, value)
    agent.sub(/<sdg:Name lang="[^"]*">/, value.nil? ? '<sdg:Name>' : %(<sdg:Name lang="#{value}">))
  end
end
