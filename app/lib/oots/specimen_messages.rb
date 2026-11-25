module Oots
  # Renders one specimen of each OOTS message, body and ebMS header, with the
  # repository's own builders, so `scripts/validate_schematron.sh` can confront
  # them with the rules published with the TDD.
  #
  # One set per EDM version, each written against the rules of its own tag: the
  # two lines differ in what they carry, so a single set could only ever satisfy
  # one of them.
  #
  # The values are fictional but realistic: only the structure is validated. The
  # clock and the identifier generator are frozen so that two runs produce the
  # same bytes — a validation report that changes on its own teaches nothing.
  #
  # The header is written apart from the body: it answers to its own rule set,
  # and the body does not contain it. On the wire it is the SOAP envelope
  # submitted to Domibus that brings the two together.
  class SpecimenMessages
    include SpecimenValues

    TIMESTAMP = Time.utc(2026, 8, 6, 10, 0, 0).freeze

    REQUEST_ID = 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797'.freeze
    # One conversation covering every specimen, and one exchange identifier per
    # message: chapter 4.4 has a conversation span the exchanges of one user's
    # session, and each exchange keep its own identifier.
    CONVERSATION_ID = 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24'.freeze
    EXCHANGE_ID = '7c9e6679-7425-40de-944b-e07fc1f90ae7'.freeze

    # `R-EDM-ERR-C019` asks for `https://`, whatever the deployment runs on.
    PREVIEW_TOKEN = '9b2f6c1e-3d4a-4f8b-a1c2-5e6d7f8a9b0c'.freeze

    # The two addresses of the second request France sends as a requester:
    # the one a correspondent returned, and France's own return address. Fixed
    # here and not read from `URL_OOTS_FRANCE`, which the local loop and the
    # continuous integration set to `http://` — `R-EDM-REQ-C005` and `C120` ask
    # for `https://` whatever the deployment runs on.
    FOREIGN_PREVIEW_LOCATION = 'https://ap.example.de/preview/2d7c4b1a-8e3f-4a6b-9c5d-0e1f2a3b4c5d?session=abc'.freeze
    RETURN_LOCATION = 'https://oots.example.gouv.fr/retour/5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d'.freeze

    # A specimen for every code the repository emits: the exception type changes
    # with the code and the rules constrain it, so a code never produced here is
    # a code never confronted with the rules.
    ERROR_SPECIMENS = {
      'erreur' => EdmException::OBJECT_NOT_FOUND,
      # The one specimen carrying a `detail`, so that the rules are asked
      # whether an exception naming the rule it refused conforms. No
      # `R-EDM-ERR-*` constrains the attribute, and nothing else would prove it.
      'erreurRequeteInvalide' => EdmException::INVALID_REQUEST.with_detail('R-EDM-REQ-S016'),
      'erreurCapaciteNonSupportee' => EdmException::UNSUPPORTED_CAPABILITY,
      'erreurExpiration' => EdmException::TIMEOUT,
    }.freeze

    # The one form nothing else produces: `R-EDM-ERR-C025` (FATAL) lets a
    # response omit `requestId` when — and only when — its exception is
    # `rs:InvalidRequestExceptionType`, which is what France answers a request
    # whose own identifier broke `R-EDM-REQ-S004`. Last, so that the sequential
    # identifiers of the seven specimens above do not shift.
    IDENTIFIERLESS_SPECIMEN = 'erreurSansIdentifiantDeRequete'.freeze

    # The one specimen this repository must never emit, and the only one the
    # validation expects to be refused: `R-EDM-ebMS-017` and `-037` are FATAL,
    # and every other specimen satisfies them, so nothing else asks whether they
    # bite. `EvidenceProvision::RejectMalformedIdentifiers` turns away one carrying such
    # a pair rather than reuse it in the answer France signs; this is what says
    # the rules it invokes refuse what it claims they refuse.
    #
    # A header alone: the two rules anchor on the ebMS header, and no RegRep body
    # carries either identifier.
    MALFORMED_IDENTIFIERS_SPECIMEN = 'identifiantsMalformes'.freeze

    # Neither is a UUID, and they differ so that a report naming one is not read
    # as naming the other.
    MALFORMED_CONVERSATION_ID = 'pas-un-uuid'.freeze
    MALFORMED_EXCHANGE_ID = 'ni-celui-ci'.freeze

    # The header of the older line, kept beside the specimens of the newer for
    # the sole purpose of being refused by them: `R-EDM-ebMS-018` counts four
    # properties in 2.0.1, and `R-EDM-ebMS-019`, whose context there is
    # `eb:MessageProperties` where 1.2.5 anchors it on `eb:Property`, counts each
    # of the four names once — so a two-property header breaks both, and naming
    # only one of them would fail a specimen that is exactly as intended.
    EARLIER_LINE_SPECIMEN = 'versionAnterieure'.freeze

    # The one request the 1.2 line must refuse, and the only body the validation
    # expects to be refused: `R-EDM-REQ-C032` counts `sdg:DistributedAs`
    # `= 1 or = 0` at the 1.2.5 tag — « must occur not more than once » — where
    # 2.0.1 counts `> 0`. Every other specimen names one distribution, so
    # nothing else asks whether that assertion bites; and it has no counterpart
    # at the 2.0.1 tag, where the same request is conformant.
    #
    # A body alone: `EDM-REQ-C` is the only rule set that judges it, and no ebMS
    # header carries a distribution.
    SEVERAL_DISTRIBUTIONS_SPECIMEN = 'requeteDeuxDistributions'.freeze

    # The prefixes of the files of a pair: what the correspondent sent, and
    # what France answers to the request it received.
    CORRESPONDENT = 'correspondant'.freeze
    RECEIVED = 'recue'.freeze

    def initialize(destination, specification: EdmSpecification.preferred)
      @destination = Pathname.new(destination)
      @specification = specification
    end

    def write_all
      write_requests
      write_responses
      write('reponseDifferee', *deferred_response)

      ERROR_SPECIMENS.each { |name, exception| write(name, *error_response(exception)) }
      write(IDENTIFIERLESS_SPECIMEN,
        *error_response(EdmException::INVALID_REQUEST.with_detail('R-EDM-REQ-S004'), request_id: nil))

      write_refused_specimens
      write_preview_specimens
      write_conversation_specimens
    end

    private

    # Last for the reason the specimen above is last: `header` draws a message
    # identifier from the sequence, and the specimens the rules accept must not
    # shift because of the one they refuse.
    def write_refused_specimens
      write_header(MALFORMED_IDENTIFIERS_SPECIMEN, malformed_header)
      write_earlier_line_header unless specification == EdmSpecification::V1_2
      write_several_distributions_request if specification == EdmSpecification::V1_2
    end

    attr_reader :destination, :specification

    # One specimen per kind of subject: R-EDM-REQ-S016 admits a `NaturalPerson`
    # or a `LegalPerson` and never both, so the rules of the second slot are
    # confronted by a document of its own or not at all.
    def write_requests
      write('requete', *request)
      write('requetePersonneMorale', *request(subject: legal_person))
      write('requeteClassification', *request(provider_classifications: [code_list_classification]))
      write('requeteTroisClassifications', *request(provider_classifications: three_classifications))
      write('requeteFormatStructure', *request(service: structured_data_service))
    end

    # One specimen per kind of subject, for the reason the requests have one:
    # `sdg:IsAbout` is an `xs:choice`, and R-EDM-RESP-S042 bounds the legal
    # branch to two elements, so a document carrying the natural branch says
    # nothing of the rules the other answers to.
    def write_responses
      write('reponse', *evidence_response)
      write('reponsePersonneMorale', *evidence_response(subject: legal_person))
      write('reponseStatutEtudiant', *student_status_response)
      write('reponseStatutEtudiantPdf', *student_status_response(StudentStatus::ATTESTATION))
    end

    def write(name, body, header)
      destination.join("#{name}.xml").write(body)
      write_header(name, header)
    end

    def write_header(name, header) = destination.join("#{name}.entete.xml").write(header.strip)

    # A preview location makes it the second request of chapter 4.9 §2 step 12,
    # which only a request that offered the preview can be.
    def request(subject: beneficiary, preview_location: nil, return_location: nil, provider_classifications: [],
                service: data_service, preview_possible: preview_location.present?, clock: self.clock, **header)
      body = EvidenceRequestBuilder.new(
        requester:, provider: german_provider, beneficiary: subject, requirement:, data_service: service,
        procedure_code: ProcedureCode::DIPLOMA_RECOGNITION,
        associated_documents: [AssociatedDocument::TRANSLATION], provider_classifications:,
        preview_possible:, preview_location:, return_location:,
        specification:, clock:, uuid:,
      )

      [body.render, request_header(body, clock:, **header)]
    end

    def request_header(body, **)
      header(
        action: EbmsAction::EXECUTE_QUERY_REQUEST,
        original_sender: requester.ebms_identity,
        final_recipient: german_provider.ebms_identity,
        payload_id: payload_id(body.document_id),
        **,
      )
    end

    def evidence_response(subject: beneficiary)
      attachment = Attachment.new(payload_id(uuid.next), 'JVBERi0=')
      body = evidence_response_body(beneficiary: subject, evidence_type:, evidence_reference: attachment.identifier)

      [body.render, evidence_response_header(body, attachment)]
    end

    # « FR - Student status (MESRI) »: the data in JSON, or the attestation in
    # PDF, with its language, and the ministry as the issuer.
    def student_status_response(distribution = StudentStatus::DATA)
      attachment = Attachment.new(payload_id(uuid.next), 'e30=', mime_type: distribution.format)
      body = evidence_response_body(beneficiary:, evidence_type:, evidence_reference: attachment.identifier,
        issuer: StudentStatus.issuer, distribution:)

      [body.render, evidence_response_header(body, attachment)]
    end

    # France as the provider the request designates: the specimens stand alone,
    # with no request whose provider they could echo.
    def evidence_response_body(**)
      EvidenceResponseBuilder.new(requester:, provider: french_provider, request_id: REQUEST_ID, specification:, clock:,
        uuid:, **)
    end

    def evidence_response_header(body, attachment)
      header(
        action: EbmsAction::EXECUTE_QUERY_RESPONSE,
        original_sender: french_provider.ebms_identity,
        final_recipient: requester.ebms_identity,
        payload_id: payload_id(body.document_id),
        attachment:,
      )
    end

    def deferred_response
      body = DeferredResponseBuilder.new(requester:, provider: french_provider, request_id: REQUEST_ID, specification:,
        clock:, uuid:)

      [
        body.render,
        header(
          action: EbmsAction::EXECUTE_QUERY_RESPONSE,
          original_sender: french_provider.ebms_identity,
          final_recipient: requester.ebms_identity,
          payload_id: payload_id(body.document_id),
        ),
      ]
    end

    # The two messages of chapter 4.9 France emits as a provider: the exception
    # sending the user to its preview space, and the empty list — to a user who
    # used nothing, or whom no document matches, at either exchange (chapter
    # 4.9 §1 and §2, step 4); and the one it emits as a requester, the second
    # request. Last, so that the identifiers drawn above do not shift — the
    # second request last of all.
    def write_preview_specimens
      write('erreurPrevisualisationRequise',
        *error_response(EdmException::AUTHORIZATION, preview_location:))
      write('reponseVide', *empty_response)
      write('requeteSeconde', *second_request)
    end

    # Step 12 of chapter 4.9 §2, as France sends it once a correspondent asked
    # for the preview: the address that correspondent returned, sent back on the
    # conversation, the exchange and towards the access point its error came
    # from. Under a clock of its own, two minutes on: `R-EDM-REQ1_EDM-REQ2-02`
    # has the second request carry another `IssueDateTime` than the first.
    def second_request
      refusal = correspondent.received('erreurPrevisualisationRequise')

      request(preview_location: refusal.body.preview_location, return_location: RETURN_LOCATION,
        clock: FrozenClock.new(TIMESTAMP + 120), conversation_id: refusal.conversation_id,
        exchange_id: refusal.exchange_id, recipient: refusal.sender)
    end

    # The specimens the cross-validation rules judge in pairs, a French message
    # against the one it answers or follows. Last, so that no identifier drawn
    # above shifts.
    def write_conversation_specimens
      correspondent.copy_to(destination, CORRESPONDENT)
      write('requetePremiere', *request(preview_possible: true))

      AnswerSpecimens.new(correspondent.received('requete'), errors: ERROR_SPECIMENS, preview_location:, clock:, uuid:)
        .each { |name, body, header| write("#{RECEIVED}.#{name}", body, header) }
    end

    def correspondent = @correspondent ||= CorrespondentMessages.new(specification)

    # Under the segment of the line of the set, as `PreviewSession.location_for`
    # composes it.
    def preview_location = "https://oots.example.gouv.fr/previsualisation/#{specification.segment}/#{PREVIEW_TOKEN}"

    def empty_response
      body = evidence_response_body

      [body.render, evidence_response_header(body, EmptyAttachment.new)]
    end

    def error_response(exception, request_id: REQUEST_ID, preview_location: nil)
      body = ErrorResponseBuilder.new(
        requester:, exception:, request_id:, preview_location:, specification:, clock:, uuid:,
      )

      [
        body.render,
        header(
          action: EbmsAction::EXCEPTION_RESPONSE,
          original_sender: french_provider.ebms_identity,
          final_recipient: requester.ebms_identity,
          payload_id: payload_id(body.document_id),
        ),
      ]
    end

    # The header of a request in every respect but its two identifiers, so that
    # the rules refuse those and nothing else — `R-EDM-ebMS-026` and `-027`
    # constrain the part reference just as tightly, and a specimen sloppy there
    # would be refused for the wrong reason. Hence a drawn identifier and not a
    # literal: it is the shape a body would have given.
    def malformed_header
      header(
        action: EbmsAction::EXECUTE_QUERY_REQUEST,
        original_sender: requester.ebms_identity,
        final_recipient: german_provider.ebms_identity,
        payload_id: payload_id(uuid.next),
        conversation_id: MALFORMED_CONVERSATION_ID,
        exchange_id: MALFORMED_EXCHANGE_ID,
      )
    end

    # A request header in every respect but its version, so that the rules of
    # the newer line refuse it for the two properties it does not carry and for
    # nothing else.
    def write_earlier_line_header
      write_header(EARLIER_LINE_SPECIMEN, header(
        action: EbmsAction::EXECUTE_QUERY_REQUEST,
        original_sender: requester.ebms_identity,
        final_recipient: german_provider.ebms_identity,
        payload_id: payload_id(uuid.next),
        specification: EdmSpecification::V1_2,
      ))
    end

    # Forged from the body already rendered, and neither rendered again nor
    # asked of the builder: `EvidenceTypeBuilder` writes one `sdg:DistributedAs`
    # and must never be able to write two — the emission path is what
    # `R-EDM-REQ-C032` judges on the way out —, and a second rendering would
    # draw from the identifier sequence and shift the UUIDs of every conformant
    # specimen.
    #
    # Read back from the file rather than kept in a variable, so that what the
    # rules are asked about is exactly what they were asked about beside it.
    def write_several_distributions_request
      destination.join("#{SEVERAL_DISTRIBUTIONS_SPECIMEN}.xml")
        .write(with_doubled_distribution(destination.join('requete.xml').read))
    end

    # The distribution of the rendered request, copied beside itself: the rule
    # counts the element, so a second one identical to the first breaks it and
    # breaks nothing else.
    def with_doubled_distribution(body)
      document = Nokogiri::XML(body)
      distribution = document.at_xpath('//sdg:DistributedAs', OotsNamespaces::NAMESPACES)
      distribution.add_next_sibling(distribution.dup)

      document.to_xml
    end

    def header(**attributes)
      EbmsHeaderBuilder.new(
        recipient: german_access_point,
        conversation_id: CONVERSATION_ID,
        exchange_id: EXCHANGE_ID,
        specification:,
        clock:, uuid:,
        **attributes,
      ).render
    end

    def payload_id(document_id) = OutgoingEnvelopeBuilder.payload_reference(document_id)

    def clock = @clock ||= FrozenClock.new(TIMESTAMP)

    def uuid = @uuid ||= SequentialUuids.new

    def requester
      @requester ||= EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur")
    end

    def french_provider = @french_provider ||= EvidenceProvider.french

    def german_provider
      @german_provider ||= EvidenceProvider.new(
        identifier: EbmsIdentity.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
        access_point: german_access_point,
        descriptions: { 'EN' => 'Civil Registration Office Berlin I' },
      )
    end

    def german_access_point
      @german_access_point ||= AccessPoint.new(
        id: 'AP_DE_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots',
      )
    end
  end
end
