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

# One exchange per state of `Conversation::STATUSES`, so that the administration
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
# and its no-criterion case, and the uniqueness matcher on `Conversation`.
#
# Keyed on their identifier rather than created outright, so replaying the seed
# does not pile up a second set.
if Rails.env.development?
  person = NaturalPerson.new(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')

  # One exchange per state France can reach, both directions, and between them
  # every one of the eight event types — so that no page of the console stands
  # empty and none shows only its easy case.
  #
  # The codes are ones the directories actually publish: `00` is the OOTS system
  # check, the rest are procedures of the TDD. A demonstration wearing a code
  # nobody declares would link to a page with nothing on it.
  #
  # `country_code` is the correspondent's either way: the country France asks,
  # and the country asking France.
  exchanges = [
    { status: 'delivered', country_code: 'FI', procedure_code: ProcedureCode::SYSTEM_CHECK,
      events: %w[request_sent response_received evidence_delivered] },
    { status: 'failed', country_code: 'DE', procedure_code: ProcedureCode::STUDENT_GRANT,
      edm_error_code: 'EDM:ERR:0004',
      error_description: "Le fournisseur n'a pas trouvé de justificatif correspondant.",
      events: %w[request_sent error_received] },
    { status: 'preview_required', country_code: 'SI', procedure_code: 'S1',
      preview_location: 'https://previsualisation.example.si/consentement',
      events: %w[request_sent error_received] },
    { status: 'sent', country_code: 'NL', procedure_code: 'S1', events: %w[request_sent] },
    { status: 'pending', country_code: 'PT', procedure_code: 'U2', events: [] },
    { incoming: true, status: 'delivered', country_code: 'BE',
      procedure_code: ProcedureCode::SYSTEM_CHECK,
      events: %w[request_received response_sent] },
    { incoming: true, status: 'failed', country_code: 'IT',
      procedure_code: ProcedureCode::STUDENT_GRANT,
      edm_error_code: 'EDM:ERR:0004',
      error_description: 'La France ne détient pas ce justificatif.',
      events: %w[request_received error_sent] },
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

  demonstrations = exchanges.each_with_index.map do |exchange, rank|
    events = exchange[:events]
    incoming = exchange.fetch(:incoming, false)
    opened = rank.days.ago

    # Le sens est dans la recherche et non dans la reprise : `incoming` est en
    # lecture seule une fois la ligne écrite, et une démonstration rejouée
    # retrouve la sienne plutôt que de la retourner.
    conversation = Conversation.find_or_initialize_by(
      conversation_id: format('00000000-0000-0000-0000-%012d', rank + 1),
      incoming:,
    )

    conversation.update!(
      exchange.except(:events, :incoming).merge(
        evidence_requester_id: incoming ? '00000000000009' : '00000000000002',
        created_at: opened,
        settled_at: (opened unless exchange[:status].in?(Conversation::IN_PROGRESS)),
      ),
    )

    events.each_with_index do |event_type, step|
      next if AuditEvent.exists?(conversation_id: conversation.conversation_id, event_type:)

      AuditEvent.create!(
        event_type:,
        occurred_at: opened + (step * 7).minutes,
        conversation_id: conversation.conversation_id,
        procedure_code: (conversation.procedure_code if event_type.in?(carries_procedure)),
        country_code: conversation.country_code,
        evidence_requester_id: (conversation.evidence_requester_id if event_type.in?(carries_requester)),
        message_id: (format('%s@domibus.eu', SecureRandom.uuid) if event_type.in?(carries_message)),
        edm_error_code: (conversation.edm_error_code if event_type.start_with?('error')),
        detail: (conversation.error_description if event_type.start_with?('error')),
        **(event_type.start_with?('request') ? AuditEvent.subject(person) : {}),
      )
    end

    conversation
  end

  # The eighth type, and the only event no exchange carries: a caller turned away
  # before anything was opened. It is what the journal holds and the conversation
  # list, by construction, cannot.
  unless AuditEvent.exists?(event_type: 'request_refused')
    AuditEvent.create!(
      event_type: 'request_refused', occurred_at: 1.hour.ago,
      procedure_code: 'U4', country_code: 'ES', evidence_requester_id: '00000000000002',
      detail: 'Le bénéficiaire doit être renseigné',
    )
  end

  puts "#{demonstrations.count { |one| !one.incoming? }} conversations émises, " \
       "#{demonstrations.count(&:incoming?)} reçues, une par état."
  puts "#{AuditEvent.count} événements de journal, dont un refus sans échange."
end
