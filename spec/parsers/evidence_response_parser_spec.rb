require 'rails_helper'

RSpec.describe EvidenceResponseParser do
  subject(:response) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')).body }

  it 'reads the identifier of the request being answered' do
    expect(response.request_id).to start_with('urn:uuid:')
  end

  it 'reads the identifier the response gives itself' do
    expect(response.response_id).to be_present
  end

  # « Evidence Identifier (for evidence response) » of chapter 4.8, taken from
  # the metadata of the object classified `MainEvidence` — never from the
  # package or from a supplementary document, which R-EDM-RESP-S063 shapes
  # differently.
  it 'reads the identifier of the evidence itself' do
    expect(response.evidence_identifier).to eq('f114a58d-3f5e-46f1-b067-d53f88c6619b')
  end

  # Chapter 4.5.2, which gives `sdg:IsAbout` its role: « Must contain the Minimum
  # Data Set part of the Evidence Subject attributes of the Evidence Request to
  # confirm identity matching. » It is the provider's own word on whom the
  # document is about, where the request holds whom it was asked about.
  describe 'the subject the provider confirms having matched' do
    it 'reads the natural person of R-EDM-RESP-S041' do
      expect(response.evidence_subject).to be_a(NaturalPerson)
        .and have_attributes(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')
    end

    # The one field a response may add to the Minimum Data Set it echoes. The
    # captured envelope carries none, so it is put there rather than assumed.
    it 'reads the eIDAS identifier where the response carries one' do
      identified = without do |body|
        body.sub('<sdg:FamilyName>', '<sdg:Identifier schemeID="eidas">FR/FI/123123123</sdg:Identifier><sdg:FamilyName>')
      end

      expect(identified.evidence_subject.eidas_identifier).to eq('FR/FI/123123123')
    end

    # The other element the rule admits beside the Minimum Data Set, and the one
    # a response may confirm where it may not confirm the level of assurance.
    # The captured envelope carries none, so it is put there rather than assumed.
    it 'reads the place of birth where the response carries one' do
      born = without do |body|
        body.sub('</sdg:DateOfBirth>', '</sdg:DateOfBirth><sdg:PlaceOfBirth>Aarhus</sdg:PlaceOfBirth>')
      end

      expect(born.evidence_subject.place_of_birth).to eq('Aarhus')
    end

    # `R-EDM-RESP-S041` closes its list on five elements, and neither the level
    # of assurance nor the sex is among them. A correspondent sending either is
    # breaking the rule; reading them would file a response as carrying what no
    # conformant one does, and the journal would show a subject richer than the
    # one actually confirmed.
    it 'keeps neither the level of assurance nor the sex the rule excludes' do
      overreaching = without do |body|
        body.sub('<sdg:FamilyName>',
          '<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance><sdg:Gender>Female</sdg:Gender><sdg:FamilyName>')
      end

      expect(overreaching.evidence_subject).to have_attributes(level_of_assurance: nil, gender: nil)
    end

    it 'reads the organisation R-EDM-RESP-S042 admits in its place' do
      expect(about_an_organisation.evidence_subject).to be_a(LegalPerson)
        .and have_attributes(eidas_identifier: 'FR/DE/A2635542Y', legal_name: 'Établissements Dupont & Fils')
    end

    # `R-EDM-RESP-S042` (FATAL) admits the eIDAS identifier and the legal name
    # and nothing else, where a request may name as many sectoral identifiers as
    # chapter 4.5.1 publishes schemes. A correspondent sending one anyway is
    # breaking the rule, and filing it would record an identifier no conformant
    # response carries — the breach itself is reported nowhere, `violations`
    # carrying no rule about the content of `sdg:IsAbout`.
    it 'keeps none of the sectoral identifiers that rule excludes' do
      carrying = about_an_organisation(
        is_about_legal_person.sub('<sdg:LegalName>', '<sdg:Identifier schemeID="VAT">FR12345678901</sdg:Identifier>' \
                                                     '<sdg:LegalName>'),
      )

      expect(carrying.evidence_subject.identifiers).to be_empty
    end

    # `NaturalPerson` requires the three fields the canonical key is made of, and
    # this one is never asked to validate: what a provider cut short is read as
    # it came, and `AuditEvent.canonical_key` composes no key for it — the
    # departure the journal keeps rather than the exchange it would have cost.
    it 'reads a person short of a field of the canonical key rather than refusing' do
      stripped = without { |body| body.sub(%r{<sdg:GivenName>.*?</sdg:GivenName>}, '') }

      expect(stripped.evidence_subject)
        .to have_attributes(family_name: 'Dupont', given_name: nil, date_of_birth: '1965-11-25')
    end

    # `LegalPerson` refuses an organisation without its eIDAS identifier, and
    # this one is never asked to validate either: an exchange that can be settled
    # must not die over a column only the journal reads.
    it 'reads an organisation short of its identifier rather than refusing' do
      stripped = about_an_organisation(
        is_about_legal_person.sub(%r{<sdg:LegalPersonIdentifier.*</sdg:LegalPersonIdentifier>}, ''),
      )

      expect(stripped.evidence_subject)
        .to have_attributes(eidas_identifier: nil, legal_name: 'Établissements Dupont & Fils')
    end

    # Emptied and not removed, which is another value entirely: `text_at` reads
    # a missing element as `nil` and a present but empty one as `""`, and only
    # the second survives the `attributes.compact` of `AuditEvent.subject`. It
    # is the form that composed the key `legal|` for every organisation answered
    # that way, so the chain is asserted here where it starts rather than only
    # on a hand-built hash.
    it 'reads an organisation whose identifier came back empty as empty, not absent' do
      emptied = about_an_organisation(
        is_about_legal_person.sub(%r{<sdg:LegalPersonIdentifier[^>]*>.*?</sdg:LegalPersonIdentifier>},
          '<sdg:LegalPersonIdentifier></sdg:LegalPersonIdentifier>'),
      )

      expect(emptied.evidence_subject.eidas_identifier).to eq('')
      expect(AuditEvent.subject(emptied.evidence_subject)[:evidence_subject_key]).to be_nil
    end
  end

  describe 'the provider that answered' do
    it 'is the agent classified EP' do
      expect(response.provider.ebms_identity.id).to be_present
    end

    it 'carries the scheme its identifier belongs to' do
      expect(response.provider.ebms_identity.type_id).to be_present
    end

    it 'names the country the answer came from' do
      expect(response.provider_country).to eq(response.provider.address.country)
    end
  end

  it 'reads the requester the answer is owed to' do
    expect(response.requester.id).to eq('00000000000002')
  end

  # Chapter 4.5.2: the status tells a deferral from an answer carrying the
  # document, and `R-EDM-RESP-S045` puts the announced date in a slot that
  # `R-EDM-RESP-S014` forbids to any other status.
  describe 'a response announcing the evidence for later' do
    subject(:deferred) { RetrievedMessageParser.new(built_envelope('reponseDifferee')).body }

    it 'is recognised by its status' do
      expect(deferred).to be_unavailable
    end

    it 'reads the date the evidence is announced for' do
      expect(deferred.response_available_at).to eq(Time.zone.parse('2026-08-07T10:00:00Z'))
    end

    it 'still correlates to the request it answers' do
      expect(deferred.request_id).to eq('urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700')
    end

    it 'is not what a response carrying the evidence looks like' do
      expect(response).not_to be_unavailable
      expect(response.response_available_at).to be_nil
    end

    # Refusing the message over its date would settle as unreadable an exchange
    # the announcement exists to keep from failing.
    it 'answers nil for a date that cannot be read' do
      unreadable = with_deferral { |body| body.sub('2026-08-07T10:00:00.000Z', 'la semaine prochaine') }

      expect(unreadable.response_available_at).to be_nil
      expect(unreadable).to be_unavailable
    end

    # `R-EDM-RESP-S014` forbids the slot to any status but this one, so the
    # reading answers nothing for a response that carries it against the rule.
    it 'answers nil on a response that carries the slot without the status' do
      contradictory = with_deferral do |body|
        body.sub('ResponseStatusType:Unavailable', 'ResponseStatusType:Success')
      end

      expect(contradictory).not_to be_unavailable
      expect(contradictory.response_available_at).to be_nil
    end

    # `Time.zone.iso8601` rolls a day that does not exist into the next month.
    # A date invented on a correspondent's behalf is worse than none.
    it 'answers nil for a day that does not exist, rather than the day after' do
      impossible = with_deferral { |body| body.sub('2026-08-07T10:00:00.000Z', '2026-02-30T10:00:00.000Z') }

      expect(impossible.response_available_at).to be_nil
    end

    it 'answers nil when the slot is absent altogether' do
      stripped = with_deferral do |body|
        body.sub(%r{<rim:Slot name="ResponseAvailableDateTime">.*?</rim:Slot>}m, '')
      end

      expect(stripped.response_available_at).to be_nil
    end
  end

  # No error path runs from a portal back to a provider, so a response that is
  # deliverable must not be refused over a field only the journal reads: the
  # exchange would die and nobody would be told.
  describe 'what it tolerates rather than refuses' do
    it 'answers nil when no object is classified MainEvidence' do
      expect(without { |body| body.gsub('MainEvidence', 'Annexe') }.evidence_identifier).to be_nil
    end

    it 'answers nil when the metadata carries no identifier' do
      stripped = without { |body| body.sub(%r{<sdg:Identifier>[^<]*</sdg:Identifier>}, '') }

      expect(stripped.evidence_identifier).to be_nil
    end

    it 'answers nil for the provider when no agent is classified EP' do
      expect(without { |body| body.gsub('>EP<', '>IP<') }.provider).to be_nil
    end

    # `R-EDM-RESP-S062` requires the element of whoever writes a response, and
    # nothing here refuses one that omits it: the journal records the absence
    # instead.
    it 'answers nil for the subject when the metadata carries no IsAbout' do
      stripped = without { |body| body.sub(%r{<sdg:IsAbout>.*?</sdg:IsAbout>}m, '') }

      expect(stripped.evidence_subject).to be_nil
    end

    # The two branches of the `xs:choice` are what is looked for, and not the
    # choice itself: an empty one would otherwise read as a person carrying no
    # field at all, which the journal would file as a subject.
    it 'answers nil for a subject naming neither a person nor an organisation' do
      emptied = without { |body| body.sub(%r{<sdg:IsAbout>.*?</sdg:IsAbout>}m, '<sdg:IsAbout/>') }

      expect(emptied.evidence_subject).to be_nil
    end

    it 'answers nil for the subject when no object is classified MainEvidence' do
      expect(without { |body| body.gsub('MainEvidence', 'Annexe') }.evidence_subject).to be_nil
    end
  end

  # The rules of chapter 4.6 a reader settles on the response alone. None of them
  # refuses anything: the chapter assigns the duty of validating to nobody, and
  # no error path runs from a portal back to a provider — the journal names the
  # rule and the exchange goes on.
  describe 'the business rules it confronts a response to' do
    let(:required_slots) { EvidenceResponseParser::REQUIRED_SLOTS }

    # Both reference answers are conformant, so anything reported here is a
    # reader inventing a breach rather than a message committing one.
    it 'finds nothing to say about the answer a real gateway delivered' do
      expect(response.violations).to be_empty
    end

    it 'finds nothing to say about an answer announcing the evidence for later' do
      expect(RetrievedMessageParser.new(built_envelope('reponseDifferee')).body.violations).to be_empty
    end

    # `R-EDM-RESP-S009` to `-S013`, one rule per slot, each counting exactly one.
    it 'names the rule requiring each slot a response leaves out' do
      required_slots.each do |name, rule|
        expect(rules_broken_by { |body| body.sub(slot(name), '') }).to include(rule)
      end
    end

    # The rules count slots (`count(…)=1`) rather than look one up: two of the
    # same name leave which one is meant undecided.
    it 'names the same rule for a slot a response carries twice' do
      doubled = rules_broken_by { |body| body.sub(slot('IssueDateTime')) { |found| found * 2 } }

      expect(doubled).to include('R-EDM-RESP-S011')
    end

    it 'refuses a version that is not the one the EDM fixes' do
      expect(rules_broken_by { |body| body.sub('oots-edm:v2.0', 'oots-edm:v1.0') }).to include('R-EDM-RESP-C002')
    end

    # The Schematron hangs its content assertions on the value element, so an
    # emptied slot would break nothing; it is reported all the same, or no rule
    # would see it at all.
    it 'refuses a slot that is there and carries nothing' do
      emptied = rules_broken_by do |body|
        body.sub(/(<rim:Slot name="EvidenceResponseIdentifier">.*?<rim:Value>)[^<]*/m, '\\1')
      end

      expect(emptied).to include('R-EDM-RESP-C003')
    end

    it 'refuses a response that declares no status at all' do
      expect(rules_broken_by { |body| body.sub(/ status="[^"]*"/, '') })
        .to include('R-EDM-RESP-S005', 'R-EDM-RESP-S006')
    end

    it 'refuses a status that is neither Success nor Unavailable' do
      expect(rules_broken_by { |body| body.sub('ResponseStatusType:Success', 'ResponseStatusType:Failure') })
        .to include('R-EDM-RESP-S006')
    end

    it 'refuses a deferral that announces no date' do
      broken = with_deferral { |body| body.sub(slot('ResponseAvailableDateTime'), '') }

      expect(broken.violations.map(&:rule)).to include('R-EDM-RESP-S045')
    end

    it 'refuses the announced date on a response that is not a deferral' do
      broken = with_deferral { |body| body.sub('ResponseStatusType:Unavailable', 'ResponseStatusType:Success') }

      expect(broken.violations.map(&:rule)).to include('R-EDM-RESP-S014')
    end

    it 'refuses an answered request identifier that carries no urn:uuid: prefix' do
      expect(rules_broken_by { |body| body.sub('requestId="urn:uuid:', 'requestId="') })
        .to include('R-EDM-RESP-S004')
    end

    # An attribute emptied is an attribute still there, so it is the shape that
    # is broken and not the presence — the same line `-C006` walks, and the one
    # that reading a node set as a value has already got wrong twice.
    it 'names the rule shaping the answered request identifier, and it alone, when it is empty' do
      broken = rules_broken_by { |body| body.sub(/ requestId="[^"]*"/, ' requestId=""') }

      expect(broken).to include('R-EDM-RESP-S004')
      expect(broken).not_to include('R-EDM-RESP-S003')
    end

    # `-S004` is asserted against the attribute node, so an absent one leaves it
    # without a context and it says nothing; `-S003` is what a response missing
    # it altogether breaks. Where the status pair, both of it asserted against
    # the response, has an absent attribute break the two at once.
    it 'names the rule requiring the answered request identifier, and it alone, when it is missing' do
      broken = rules_broken_by { |body| body.sub(/ requestId="[^"]*"/, '') }

      expect(broken).to include('R-EDM-RESP-S003')
      expect(broken).not_to include('R-EDM-RESP-S004')
    end

    # The response identifier is the bare UUID, where the attribute above is the
    # prefixed one: giving it the prefix breaks the rule just as dropping it
    # breaks the other.
    it 'refuses a response identifier that is not a bare UUID' do
      expect(rules_broken_by { |body| body.sub('728c1aa1', 'urn:uuid:728c1aa1') })
        .to include('R-EDM-RESP-C003')
    end

    it 'refuses an issue date that is not shaped like a date and a time' do
      expect(rules_broken_by { |body| body.sub('2026-08-11T09:22:22.312Z', 'pas une date') })
        .to include('R-EDM-RESP-C004')
    end

    it 'refuses an announced date that is not shaped like a date and a time' do
      broken = with_deferral { |body| body.sub('2026-08-07T10:00:00.000Z', 'pas une date') }

      expect(broken.violations.map(&:rule)).to include('R-EDM-RESP-C005')
    end

    it 'refuses a provider slot carrying no agent classified EP' do
      expect(rules_broken_by { |body| body.sub('>EP<', '>IP<') }).to include('R-EDM-RESP-C046')
    end

    # The upper bound, which `count(…)=1` refuses as it refuses zero.
    it 'refuses a provider slot carrying two agents classified EP' do
      doubled = rules_broken_by do |body|
        body.sub(%r{<rim:Element xsi:type="rim:AnyValueType">.*?</rim:Element>}m) { |found| found * 2 }
      end

      expect(doubled).to include('R-EDM-RESP-C046')
    end

    it 'refuses a provider identifier that does not name its scheme' do
      expect(rules_broken_by { |body| body.sub(/ schemeID="[^"]*"/, '') })
        .to include('R-EDM-RESP-C006')
    end

    # The rule asks for the attribute, not for a value in it: an empty one
    # satisfies it, and reporting it would accuse a correspondent of a breach
    # the Schematron clears.
    it 'finds nothing to say about a provider identifier whose scheme is named but empty' do
      expect(rules_broken_by { |body| body.sub(/ schemeID="[^"]*"/, ' schemeID=""') })
        .not_to include('R-EDM-RESP-C006')
    end

    it 'refuses a response carrying no object list at all' do
      expect(rules_broken_by { |body| body.sub(%r{<rim:RegistryObjectList>.*</rim:RegistryObjectList>}m, '') })
        .to include('R-EDM-RESP-S007')
    end

    it 'refuses an exception inside an answer that says it succeeded' do
      exception = '<rs:Exception xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0" code="EDM:ERR:0004"/>'
      broken = rules_broken_by { |body| body.sub('</query:QueryResponse>', "#{exception}</query:QueryResponse>") }

      expect(broken).to include('R-EDM-RESP-S008')
    end

    it 'refuses a slot the response is not allowed to carry' do
      surplus = '<rim:Slot name="Bizarre"><rim:SlotValue xsi:type="rim:StringValueType">' \
                '<rim:Value>x</rim:Value></rim:SlotValue></rim:Slot>'
      broken = rules_broken_by { |body| body.sub('<rim:RegistryObjectList>', "#{surplus}<rim:RegistryObjectList>") }

      expect(broken).to include('R-EDM-RESP-S016')
    end

    # What the comment on `-S008` claims: a success is not the only response
    # forbidden an exception, `-S016` counting every child.
    it 'refuses an exception inside a deferral too, by the rule that counts children' do
      exception = '<rs:Exception xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0" code="EDM:ERR:0004"/>'
      broken = with_deferral { |body| body.sub('</query:QueryResponse>', "#{exception}</query:QueryResponse>") }

      expect(broken.violations.map(&:rule)).to include('R-EDM-RESP-S016')
      expect(broken.violations.map(&:rule)).not_to include('R-EDM-RESP-S008')
    end

    it 'names the rule and what the rule says' do
      broken = without { |body| body.sub('oots-edm:v2.0', 'oots-edm:v1.0') }

      expect(broken.violations.map(&:sentence))
        .to include('R-EDM-RESP-C002 : La réponse reçue annonce oots-edm:v1.0, et non oots-edm:v2.0.')
    end

    # All of them, and not the first: the journal keeps one line per arrival, so
    # a reading that stopped at the first breach would hide the rest for good.
    it 'reports every rule a response breaks at once' do
      broken = rules_broken_by do |body|
        body.sub('oots-edm:v2.0', 'oots-edm:v1.0').sub(slot('IssueDateTime'), '')
      end

      expect(broken).to include('R-EDM-RESP-C002', 'R-EDM-RESP-S011')
    end

    # Nothing here refuses, so a response breaking every rule at once is still
    # read, still journalled and still delivered.
    it 'still reads a response that breaks the rules it can break' do
      broken = without do |body|
        body.sub(slot('IssueDateTime'), '').sub('oots-edm:v2.0', 'oots-edm:v1.0')
          .sub('ResponseStatusType:Success', 'ResponseStatusType:Failure')
      end

      expect(broken.violations.size).to be > 1
      expect(broken.evidence_identifier).to eq('f114a58d-3f5e-46f1-b067-d53f88c6619b')
      expect(broken.requester.id).to eq('00000000000002')
    end

    # A raise would cost every violation already found, the array being built
    # in one go, and `AuditTrail` would make the loss indistinguishable from a
    # conformant response. The invariant is locked here, not in a comment.
    it 'reads a document stripped of everything without ever raising' do
      stripped = without do |body|
        required_slots.keys.reduce(body) { |left, name| left.sub(slot(name), '') }
          .sub(/ status="[^"]*"/, '').sub(/ requestId="[^"]*"/, '')
          .sub(%r{<rim:RegistryObjectList>.*</rim:RegistryObjectList>}m, '')
      end

      expect { stripped.violations }.not_to raise_error
      expect(stripped.violations.map(&:rule)).to include(*required_slots.values, 'R-EDM-RESP-S007')
    end

    # Chapter 4.5.2 §2.6, « Evidence Packaging », and the twenty rules `-S046` to
    # `-S066` it publishes with the 2.0 line — `-S064` on neither. Nothing here
    # is refused either: the package governs what the journal says of a response
    # and nothing else, France delivering the `application/pdf` part its header
    # declares and never a document the package points at.
    describe 'the packaging of the response' do
      it 'refuses an object of the top-level list that is not a package' do
        expect(rules_broken_by { |body| body.sub(package_type, 'xsi:type="rim:ExtrinsicObjectType"') })
          .to contain_exactly('R-EDM-RESP-S066')
      end

      # `count(rim:RegistryObjectList)=1`, so a package holding none breaks it.
      # Emptying the package takes its nested list with it, which is why nothing
      # else is reported: every rule below hangs on an object of that list.
      it 'refuses a package that holds no nested list' do
        expect(rules_broken_by { |body| body.sub(%r{(#{package_type}[^>]*>).*(</rim:RegistryObject>)}m, '\1\2') })
          .to contain_exactly('R-EDM-RESP-S046')
      end

      # `-S047` executes the floor of §2.6 alone, `count(…)>0`, where the prose
      # says « At least one » and, four lines below, « Exactly one ». The
      # assertion decides.
      it 'refuses a package whose list classifies nothing as the main evidence' do
        expect(rules_broken_by { |body| body.gsub('MainEvidence', 'Annexe') }).to include('R-EDM-RESP-S047')
      end

      # No status filter on that context, where `-S033` to `-S036` all carry
      # one: §2.6 asks a deferral for an empty list, which is not what a package
      # holding an unclassified object is.
      it 'refuses it in a deferral too, that rule asking nothing of the status' do
        deferred = rules_broken_by do |body|
          body.gsub('MainEvidence', 'Annexe').sub('ResponseStatusType:Success', 'ResponseStatusType:Unavailable')
        end

        expect(deferred).to include('R-EDM-RESP-S047')
      end

      # §2.1 lets the nested list « be empty if no matching Evidence is
      # available », where §2.6 asks it for « one or more (1..n) ». The two
      # contradict, `-S047` is the only assertion tiring on it, and it refuses
      # the empty one — which is what gets reported.
      it 'refuses an empty nested list, the prose of §2.1 notwithstanding' do
        expect(rules_broken_by { |body| body.sub(evidence_object, '') }).to include('R-EDM-RESP-S047')
      end

      # The other half of the contradiction, and the reason the assertion is
      # what this reader follows: a second main document breaks no published
      # rule, so naming one would accuse a correspondent of nothing.
      it 'finds nothing to say about a package classifying two objects as the main evidence' do
        doubled = rules_broken_by do |body|
          body.sub(evidence_object) { |object| object + object.gsub('ab42bdbd', 'ab42bdbe').gsub('2f3a1a65', '2f3a1a66') }
        end

        expect(doubled).to be_empty
      end
    end

    # What each object of a package is: `-S048`, `-S049` and `-S065`.
    describe 'the classification of the objects of a package' do
      it 'refuses an object carrying no classification of the EDM scheme' do
        expect(rules_broken_by { |body| body.sub(%r{<rim:Classification[^>]*/>}m, '') })
          .to include('R-EDM-RESP-S048')
      end

      it 'refuses a classification node that is none of the four' do
        expect(rules_broken_by { |body| body.sub('classificationNode="MainEvidence"', 'classificationNode="Appendix"') })
          .to include('R-EDM-RESP-S049')
      end

      it 'refuses a classification whose id is not a prefixed UUID' do
        expect(rules_broken_by { |body| body.sub(/<rim:Classification id="[^"]*"/, '<rim:Classification id="c1"') })
          .to include('R-EDM-RESP-S065')
      end

      # Several lines of one rule sit side by side in a single `detail`, and the
      # `id` is what tells them apart — so an object carrying none has to read
      # as words rather than as a blank.
      it 'still names the object it accuses when that object carries no id' do
        unidentified = without do |body|
          body.sub(%r{<rim:Classification[^>]*/>}m, '').sub(/ id="urn:uuid:ab42bdbd[^"]*"/, '')
        end

        expect(unidentified.violations.map(&:sentence))
          .to include(a_string_including('R-EDM-RESP-S048').and(a_string_including('sans identifiant')))
      end

      # The rule requiring the `id` is the one case where the `id` cannot name
      # the object, so the sentence falls back on its `@xsi:type` — and says so
      # when there is not one of those either.
      it 'names an object requiring an id by its type, or says it carries none' do
        untyped = without do |body|
          body.sub(' xsi:type="rim:ExtrinsicObjectType"', '').sub(/ id="urn:uuid:ab42bdbd[^"]*"/, '')
        end

        expect(untyped.violations.map(&:sentence))
          .to include(a_string_including('R-EDM-RESP-S036').and(a_string_including('sans type')))
      end

      # The context of `-S065` is the attribute itself, so a classification
      # carrying none opens it on nothing — a hole of the Schematron kept rather
      # than closed, refusing what a FATAL rule admits being the fault this
      # reader exists to avoid.
      it 'finds nothing to say about a classification carrying no id at all' do
        expect(rules_broken_by { |body| body.sub(/<rim:Classification id="[^"]*"/, '<rim:Classification') })
          .not_to include('R-EDM-RESP-S065')
      end
    end

    # `-S033` to `-S037`, the one family both lines publish — on the objects of
    # the package in 2.0, on those of the flat list in 1.2.
    describe 'what each object identifies and points at' do
      it 'refuses an object of a package carrying no repository item' do
        expect(rules_broken_by { |body| body.sub(%r{<rim:RepositoryItemRef[^>]*/>}, '') })
          .to include('R-EDM-RESP-S033')
      end

      it 'refuses the same of an object of the flat list of a 1.2 response' do
        flat = earlier_line_response { |body| body.sub(%r{<rim:RepositoryItemRef[^>]*/>}, '') }

        expect(flat.body.violations.map(&:rule)).to include('R-EDM-RESP-S033')
      end

      # `-S033` excepts a package and an association in 2.0.1 and excepts nothing
      # in 1.2.5, whose flat list holds documents and nothing else. The very
      # object the later line exempts is therefore the one the earlier refuses.
      it 'refuses an association of a flat 1.2 list, a line that excepts nothing' do
        flat = earlier_line_response do |body|
          body.sub('</rim:RegistryObjectList>', "#{annex_association}</rim:RegistryObjectList>")
        end

        expect(flat.body.violations.map(&:rule)).to include('R-EDM-RESP-S033')
      end

      it 'refuses a repository item that names no charge' do
        expect(rules_broken_by { |body| body.sub(/ xlink:href="[^"]*"/, '') })
          .to include('R-EDM-RESP-S034')
      end

      it 'refuses a repository item that carries no title' do
        expect(rules_broken_by { |body| body.sub(/ xlink:title="[^"]*"/, '') })
          .to include('R-EDM-RESP-S035')
      end

      # `-S036` requires the attribute and `-S037` shapes it, and the two never
      # fire together: `-S037` is asserted against the attribute node, which an
      # object carrying none never opens. The same split as `-S003` and `-S004`
      # on the request identifier.
      it 'names the rule requiring the id, and it alone, when an object carries none' do
        broken = rules_broken_by { |body| body.sub(/ id="urn:uuid:ab42bdbd[^"]*"/, '') }

        expect(broken).to include('R-EDM-RESP-S036')
        expect(broken).not_to include('R-EDM-RESP-S037')
      end

      it 'refuses an id that is not a prefixed UUID' do
        expect(rules_broken_by { |body| body.sub(/ id="urn:uuid:ab42bdbd[^"]*"/, ' id="obj1"') })
          .to include('R-EDM-RESP-S037')
      end

      # `-S037` hangs on the attribute with no status filter, where `-S036`
      # holds a success alone: a malformed id in a deferral names the shape and
      # never the presence.
      it 'names the rule shaping the id, and not the one requiring it, in a deferral' do
        deferred = rules_broken_by do |body|
          body.sub(/ id="urn:uuid:ab42bdbd[^"]*"/, ' id="obj1"')
            .sub('ResponseStatusType:Success', 'ResponseStatusType:Unavailable')
        end

        expect(deferred).to include('R-EDM-RESP-S037')
        expect(deferred).not_to include('R-EDM-RESP-S036')
      end
    end

    # §2.6 « Associations Between Evidence Objects », read forwards and
    # backwards: `-S050` to `-S061`.
    describe 'how the objects of a package are joined' do
      it 'finds nothing to say about an annex joined to the main evidence as §2.6 asks' do
        expect(response_with_an_annex.body.violations).to be_empty
      end

      it 'refuses a supplementary object that is the source of no association' do
        expect(rules_broken_by_annex { |body| body.sub(annex_association, '') })
          .to contain_exactly('R-EDM-RESP-S050')
      end

      it 'refuses an association carrying no source' do
        expect(rules_broken_by_annex { |body| body.sub(/ sourceObject="[^"]*"/, '') })
          .to include('R-EDM-RESP-S051')
      end

      it 'refuses an association carrying no target' do
        expect(rules_broken_by_annex { |body| body.sub(/ targetObject="[^"]*"/, '') })
          .to include('R-EDM-RESP-S055')
      end

      # The three couples, each written out rather than looped over one rule:
      # `-S052`/`-S056` bind the annex, `-S053`/`-S057` the human-readable
      # version and `-S054`/`-S058` the translation. Both ends of an association
      # pointing at an object no list holds break the two at once.
      {
        'Annex' => %w[R-EDM-RESP-S052 R-EDM-RESP-S056],
        'HumanReadableVersion' => %w[R-EDM-RESP-S053 R-EDM-RESP-S057],
        'Translation' => %w[R-EDM-RESP-S054 R-EDM-RESP-S058],
      }.each do |node, (source, target)|
        it "names #{source} and #{target} for a #{node} association joining nothing" do
          adrift = rules_broken_by_annex do |body|
            body.sub('AssociationType:Annex"', %(AssociationType:#{node}"))
              .sub(/ sourceObject="[^"]*"/, %( sourceObject="#{unknown_object_id}"))
              .sub(/ targetObject="[^"]*"/, %( targetObject="#{unknown_object_id}"))
          end

          expect(adrift).to include(source, target)
        end
      end

      # And the same three read backwards, where the numbering crosses over:
      # `-S059` is the annex's, but `-S060` is the **translation**'s and `-S061`
      # the **human-readable version**'s. The association is given a type of the
      # registry that none of the three couples names, so that only the rule
      # typing it has anything to say.
      {
        'Annex' => 'R-EDM-RESP-S059',
        'Translation' => 'R-EDM-RESP-S060',
        'HumanReadableVersion' => 'R-EDM-RESP-S061',
      }.each do |node, rule|
        it "names #{rule} for a #{node} joined to the main evidence under another type" do
          mistyped = rules_broken_by_annex do |body|
            body.sub('classificationNode="Annex"', %(classificationNode="#{node}"))
              .sub('AssociationType:Annex"', 'AssociationType:RelatedTo"')
          end

          expect(mistyped).to contain_exactly(rule)
        end
      end

      # The classification of the source is read under any scheme by `-S059` to
      # `-S061` and under the EDM one alone by `-S052` to `-S058`: an annex
      # classified `Translation` under the EDM scheme, joined by an association
      # still typed as an annex, breaks the forward rule.
      it 'refuses an association typed as an annex whose source is classified otherwise' do
        expect(rules_broken_by_annex { |body| body.sub('classificationNode="Annex"', 'classificationNode="Translation"') })
          .to include('R-EDM-RESP-S052')
      end

      # The target is retargeted through the attribute, which the annexed body
      # carries once, and never through the value of `MAIN_EVIDENCE_ID`, which it
      # carries twice — the `id` of the main object comes first, so substituting
      # the value would rename that object and leave the association pointing at
      # an `id` no object holds. The rule would still be named, by the path the
      # spec above already covers, and this case — a target that exists and is
      # classified wrong — would be tested nowhere.
      it 'refuses an association typed as an annex pointing back at the annex itself' do
        expect(rules_broken_by_annex { |body| body.sub(/ targetObject="[^"]*"/, %( targetObject="#{EvidencePackage::ANNEX_ID}")) })
          .to include('R-EDM-RESP-S056')
      end
    end

    # What the `sdg:Evidence` of each object carries: `-S062` on the main
    # document, `-S063` on everything beside it.
    describe 'what each object of a package says of itself' do
      # The assertion requires six elements where the message of the rule names
      # five, `Distribution` being the one it leaves out. The assertion is the
      # rule — the same split this reader already makes for `-S038`.
      it 'refuses a main evidence missing one of the six elements the assertion requires' do
        expect(rules_broken_by { |body| body.sub(%r{<sdg:IssuingAuthority>.*?</sdg:IssuingAuthority>}m, '') })
          .to include('R-EDM-RESP-S062')
      end

      it 'refuses a supplementary object carrying what the main evidence alone may carry' do
        carrying = rules_broken_by_annex do |body|
          body.sub(annex_object, annex_object.sub('<sdg:Distribution>', "#{is_about_a_person}<sdg:Distribution>"))
        end

        expect(carrying).to include('R-EDM-RESP-S063')
      end
    end

    # `-S041` and `-S042`, the closed lists chapter 4.5.2 §3.3 puts on the
    # subject a provider confirms having matched. Named and never refused, like
    # everything else here — and the reading of the subject does not move: what
    # a conformant response carries is what is filed, and what it adds is what
    # the journal names.
    describe 'the subject each object confirms' do
      it 'names the rule closing the list when a person carries an element besides' do
        overreaching = rules_broken_by do |body|
          body.sub('<sdg:FamilyName>', '<sdg:Gender>Female</sdg:Gender><sdg:FamilyName>')
        end

        expect(overreaching).to include('R-EDM-RESP-S041')
      end

      # The two readings part company here, which is the whole point: the sex is
      # named as a breach and is not filed as a field of the subject.
      it 'files nothing of the element it names' do
        overreaching = without do |body|
          body.sub('<sdg:FamilyName>', '<sdg:Gender>Female</sdg:Gender><sdg:FamilyName>')
        end

        expect(overreaching.evidence_subject)
          .to have_attributes(family_name: 'Dupont', gender: nil, place_of_birth: nil)
      end

      it 'names the rule closing the list of an organisation carrying a sectoral identifier' do
        carrying = about_an_organisation(
          is_about_legal_person.sub('<sdg:LegalName>', '<sdg:Identifier schemeID="VAT">FR12345678901</sdg:Identifier>' \
                                                       '<sdg:LegalName>'),
        )

        expect(carrying.violations.map(&:rule)).to include('R-EDM-RESP-S042')
        expect(carrying.evidence_subject)
          .to have_attributes(eidas_identifier: 'FR/DE/A2635542Y', legal_name: 'Établissements Dupont & Fils')
      end

      # Neither context filters on a classification, so an annex naming a subject
      # is judged exactly as the main document is — beside `-S063`, which is what
      # forbids it a subject at all.
      it 'judges the subject of an annex as it judges the main evidence' do
        carrying = rules_broken_by_annex do |body|
          body.sub(annex_object, annex_object.sub('<sdg:Distribution>', "#{is_about_an_organisation}<sdg:Distribution>"))
        end

        expect(carrying).to include('R-EDM-RESP-S042', 'R-EDM-RESP-S063')
      end

      # The 1.2 line anchors the two rules on the objects of the flat list, where
      # 2.0.1 moves them one level down with the packaging.
      it 'names the rule on the flat list of a 1.2 response' do
        flat = earlier_line_response do |body|
          body.sub('<sdg:FamilyName>', '<sdg:Gender>Female</sdg:Gender><sdg:FamilyName>')
        end

        expect(flat.body.violations.map(&:rule)).to include('R-EDM-RESP-S041')
      end

      it 'says nothing of a subject carrying only what the rules admit' do
        expect(about_an_organisation.violations.map(&:rule)).not_to include('R-EDM-RESP-S042')
      end
    end

    # A subject the rule admits nothing of, on an object that may carry none:
    # `-S063` names the `sdg:IsAbout` and `-S042` what is inside it.
    def is_about_an_organisation
      '<sdg:IsAbout><sdg:LegalPerson><sdg:LegalPersonIdentifier>FR/DE/A2635542Y</sdg:LegalPersonIdentifier>' \
        '<sdg:LegalName>Dupont</sdg:LegalName><sdg:Identifier schemeID="VAT">FR12345678901</sdg:Identifier>' \
        '</sdg:LegalPerson></sdg:IsAbout>'
    end

    # Nothing of the packaging refuses anything either: the evidence is
    # delivered, the journal names the rule, and the exchange settles.
    describe 'what a broken package costs the exchange' do
      subject(:unclassified) { envelope_with_body('reponseAvecPieceJointe') { |body| body.gsub('MainEvidence', 'Annexe') } }

      it 'still delivers the evidence the header declares' do
        expect(unclassified.evidence).to have_attributes(mime_type: 'application/pdf', content: be_present)
      end

      it 'reads a package broken in every way it can be broken without ever raising' do
        stripped = without do |body|
          body.sub(package_type, 'xsi:type="rim:ExtrinsicObjectType"').gsub('MainEvidence', 'Annexe')
            .sub(%r{<rim:RepositoryItemRef[^>]*/>}, '').sub(/ id="urn:uuid:ab42bdbd[^"]*"/, ' id="obj1"')
        end

        expect { stripped.violations }.not_to raise_error
        expect(stripped.violations.map(&:rule))
          .to include('R-EDM-RESP-S066', 'R-EDM-RESP-S047', 'R-EDM-RESP-S033', 'R-EDM-RESP-S037')
      end

      # The line of the rules is the one the response announces, and the line of
      # the exchange judges `-C002` alone — which is what makes a correspondent's
      # drift visible instead of self-justifying.
      it 'judges a 2.0 response by the 2.0 packaging even on an exchange opened in 1.2' do
        expect(response.violations(expected: EdmSpecification::V1_2).map(&:rule))
          .to contain_exactly('R-EDM-RESP-C002')
      end
    end

    # A supplementary document is the one thing the whole `sdg:IsAbout` of a
    # response may not carry, `-S063` naming it first.
    def is_about_a_person
      '<sdg:IsAbout><sdg:NaturalPerson><sdg:FamilyName>Dupont</sdg:FamilyName></sdg:NaturalPerson></sdg:IsAbout>'
    end

    def package_type = 'xsi:type="rim:RegistryPackageType"'

    # The object the captured response classifies `MainEvidence`, from its
    # opening tag to its own closing one — the first `</rim:RegistryObject>` the
    # body carries, the package closing after it.
    def evidence_object = %r{<rim:RegistryObject xsi:type="rim:ExtrinsicObjectType".*?</rim:RegistryObject>}m

    # An id no object of any list carries, so that an association naming it
    # joins nothing at all.
    def unknown_object_id = 'urn:uuid:00000000-0000-4000-8000-000000000000'

    def rules_broken_by_annex(&) = response_with_an_annex(&).body.violations.map(&:rule)

    def slot(name) = %r{<rim:Slot name="#{name}">.*?</rim:Slot>}m

    def rules_broken_by(&) = without(&).violations.map(&:rule)
  end

  def without(&) = envelope_with_body('reponseAvecPieceJointe', &).body

  def about_an_organisation(subject = is_about_legal_person) = response_about_an_organisation(subject).body

  # The deferred answer is a built envelope, where `envelope_with_body` reads
  # from `incoming/reel/`: altering it needs its own hand.
  def with_deferral
    document = Nokogiri::XML(built_envelope('reponseDifferee'))
    value = document.xpath('//payload/value').first
    value.content = Base64.strict_encode64(yield(Base64.decode64(value.text)))

    RetrievedMessageParser.new(document.to_xml).body
  end
end
