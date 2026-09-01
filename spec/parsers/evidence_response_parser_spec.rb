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
