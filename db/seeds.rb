# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# The account a developer opens the administration space with. Not created in
# production: this password is in the repository, so seeding it there would open
# the space to whoever has read the file. A real deployment makes its own
# account in `rails console` — docs/espace_administration.md says how.
#
# Assigned rather than only created, so that replaying the seed restores the
# advertised password on an account whose own was changed.
if Rails.env.production?
  # Said rather than passed over in silence: without it, nothing distinguishes
  # a seed that deliberately skipped from one that died before reaching here.
  puts "Aucun compte d'administration n'est créé en production : voir docs/espace_administration.md"
else
  administrator = Administrator.find_or_initialize_by(email: 'admin@example.com')
  administrator.password = 'Administration-2026'
  administrator.save!

  puts "Compte d'administration : #{administrator.email} / Administration-2026"
end

# One exchange per state of `Exchange::STATUSES`, so that the administration
# space has its badges, its filters and its detail page to show. Nothing here
# ever happened: no message was built, no gateway was called, and their
# identifiers say so — a real one is a UUID that `UuidGenerator` drew, never a
# run of zeroes. An operator who meets one of these while looking into an
# incident must be able to see at a glance that there is nothing to look into.
#
# `development?` and not merely "outside production", unlike the account above:
# a test database is never looked at, and rows in it that no example asked for
# make the suite red on a developer's machine while the CI, whose database is
# never seeded, stays green. Five examples fail that way — the filter's paging
# and its no-criterion case, and the uniqueness matcher on `Exchange`.
#
# Keyed on their identifier rather than created outright, so replaying the seed
# does not pile up a second set.
if Rails.env.development?
  person = NaturalPerson.new(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')

  # One outgoing exchange per state France can reach, two received ones, and
  # between them every one of the eight event types — so that no page of the
  # console stands empty and none shows only its easy case.
  #
  # The codes are ones the directories actually publish: `00` is the OOTS system
  # check, the rest are procedures of the TDD. A demonstration wearing a code
  # nobody declares would link to a page with nothing on it.
  #
  # `country_code` is the correspondent's either way: the country France asks,
  # and the country asking France. Appended to, never inserted into: the rank of
  # an entry is its identifier, so a new one slipped in the middle renames every
  # one after it and a replay collides with the rows it wrote last time.
  #
  # `conversation` gathers several exchanges under one user's session, as
  # chapter 4.4 allows: the first two are Sophie Dupont asking for two
  # different pieces of evidence in a row, so the console has a conversation
  # worth following from one exchange to the other.
  scenarios = [
    { status: 'delivered', country_code: 'FI', procedure_code: ProcedureCode::SYSTEM_CHECK,
      conversation: 1, events: %w[request_sent response_received evidence_delivered] },
    { status: 'failed', country_code: 'DE', procedure_code: ProcedureCode::DIPLOMA_RECOGNITION,
      edm_error_code: 'EDM:ERR:0004',
      error_description: "Le fournisseur n'a pas trouvé de justificatif correspondant.",
      conversation: 1, events: %w[request_sent error_received] },
    { status: 'preview_required', country_code: 'SI', procedure_code: 'S1',
      preview_location: 'https://previsualisation.example.si/consentement',
      events: %w[request_sent error_received] },
    { status: 'sent', country_code: 'NL', procedure_code: 'S1', events: %w[request_sent] },
    { status: 'pending', country_code: 'PT', procedure_code: 'U2', events: [] },
    { incoming: true, status: 'delivered', country_code: 'BE',
      procedure_code: ProcedureCode::SYSTEM_CHECK,
      events: %w[request_received response_sent] },
    { incoming: true, status: 'failed', country_code: 'IT',
      procedure_code: ProcedureCode::DIPLOMA_RECOGNITION,
      edm_error_code: 'EDM:ERR:0004',
      error_description: 'La France ne détient pas ce justificatif.',
      events: %w[request_received error_sent] },
    { status: 'deferred', country_code: 'ES', procedure_code: ProcedureCode::BIRTH_REGISTRATION,
      response_available_at: 8.days.from_now,
      events: %w[request_sent response_received] },
  ]

  # What each type of event actually carries, as `AuditTrail` writes it: every
  # one names a country — the exchange gives it where France asks, the agent's
  # address where a message arrives. The other three are narrower, and a
  # demonstration that filled them all would teach the console to lie: a
  # received request names its procedure but not the requester, whom
  # `AuditTrail` records as a requesting authority instead; and only what
  # travelled through the gateway names a message.
  carries_procedure = %w[request_sent request_refused evidence_delivered request_received].freeze
  carries_requester = %w[request_sent request_refused evidence_delivered].freeze
  carries_message = (AuditEvent::SENT_BY_FRANCE + AuditEvent::RECEIVED_BY_FRANCE).freeze

  # One shape per message the TDD define: a request, an answer, and an answer
  # that refuses — the last being a `QueryResponse` carrying an `rs:Exception`,
  # and not a document of its own.
  demonstration_body = lambda do |event_type|
    id = SecureRandom.uuid

    case event_type
    when 'request_sent', 'request_received'
      format(<<~XML, id:)
        <?xml version="1.0" encoding="UTF-8"?>
        <query:QueryRequest xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                            id="urn:uuid:%<id>s">
          <!-- Corps de démonstration : voir docs/journal_des_echanges.md -->
        </query:QueryRequest>
      XML
    when 'error_sent', 'error_received'
      format(<<~XML, id:)
        <?xml version="1.0" encoding="UTF-8"?>
        <query:QueryResponse xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                             xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
                             requestId="urn:uuid:%<id>s"
                             status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure">
          <rs:Exception code="EDM:ERR:0004"/>
          <!-- Corps de démonstration : voir docs/journal_des_echanges.md -->
        </query:QueryResponse>
      XML
    else
      format(<<~XML, id:)
        <?xml version="1.0" encoding="UTF-8"?>
        <query:QueryResponse xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                             requestId="urn:uuid:%<id>s"
                             status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success">
          <!-- Corps de démonstration : voir docs/journal_des_echanges.md -->
        </query:QueryResponse>
      XML
    end
  end

  # What the evidence leaves in the journal, where `AuditTrail#evidence_fingerprint`
  # writes it: the two answers that carry a document, and the handover to the
  # French requester. A deferred answer announces a date and carries nothing, so
  # it gets neither column — as the code leaves both empty there.
  #
  # The digest is the real one of the document France serves, so that the
  # procedure `journal_des_echanges.md` describes for settling a dispute can be
  # walked on demonstration data rather than only read.
  carries_evidence = %w[response_sent response_received evidence_delivered].freeze
  served_evidence = Rails.root.join(EvidenceProvision::AnswerRequest::EVIDENCE_PATH).binread

  evidence_fingerprint = lambda do |event_type, exchange|
    return {} unless event_type.in?(carries_evidence) && exchange.status != 'deferred'

    { evidence_digest: Digest::SHA256.hexdigest(served_evidence),
      evidence_mime_type: RetrievedMessageParser::PDF }
  end

  # The first MIME part travels with the message, so the events that carry one
  # carry it — and each carries the shape its own message would have. A stand-in
  # and not a real message: the console page has to be readable by hand, and
  # nothing here is evidence of anything.
  #
  # The shape matters all the same. A demonstration answering a request with the
  # body of a request would teach the console, and whoever reads it, that the two
  # look alike — where the whole point of keeping the body is to show what each
  # message actually said.
  regrep_body = lambda do |event_type|
    return {} unless event_type.in?(carries_message)

    { regrep_mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE,
      regrep_body: demonstration_body.call(event_type) }
  end

  demonstrations = scenarios.each_with_index.map do |scenario, rank|
    events = scenario[:events]
    incoming = scenario.fetch(:incoming, false)
    opened = rank.days.ago

    # One conversation of its own unless the scenario joins another: the two
    # identifiers are distinct, and the demonstration would teach otherwise if
    # they were derived from one another.
    conversation_id = format('00000000-0000-0000-0001-%012d', scenario.fetch(:conversation, rank + 1))

    # The direction is in the lookup and not in the update: `incoming` is
    # read-only once the row is written, and a demonstration replayed finds its
    # own row rather than turning it round.
    exchange = Exchange.find_or_initialize_by(
      exchange_id: format('00000000-0000-0000-0000-%012d', rank + 1),
      incoming:,
    )

    exchange.update!(
      scenario.except(:events, :incoming, :conversation).merge(
        conversation_id:,
        evidence_requester_id: incoming ? '00000000000009' : '00000000000002',
        created_at: opened,
        settled_at: (opened unless scenario[:status].in?(Exchange::IN_PROGRESS)),
      ),
    )

    events.each_with_index do |event_type, step|
      next if AuditEvent.exists?(exchange_id: exchange.exchange_id, event_type:)

      AuditEvent.create!(
        event_type:,
        occurred_at: opened + (step * 7).minutes,
        exchange_id: exchange.exchange_id,
        conversation_id: exchange.conversation_id,
        procedure_code: (exchange.procedure_code if event_type.in?(carries_procedure)),
        country_code: exchange.country_code,
        evidence_requester_id: (exchange.evidence_requester_id if event_type.in?(carries_requester)),
        message_id: (format('%s@domibus.eu', SecureRandom.uuid) if event_type.in?(carries_message)),
        edm_error_code: (exchange.edm_error_code if event_type.start_with?('error')),
        detail: (exchange.error_description if event_type.start_with?('error')),
        **(event_type.start_with?('request') ? AuditEvent.subject(person) : {}),
        **regrep_body.call(event_type),
        **evidence_fingerprint.call(event_type, exchange),
      )
    end

    exchange
  end

  # The eighth type, and the only event no exchange carries: a caller turned away
  # before anything was opened. It is what the journal holds and the exchange
  # list, by construction, cannot.
  unless AuditEvent.exists?(event_type: 'request_refused')
    AuditEvent.create!(
      event_type: 'request_refused', occurred_at: 1.hour.ago,
      procedure_code: 'U4', country_code: 'ES', evidence_requester_id: '00000000000002',
      detail: 'Le bénéficiaire doit être renseigné',
    )
  end

  puts "#{demonstrations.count { |one| !one.incoming? }} échanges émis, un par état, " \
       "#{demonstrations.count(&:incoming?)} reçus, " \
       "sur #{demonstrations.map(&:conversation_id).uniq.count} conversations."
  puts "#{AuditEvent.count} événements de journal, dont un refus sans échange."
end
