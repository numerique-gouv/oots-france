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

  # Le second sujet que le chapitre 4.5.1 autorise. Il donne à la console sa
  # ligne dont la clé canonique est de la forme morale — `legal|` suivi de
  # l'identifiant eIDAS —, donc la seule que le second formulaire de la
  # recherche par sujet retrouve, et qu'une démonstration n'affichant que des
  # personnes physiques laisserait croire introuvable.
  organisation = LegalPerson.new(
    eidas_identifier: 'FR/DE/A2635542Y',
    legal_name: 'Établissements Dupont & Fils',
    identifiers: { 'VAT' => 'FR12345678901' },
  )

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
    # `preview_required!` ne pose pas de code sur l'échange — il n'y en a pas à
    # poser, la prévisualisation n'étant pas un échec —, mais l'erreur reçue en
    # portait un, et `AuditTrail#received_error` l'inscrit sur l'événement.
    { status: 'preview_required', country_code: 'SI', procedure_code: 'S1',
      preview_location: 'https://previsualisation.example.si/consentement',
      message_error_code: EdmException::AUTHORIZATION.code,
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
    # France answered and the gateway did not take the answer: the exchange
    # fails with no EDM code, as `IncomingMessage::Process` leaves it, and the
    # answer that never went out gets its line just below.
    { incoming: true, status: 'failed', country_code: 'PL',
      procedure_code: ProcedureCode::SYSTEM_CHECK,
      error_description: "L'échange a échoué : 503 Service Unavailable",
      events: %w[request_received] },
    # Une requête dont l'identifiant même enfreint `R-EDM-REQ-S004`. La France
    # refuse en `EDM:ERR:0003` et sa réponse ne porte aucun `requestId` — la
    # seule omission que `R-EDM-ERR-C025` autorise. Le journal n'en garde donc
    # pas d'identifiant de requête, ni sur l'arrivée ni sur le refus : ce que
    # `AuditTrail` n'a pas su lire, il laisse vide. Le corps conservé, lui,
    # porte l'identifiant tel qu'il a circulé, faute de quoi la fiche ne dirait
    # pas ce qui a été refusé.
    { incoming: true, status: 'failed', country_code: 'HU',
      procedure_code: ProcedureCode::SYSTEM_CHECK,
      edm_error_code: EdmException::INVALID_REQUEST.code,
      error_description: EdmException::INVALID_REQUEST.message,
      error_detail: 'R-EDM-REQ-S004',
      request_id: nil, request_id_as_sent: 'pas-un-uuid',
      events: %w[request_received error_sent] },
    # Le sujet du justificatif est une personne morale, ce que
    # `R-EDM-REQ-S016` autorise autant qu'une personne physique.
    { incoming: true, status: 'delivered', country_code: 'AT',
      procedure_code: ProcedureCode::SYSTEM_CHECK, subject: organisation,
      events: %w[request_received response_sent] },
    # Une réponse qu'un correspondant a émise en annonçant `oots-edm:v1.0` :
    # `R-EDM-RESP-C002` est enfreinte, et `EvidenceResponseParser#violations` la
    # relève. Rien n'est refusé pour autant — le chapitre 4.6 n'attribue le
    # devoir de valider à personne et aucun chemin d'erreur ne remonte vers un
    # fournisseur —, donc l'échange se règle et le justificatif est remis. Le
    # `detail` de `response_received` est la seule trace que l'écart a été vu.
    #
    # La phrase est composée par le chemin qui l'écrit en production, et non
    # recopiée : reformuler la clé i18n laisserait sinon la démonstration
    # mentir sur ce que le code produit, et une console qui ment se lit comme
    # une documentation.
    { status: 'delivered', country_code: 'CZ', procedure_code: ProcedureCode::BIRTH_REGISTRATION,
      confirmed_without: %w[date_of_birth],
      response_detail: BusinessRuleViolation.new(
        rule: 'R-EDM-RESP-C002',
        description: I18n.t('parsers.evidence_response.unexpected_specification',
          announced: 'oots-edm:v1.0', expected: EdmSpecification::IDENTIFIER),
      ).sentence,
      events: %w[request_sent response_received evidence_delivered] },
  ]

  # Le sujet tel qu'une réponse le confirme. Le chapitre 4.5.2 fait porter à
  # `sdg:IsAbout` le *Minimum Data Set* du sujet demandé « to confirm identity
  # matching » : le fournisseur confirme, et peut compléter. L'écart démontré
  # est donc un identifiant eIDAS que la requête ne portait pas, et non un nom
  # divergent — le triplet ne bouge pas, donc la clé canonique non plus, et les
  # deux lignes se retrouvent ensemble à la recherche par sujet, là où un nom
  # différent aurait fait croire la recherche cassée.
  #
  # `R-EDM-REQ-C040` donne à l'identifiant d'une personne physique la forme
  # `XX/YY/Z…Z` : le pays qui affirme l'identité, puis celui à qui elle est
  # affirmée. Le second est donc celui du correspondant, et non une constante.
  # C'est bien la règle de la requête — la réponse ne fait qu'en renvoyer le
  # *Minimum Data Set* —, et celle de la personne physique : `R-EDM-REQ-C051`,
  # que cite `LegalPerson`, porte le même format pour la personne morale.
  #
  # `confirmed_without` retire un champ à ce que la réponse confirme : le
  # chapitre 4.6 n'attribue à personne le devoir de valider un sujet reçu, et
  # `EvidenceResponseParser#evidence_subject` consigne sans valider, si bien
  # qu'un correspondant qui répond court d'un champ écrit une ligne **sans clé
  # canonique**. C'est le seul cas qui en reste, et donc la seule fiche où le
  # bouton listant les autres événements du même sujet est absent — ce que
  # docs/journal_des_echanges.md décrit et qu'aucune autre ligne ne montrerait.
  matched_person = lambda do |exchange, scenario|
    NaturalPerson.new(
      person.attributes
        .merge('eidas_identifier' => format('FR/%s/123123123', exchange.country_code))
        .except(*scenario.fetch(:confirmed_without, [])),
    )
  end

  # Les deux sujets que le journal garde d'un même échange : celui que la
  # requête demande, et celui que la réponse confirme. Une réponse différée
  # n'annonce aucune métadonnée, donc aucun sujet — comme le code, qui n'en lit
  # pas. Et la réponse française n'en porte pas non plus : `AuditTrail#response_sent`
  # n'en écrit aucun, le sujet lu de la requête reçue ayant déjà sa ligne.
  demonstration_subject = lambda do |event_type, scenario, exchange|
    return AuditEvent.subject(scenario.fetch(:subject, person)) if event_type.start_with?('request')
    return {} unless event_type == 'response_received' && exchange.status != 'deferred'

    AuditEvent.subject(matched_person.call(exchange, scenario))
  end

  # What `detail` holds, type by type, as `AuditTrail` writes it: the rule the
  # refused request broke where France turns one away, the wording the code list
  # fixes where the exchange keeps it, and the rules of chapter 4.6 an arriving
  # response breaks — those refuse nothing, and the answer is handled all the
  # same.
  demonstration_detail = lambda do |event_type, scenario, exchange|
    return scenario[:error_detail] || exchange.error_description if event_type.start_with?('error')

    scenario[:response_detail] if event_type == 'response_received'
  end

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

  # The ebMS action, which every message names and nothing else does: what
  # circulated is one of the three the TDD define, and `AuditTrail` writes it
  # from the constant where France speaks and from the header where it listens.
  ebms_actions = {
    'request_sent' => EbmsAction::EXECUTE_QUERY_REQUEST,
    'request_received' => EbmsAction::EXECUTE_QUERY_REQUEST,
    'response_sent' => EbmsAction::EXECUTE_QUERY_RESPONSE,
    'response_received' => EbmsAction::EXECUTE_QUERY_RESPONSE,
    'error_sent' => EbmsAction::EXCEPTION_RESPONSE,
    'error_received' => EbmsAction::EXCEPTION_RESPONSE,
  }.freeze

  # The response identifier, which a shorter list carries than the request one:
  # every message of an exchange names the request it belongs to — that shared
  # value is the whole of what correlating means — where a request names no
  # answer, and a received error carries no response identifier of its own, its
  # reader taking the code and the request it answers and no identifier beyond.
  carries_response_id = %w[response_sent response_received error_sent].freeze

  # One shape per message the TDD define: a request, an answer, and an answer
  # that refuses — the last being a `QueryResponse` carrying an `rs:Exception`,
  # and not a document of its own.
  #
  # L'identifiant est celui de l'échange démontré, et non un tiré au sort : un
  # corps dont le `requestId` ne correspond à rien apprendrait à lire la fiche
  # sans la croire. Là où il manque, l'attribut est omis et non laissé vide —
  # `R-EDM-ERR-C025` n'autorise cette omission que sous
  # `rs:InvalidRequestExceptionType`, et c'est la seule réponse qui en use.
  demonstration_body = lambda do |event_type, sent: nil, echoed: nil, code: nil, preview: nil|
    request_id_attribute = %( requestId="#{echoed}") if echoed.present?
    # Le slot que `R-EDM-ERR-C022` attache à la sévérité `PreviewRequired`, et
    # d'où `AuditTrail#received_error` tire sa colonne : le corps conservé doit
    # porter ce dont la colonne d'à côté prétend venir.
    # Décalé exprès : le résultat est interpolé à la colonne 2 du corps, donc
    # c'est ce décalage-là qui le fait sortir droit. Redresser la source ici
    # tordrait le XML que la fiche affiche.
    exception_element =
      if preview.present?
        format(<<~XML.chomp, code:, preview:)
          <rs:Exception code="%<code>s">
              <rim:Slot name="PreviewLocation">
                <rim:SlotValue><rim:Value>%<preview>s</rim:Value></rim:SlotValue>
              </rim:Slot>
            </rs:Exception>
        XML
      else
        format('<rs:Exception code="%<code>s"/>', code:)
      end

    case event_type
    when 'request_sent', 'request_received'
      format(<<~XML, id: sent)
        <?xml version="1.0" encoding="UTF-8"?>
        <query:QueryRequest xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                            id="%<id>s">
          <!-- Corps de démonstration : voir docs/journal_des_echanges.md -->
        </query:QueryRequest>
      XML
    when 'error_sent', 'error_received'
      format(<<~XML, request_id: request_id_attribute, exception: exception_element)
        <?xml version="1.0" encoding="UTF-8"?>
        <query:QueryResponse xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
                             xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
                             xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"%<request_id>s
                             status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure">
          %<exception>s
          <!-- Corps de démonstration : voir docs/journal_des_echanges.md -->
        </query:QueryResponse>
      XML
    else
      format(<<~XML, request_id: request_id_attribute)
        <?xml version="1.0" encoding="UTF-8"?>
        <query:QueryResponse xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"%<request_id>s
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

  # The `cid:` of the part that carried the document, which chapter 4.8 has the
  # response flow log beside its type: it is what ties the attachment to the
  # `rim:RepositoryItemRef` naming it. Minted where the answer was — France's own
  # suffix where France answered, the correspondent's where it received.
  evidence_content_id = lambda do |exchange|
    # `AnswerRequest#attachment_for` mints the French one under this suffix; a
    # correspondent's is its own, so a demonstration wearing ours both ways would
    # teach the console that France attached what it received.
    suffix = exchange.incoming? ? 'pdf.oots.fr' : "pdf.oots.#{exchange.country_code.downcase}"

    format('cid:%s@%s', SecureRandom.uuid, suffix)
  end

  evidence_fingerprint = lambda do |event_type, exchange, content_id|
    return {} unless event_type.in?(carries_evidence) && exchange.status != 'deferred'

    { evidence_digest: Digest::SHA256.hexdigest(served_evidence),
      evidence_mime_type: RetrievedMessageParser::PDF,
      evidence_content_id: content_id }
  end

  # The identifier the provider gave the document, which chapter 4.8 has both
  # ends of a response log. A shorter list than the fingerprint's: the handover
  # to the French requester leaves no line naming it, `AuditTrail` recording
  # there only what the exchange and the document itself say.
  names_evidence = %w[response_sent response_received].freeze

  evidence_identifier = lambda do |event_type, exchange|
    return {} unless event_type.in?(names_evidence) && exchange.status != 'deferred'

    { evidence_identifier: SecureRandom.uuid }
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
  regrep_body = lambda do |event_type, sent:, echoed:, code:, preview:|
    return {} unless event_type.in?(carries_message)

    { regrep_mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE,
      regrep_body: demonstration_body.call(event_type, sent:, echoed:, code:, preview:) }
  end

  demonstrations = scenarios.each_with_index.map do |scenario, rank|
    events = scenario[:events]
    incoming = scenario.fetch(:incoming, false)
    opened = rank.days.ago

    # One conversation of its own unless the scenario joins another: the two
    # identifiers are distinct, and the demonstration would teach otherwise if
    # they were derived from one another.
    conversation_id = format('00000000-0000-0000-0001-%012d', scenario.fetch(:conversation, rank + 1))

    # Drawn once per exchange, so that the events of one exchange name the same
    # request and the same answer — the correlation an auditor follows.
    #
    # Each in the form its own message carries, which are not the same:
    # `R-EDM-REQ-S004` prefixes a request identifier `urn:uuid:`, where the
    # `EvidenceResponseIdentifier` slot holds the bare UUID a builder drew.
    # Nul quand le correspondant en a envoyé un que rien ne pouvait lire ; le
    # corps, lui, garde ce qui a circulé, ce que la colonne ne peut pas faire.
    request_id = scenario.fetch(:request_id, format('urn:uuid:%s', SecureRandom.uuid))
    circulated_id = scenario.fetch(:request_id_as_sent, request_id)
    response_id = SecureRandom.uuid

    # Le code que le message d'erreur portait, que les deux écrivains
    # d'`AuditTrail` lisent du message et non de l'échange : le plus souvent le
    # même, sauf là où l'échange n'en garde aucun.
    message_error_code = scenario[:message_error_code] || scenario[:edm_error_code]

    # The direction is in the lookup and not in the update: `incoming` is
    # read-only once the row is written, and a demonstration replayed finds its
    # own row rather than turning it round.
    exchange = Exchange.find_or_initialize_by(
      exchange_id: format('00000000-0000-0000-0000-%012d', rank + 1),
      incoming:,
    )

    exchange.update!(
      scenario.except(:events, :incoming, :conversation, :error_detail, :response_detail,
        :request_id, :request_id_as_sent, :message_error_code, :subject,
        :confirmed_without).merge(
          conversation_id:,
          # `SendToGateway` l'écrit au moment de soumettre : un échange que rien
          # n'a encore quitté n'en porte pas, et rien n'en écrit côté
          # fournisseur, où l'identifiant ne vit que dans le journal.
          request_id: (request_id unless incoming || scenario[:status] == 'pending'),
          evidence_requester_id: incoming ? '00000000000009' : '00000000000002',
          created_at: opened,
          settled_at: (opened unless scenario[:status].in?(Exchange::IN_PROGRESS)),
        ),
    )

    # Drawn once per exchange, like the two identifiers above: the answer and the
    # handover name the same attachment, which is the correlation an auditor
    # follows from the body's `rim:RepositoryItemRef`.
    content_id = evidence_content_id.call(exchange)

    events.each_with_index do |event_type, step|
      next if AuditEvent.exists?(exchange_id: exchange.exchange_id, event_type:)

      # L'adresse que le correspondant a déclarée, et que `received_error` seul
      # inscrit : la France n'émet aucune prévisualisation, faute d'espace où
      # l'ouvrir. Le corps conservé porte le slot d'où elle vient, sans quoi la
      # fiche montrerait une colonne que le message d'à côté ne dit pas.
      declared_preview = (exchange.preview_location if event_type == 'error_received')

      AuditEvent.create!(
        event_type:,
        occurred_at: opened + (step * 7).minutes,
        exchange_id: exchange.exchange_id,
        conversation_id: exchange.conversation_id,
        procedure_code: (exchange.procedure_code if event_type.in?(carries_procedure)),
        country_code: exchange.country_code,
        evidence_requester_id: (exchange.evidence_requester_id if event_type.in?(carries_requester)),
        message_id: (format('%s@domibus.eu', SecureRandom.uuid) if event_type.in?(carries_message)),
        ebms_action: ebms_actions[event_type],
        request_id: (request_id if event_type.in?(carries_message)),
        response_id: (response_id if event_type.in?(carries_response_id)),
        edm_error_code: (message_error_code if event_type.start_with?('error')),
        detail: demonstration_detail.call(event_type, scenario, exchange),
        **demonstration_subject.call(event_type, scenario, exchange),
        preview_location: declared_preview,
        **regrep_body.call(event_type, sent: circulated_id, echoed: request_id,
          code: message_error_code, preview: declared_preview),
        **evidence_fingerprint.call(event_type, exchange, content_id),
        **evidence_identifier.call(event_type, exchange),
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

  # The three that say nothing else happened. Each carries exactly what its
  # writer in `AuditTrail` can fill, and a demonstration filling more would
  # teach the console to lie: an envelope the parser refused leaves only what
  # the gateway called it, since there is no header to read anything else from;
  # an action no handler claims leaves that action and the identifiers the
  # header did carry, but no country, which is only ever read from an agent's
  # address in the body.
  unless AuditEvent.exists?(event_type: 'message_unreadable')
    AuditEvent.create!(
      event_type: 'message_unreadable', occurred_at: 2.hours.ago,
      message_id: format('%s@domibus.eu', SecureRandom.uuid),
      detail: 'Enveloppe illisible',
    )
  end

  unless AuditEvent.exists?(event_type: 'message_unhandled')
    AuditEvent.create!(
      event_type: 'message_unhandled', occurred_at: 3.hours.ago,
      ebms_action: 'SomethingElse',
      conversation_id: '00000000-0000-0000-0001-000000000010',
      exchange_id: '00000000-0000-0000-0000-000000000010',
      message_id: format('%s@domibus.eu', SecureRandom.uuid),
      detail: I18n.t('lib.audit_trail.unhandled_action', action: 'SomethingElse'),
      # The body of a request, because that is what an unknown action arrives
      # carrying: `first_part` reads by position, so a correspondent who names
      # its action wrongly still hands over a well-formed RegRep document.
      # Leaving the pair empty would teach the console that this type never has
      # a body, where the code writes one whenever the part reads.
      regrep_mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE,
      regrep_body: demonstration_body.call('request_received',
        sent: format('urn:uuid:%s', SecureRandom.uuid)),
    )
  end

  # The answer France built for the exchange above, kept because nothing else
  # holds it: the gateway never took it, so there is no message identifier and
  # no evidence digest — that digest says whether a document is the one that
  # went through, and none did.
  # Désigné par son pays et non par sa place dans la liste : les scénarios
  # s'ajoutent en fin, et `last` suivrait le dernier venu.
  refused_by_gateway = demonstrations.find { |one| one.incoming? && one.country_code == 'PL' }

  unless AuditEvent.exists?(event_type: 'answer_not_sent')
    # The request identifier is read back from the arrival rather than drawn
    # again: this line answers that request, and an answer naming a request
    # nobody made would teach the console that the two never correlate. The
    # response identifier is its own — France minted one, and it never left.
    answered_request = AuditEvent.find_by(exchange_id: refused_by_gateway.exchange_id,
      event_type: 'request_received')

    AuditEvent.create!(
      event_type: 'answer_not_sent', occurred_at: refused_by_gateway.created_at + 7.minutes,
      ebms_action: EbmsAction::EXECUTE_QUERY_RESPONSE,
      conversation_id: refused_by_gateway.conversation_id,
      exchange_id: refused_by_gateway.exchange_id,
      country_code: refused_by_gateway.country_code,
      request_id: answered_request&.request_id,
      response_id: SecureRandom.uuid,
      detail: '503 Service Unavailable',
      regrep_mime_type: EbmsHeaderBuilder::REGREP_MIME_TYPE,
      regrep_body: demonstration_body.call('response_sent', echoed: answered_request&.request_id),
    )
  end

  puts "#{demonstrations.count { |one| !one.incoming? }} échanges émis, un par état, " \
       "#{demonstrations.count(&:incoming?)} reçus, " \
       "sur #{demonstrations.map(&:conversation_id).uniq.count} conversations."
  puts "#{AuditEvent.count} événements de journal, dont un refus sans échange " \
       "et trois arrivées ou départs qui ne laissent rien d'autre."
end
