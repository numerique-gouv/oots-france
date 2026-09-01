require 'rails_helper'

RSpec.describe AuditEvent do
  subject(:event) { create(:audit_event) }

  it { is_expected.to validate_presence_of(:occurred_at) }
  it { is_expected.to validate_inclusion_of(:event_type).in_array(described_class::EVENT_TYPES) }

  # The trace is what an audit rests on, and one that can be rewritten after the
  # fact rests on nothing.
  it 'refuses to be rewritten once written' do
    expect { event.update!(detail: 'autre chose') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe 'the personal data it carries' do
    subject(:event) { create(:audit_event, :about_a_person) }

    # Chapter 4.8 names the evidence subject among what must be logged, and the
    # log outlives the exchange by twelve months: a database dump must not hand
    # over who asked for what.
    it 'is unreadable in the column that holds it' do
      stored = described_class.connection.select_value(
        "SELECT evidence_subject FROM audit_events WHERE id = #{event.id}",
      )

      expect(stored).not_to include('Königreich')
      expect(event.reload.evidence_subject).to include('Königreich')
    end

    # The RegRep document carries the subject in clear inside its own XML, so it
    # is of the same class as the column above and answers to the same key.
    it 'is unreadable in the RegRep document as well' do
      kept = create(:audit_event, :with_regrep_body)
      stored = described_class.connection.select_value(
        "SELECT regrep_body FROM audit_events WHERE id = #{kept.id}",
      )

      expect(stored).not_to include('QueryRequest')
      expect(kept.reload.regrep_body).to include('QueryRequest')
    end

    # What prefills the search from an event's page, taken from the subject and
    # not from the key, whose case `subject_key` has folded away.
    it 'hands back the criteria that find the same person' do
      expect(event.subject_criteria).to eq(family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01')
    end

    # The other form of the page, named by the criterion it submits: the
    # identifier alone, and never the triplet an organisation cannot fill.
    it 'hands back the identifier that finds the same organisation' do
      organisation = create(:audit_event, :about_an_organisation)

      expect(organisation.subject_criteria).to eq(legal_person_identifier: 'FR/DE/A2635542Y')
    end

    it 'hands back nothing for a subject no key was composed of' do
      incomplete = create(:audit_event, :about_an_incomplete_person)

      expect(incomplete.subject_criteria).to eq({})
    end

    # Deterministic, and only on this column: it is what article 17 is for —
    # answering which of a person's data travelled — and what chantier 5 will
    # compare a response against.
    it 'can still be looked up by subject' do
      expect(described_class.where(evidence_subject_key: 'königreich|ada|1990-01-01')).to contain_exactly(event)
    end

    # The event's page walks `admin.journal.attributes` and marks with a padlock
    # whatever it had to decrypt. A column encrypted but absent from that tree is
    # shown nowhere, so the padlock announcing it would never appear either.
    it 'gives every encrypted column a row on the page that marks it' do
      expect(described_class.encrypted_attributes).to all(be_in(I18n.t('admin.journal.attributes').keys))
    end
  end

  # It lives on the model because three callers share it: the writing, the
  # search, and the comparison chantier 5 will make against a response.
  describe '.subject_key' do
    it 'folds the case, so one person yields one key' do
      expect(described_class.subject_key(family_name: 'DUPONT', given_name: 'Sophie', date_of_birth: '1965-11-25'))
        .to eq('dupont|sophie|1965-11-25')
    end

    # A bare separator is a join and nothing else, which is what makes the two
    # forms tell apart by their count of components.
    it 'escapes a separator a component was carrying' do
      expect(described_class.subject_key(family_name: 'Legal|Sophie', given_name: 'Ada', date_of_birth: '1990-01-01'))
        .to eq('legal\\|sophie|ada|1990-01-01')
    end

    # Doubled, or a name ending in one would escape the separator that follows
    # it and swallow the join.
    it 'doubles a backslash a component was carrying' do
      expect(described_class.subject_key(family_name: 'Legal\\', given_name: 'Ada', date_of_birth: '1990-01-01'))
        .to eq('legal\\\\|ada|1990-01-01')
    end

    # The escape applies to every component and not to the first alone, which is
    # what keeps two people apart when they differ only by where the separator
    # falls. Unescaped, both composed `dupont|marie|claude|1990-01-01`.
    it 'tells apart two people differing only by which field carries the separator' do
      straddling = { family_name: 'Dupont|Marie', given_name: 'Claude', date_of_birth: '1990-01-01' }
      split_later = { family_name: 'Dupont', given_name: 'Marie|Claude', date_of_birth: '1990-01-01' }

      expect(described_class.subject_key(**straddling)).not_to eq(described_class.subject_key(**split_later))
    end
  end

  describe '.legal_subject_key' do
    it 'folds the case, so one organisation yields one key' do
      expect(described_class.legal_subject_key(eidas_identifier: 'FR/DE/A2635542Y'))
        .to eq('legal|fr/de/a2635542y')
    end

    # The collision the mark alone did not close, on an identifier R-EDM-REQ-C051
    # admits: the rule shapes it `XX/YY/Z…Z` and asks of the last segment only
    # that it be non-blank, so `FR/FR/AB|123456` conforms and carries a bare
    # separator. « Legal » being an ordinary French family name, the two
    # composed one and the same key, and one search answered about a person and
    # about an organisation at once.
    it 'keeps an identifier spelt like a triplet out of that person\'s key' do
      namesake = { family_name: 'Legal', given_name: 'FR/FR/AB', date_of_birth: '123456' }

      expect(described_class.legal_subject_key(eidas_identifier: 'FR/FR/AB|123456'))
        .not_to eq(described_class.subject_key(**namesake))
    end
  end

  describe '.subject' do
    it 'writes a natural person under the key an auditor searches by' do
      expect(described_class.subject(build(:natural_person))).to eq(
        evidence_subject: '{"family_name":"Dupont","given_name":"Sophie","date_of_birth":"1965-11-25"}',
        evidence_subject_key: 'dupont|sophie|1965-11-25',
      )
    end

    # Chapter 4.5.1 lets the evidence subject be an organisation, which has
    # neither a given name nor a date of birth: it is keyed on the identifier
    # eIDAS makes unique, under the mark that tells the two forms apart.
    it 'writes an organisation under the key of its eIDAS identifier' do
      expect(described_class.subject(build(:legal_person)))
        .to include(evidence_subject_key: 'legal|fr/de/a2635542y')
    end

    # The name is what a correspondent rewrites on the way back, so keying on it
    # would give one organisation two keys and scatter the lines the key exists
    # to gather.
    it 'gives one organisation one key, whatever name the correspondent wrote' do
      keys = ['Établissements Dupont & Fils', 'ETS DUPONT ET FILS'].map do |legal_name|
        described_class.subject(build(:legal_person, legal_name:))[:evidence_subject_key]
      end

      expect(keys.uniq.size).to eq(1)
    end

    # A subject read off a response carries an eIDAS identifier too, and it is
    # `legal_name` — which no natural person has — that keeps her from being
    # filed as an organisation on the strength of that identifier.
    it 'keys a person by the triplet even though a response gave it an identifier' do
      person = build(:natural_person, eidas_identifier: 'FR/FI/123123123')

      expect(described_class.subject(person)).to include(evidence_subject_key: 'dupont|sophie|1965-11-25')
    end

    # The order the two forms are tried in, which only ever settles a hash
    # carrying both whole — one no parser can build, `sdg:IsAbout` being an
    # `xs:choice`. Pinned on a hand-built hash so that reversing the two returns
    # says so somewhere.
    it 'keys a subject carrying both forms whole by the person' do
      both = { family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25',
               eidas_identifier: 'FR/DE/A2635542Y', legal_name: 'Établissements Dupont & Fils' }

      expect(described_class.canonical_key(both)).to eq('dupont|sophie|1965-11-25')
    end

    # `EvidenceResponseParser#evidence_subject` records without validating, so a
    # correspondent answering short of a field writes a line that neither form
    # of key can compose. It keeps its trace and loses its search.
    it 'writes no key at all for a subject that is neither whole' do
      truncated = { eidas_identifier: 'FR/DE/123123123', family_name: 'Königreich', given_name: 'Ada' }

      expect(described_class.canonical_key(truncated)).to be_nil
    end

    # `LEGAL_SUBJECT_FIELDS` wants the pair, and this is the case that says so
    # on its own: an identifier without a name is what tells an organisation
    # from a natural person carrying one too.
    it 'writes no key for an organisation whose name never came' do
      expect(described_class.canonical_key(eidas_identifier: 'FR/DE/A2635542Y')).to be_nil
    end

    # `text_at` reads `<sdg:LegalPersonIdentifier/>` as `""`, and
    # `attributes.compact` keeps it: counted as carried, it composed `legal|`
    # for every organisation answered that way, which is one key for subjects
    # that have nothing to do with each other.
    it 'writes no key for an identifier that came back empty' do
      answered_empty = described_class.subject(build(:legal_person, eidas_identifier: ''))

      expect(answered_empty[:evidence_subject_key]).to be_nil
    end

    it 'writes no key for a natural person whose three fields came back empty' do
      answered_empty = described_class.subject(
        build(:natural_person, family_name: '', given_name: '', date_of_birth: ''),
      )

      expect(answered_empty[:evidence_subject_key]).to be_nil
    end

    # The identifiers live outside the attribute API for want of a `Hash` type.
    # Dropped here, the journal would say an organisation carried no VAT number
    # where the request carried one. Asserted whole, so that a field falling out
    # of `attributes` shows up as well as one staying in.
    it 'keeps the optional identifiers of an organisation' do
      subject = described_class.subject(build(:legal_person, identifiers: { 'VAT' => 'FR12345678901' }))

      expect(JSON.parse(subject[:evidence_subject])).to eq(
        'eidas_identifier' => 'FR/DE/A2635542Y',
        'legal_name' => 'Établissements Dupont & Fils',
        'identifiers' => { 'VAT' => 'FR12345678901' },
      )
    end

    # Absent and not `{}`: an empty table and no table are the same silence, and
    # the console would otherwise show an empty row for identifiers nobody sent.
    it 'names no identifiers at all for an organisation that declared none' do
      subject = described_class.subject(build(:legal_person))

      expect(JSON.parse(subject[:evidence_subject]).keys).to contain_exactly('eidas_identifier', 'legal_name')
    end

    it 'says nothing at all of a message that named no subject' do
      expect(described_class.subject(nil)).to eq({})
    end
  end

  # The counterpart of `.subject`, on the model that owns the column: what a
  # `to_json` wrote, a `JSON.parse` reads back — and no page has to parse it a
  # second time on its own.
  describe '#described_subject' do
    it 'hands back the fields as the subject carried them' do
      event = create(:audit_event, :about_an_organisation)

      expect(event.described_subject).to eq(
        'eidas_identifier' => 'FR/DE/A2635542Y',
        'legal_name' => 'Établissements Dupont & Fils',
        'identifiers' => { 'VAT' => 'FR12345678901' },
      )
    end

    # The encoder writes `&`, `<` and `>` as JSON escapes and leaves the non-ASCII
    # alone, which is why the column holds `\u0026` for an ampersand and
    # `Établissements` whole.
    # Asserted on the stored string, so that what the reading undoes is named.
    it 'undoes the entities the encoder escaped, the accents never having been' do
      event = create(:audit_event, :about_an_organisation)

      expect(event.evidence_subject).to include('\u0026', 'Établissements')
      expect(event.described_subject['legal_name']).to eq('Établissements Dupont & Fils')
    end

    it 'is empty for an event that named no subject' do
      expect(create(:audit_event).described_subject).to eq({})
    end

    # The reading carries no `rescue` on purpose, the column having a single
    # writer: a value it could not parse is a defect, and a cell left blank
    # would bury it on the one page an operator comes to read.
    it 'fails rather than blank a subject it cannot parse' do
      event = create(:audit_event, evidence_subject: 'ce que personne n\'écrit')

      expect { event.described_subject }.to raise_error(JSON::ParserError)
    end
  end

  it 'upcases the country whoever wrote it' do
    expect(create(:audit_event, country_code: 'be').country_code).to eq('BE')
  end

  # Chapter 4.4: « A Data Service MUST reject requests that use identifiers that
  # were used in previously processed requests. » The journal is the only memory
  # of it — no `Exchange` on the provider side carries a request identifier.
  describe '.request_already_received?' do
    let(:identifier) { 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700' }

    it 'is false when no request has carried the identifier' do
      expect(described_class.request_already_received?(identifier)).to be(false)
    end

    it 'is true once a request has arrived under it' do
      create(:audit_event, event_type: 'request_received', request_id: identifier, message_id: 'message-1')

      expect(described_class.request_already_received?(identifier)).to be(true)
    end

    # `IncomingMessage::Process` journals an arrival before it dispatches, so
    # the request being answered already has a line here. Without excluding it,
    # every request would look like its own replay.
    it 'ignores the arrival of the message being handled' do
      create(:audit_event, event_type: 'request_received', request_id: identifier, message_id: 'message-1')

      expect(described_class.request_already_received?(identifier, except: 'message-1')).to be(false)
    end

    it 'still sees an earlier arrival under another gateway message' do
      create(:audit_event, event_type: 'request_received', request_id: identifier, message_id: 'message-1')
      create(:audit_event, event_type: 'request_received', request_id: identifier, message_id: 'message-2')

      expect(described_class.request_already_received?(identifier, except: 'message-2')).to be(true)
    end

    # What France sent out under an identifier of its own is not a request
    # anybody addressed to it.
    it 'looks at arrivals alone, and not at what France sent' do
      create(:audit_event, event_type: 'request_sent', request_id: identifier, message_id: 'message-1')

      expect(described_class.request_already_received?(identifier)).to be(false)
    end

    # `where(request_id: nil)` would match every line that never carried one,
    # and turn a request whose identifier could not be read into a replay.
    it 'is false for a request whose identifier could not be read' do
      create(:audit_event, event_type: 'request_received', request_id: nil, message_id: 'message-1')

      expect(described_class.request_already_received?(nil)).to be(false)
    end
  end
end
