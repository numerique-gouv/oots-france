module Oots
  # Renders one specimen of each OOTS message, body and ebMS header, with the
  # repository's own builders, so `scripts/validate_schematron.sh` can confront
  # them with the rules published with the TDD.
  #
  # The values are fictional but realistic: only the structure is validated. The
  # clock and the identifier generator are frozen so that two runs produce the
  # same bytes — a validation report that changes on its own teaches nothing.
  #
  # The header is written apart from the body: it answers to its own rule set,
  # and the body does not contain it. On the wire it is the SOAP envelope
  # submitted to Domibus that brings the two together.
  class SpecimenMessages
    TIMESTAMP = '2026-08-06T10:00:00.000Z'.freeze

    REQUEST_ID = 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797'.freeze
    # One conversation covering every specimen, and one exchange identifier per
    # message: chapter 4.4 has a conversation span the exchanges of one user's
    # session, and each exchange keep its own identifier.
    CONVERSATION_ID = 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24'.freeze
    EXCHANGE_ID = '7c9e6679-7425-40de-944b-e07fc1f90ae7'.freeze

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

    def initialize(destination)
      @destination = Pathname.new(destination)
    end

    def write_all
      write('requete', *request)
      write('reponse', *system_check_response)
      write('reponseDifferee', *deferred_response)

      ERROR_SPECIMENS.each { |name, exception| write(name, *error_response(exception)) }
    end

    private

    attr_reader :destination

    def write(name, body, header)
      destination.join("#{name}.xml").write(body)
      destination.join("#{name}.entete.xml").write(header.strip)
    end

    def request
      body = EvidenceRequestBuilder.new(
        requester:, provider: german_provider, beneficiary:, requirement:, data_service:,
        procedure_code: ProcedureCode::DIPLOMA_RECOGNITION,
        clock:, uuid:,
      )

      [
        body.render,
        header(
          action: EbmsAction::EXECUTE_QUERY_REQUEST,
          original_sender: requester.ebms_identity,
          final_recipient: german_provider.ebms_identity,
          payload_id: payload_id(body.document_id),
        ),
      ]
    end

    def system_check_response
      attachment = Attachment.new("cid:#{uuid.next}@pdf.oots.fr", 'JVBERi0=')
      body = system_check_body(attachment)

      [body.render, system_check_header(body, attachment)]
    end

    def system_check_body(attachment)
      SystemCheckResponseBuilder.new(
        requester:, beneficiary:, evidence_type:, attachment:,
        request_id: REQUEST_ID, clock:, uuid:,
      )
    end

    def system_check_header(body, attachment)
      header(
        action: EbmsAction::EXECUTE_QUERY_RESPONSE,
        original_sender: french_provider.ebms_identity,
        final_recipient: requester.ebms_identity,
        payload_id: payload_id(body.document_id),
        attachment:,
      )
    end

    def deferred_response
      body = DeferredResponseBuilder.new(requester:, request_id: REQUEST_ID, clock:, uuid:)

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

    def error_response(exception)
      body = ErrorResponseBuilder.new(
        requester:, exception:, request_id: REQUEST_ID, clock:, uuid:,
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

    def header(**attributes)
      EbmsHeaderBuilder.new(
        recipient: german_access_point,
        conversation_id: CONVERSATION_ID,
        exchange_id: EXCHANGE_ID,
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

    def french_provider = @french_provider ||= EvidenceProvider.french(**Settings.french_provider_identity)

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

    def beneficiary
      @beneficiary ||= NaturalPerson.new(
        eidas_identifier: 'FR/DE/123123123', family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
      )
    end

    def evidence_type
      @evidence_type ||= EvidenceType.new(
        id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        descriptions: { 'EN' => 'Certificate of Birth' },
        distribution_format: EvidenceType::PDF,
      )
    end

    def requirement
      @requirement ||= Requirement.new(
        id: 'https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42',
        descriptions: { 'EN' => 'Proof of tertiary education diploma/certificate/degree' },
        details: { 'EN' => 'Proof that the person holds a diploma awarded by a tertiary education institution.' },
      )
    end

    def data_service
      @data_service ||= DataService.new(
        id: '41170824-15d9-4c16-984e-63b75b937b8c',
        evidence_type_classification: evidence_type.id,
        distribution_format: EvidenceType::PDF,
        distribution_language: 'EN',
        descriptions: evidence_type.descriptions,
        details: { 'EN' => 'Birth certificate issued by the civil registration office.' },
      )
    end
  end
end
