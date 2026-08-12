module Oots
  # Renders one specimen of each OOTS message, body and ebMS header, with the
  # repository's own builders, so `scripts/valideSchematron.sh` can confront
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
    CONVERSATION_ID = 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24'.freeze

    # A specimen for every code the repository emits: the exception type changes
    # with the code and the rules constrain it, so a code never produced here is
    # a code never confronted with the rules.
    ERROR_SPECIMENS = {
      'erreur' => EdmException::OBJECT_NOT_FOUND,
      'erreurRequeteInvalide' => EdmException::INVALID_REQUEST,
      'erreurCapaciteNonSupportee' => EdmException::UNSUPPORTED_CAPABILITY,
    }.freeze

    def initialize(destination)
      @destination = Pathname.new(destination)
    end

    def write_all
      write('requete', *request)
      write('reponse', *system_check_response)

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
        requester:, provider: german_provider, beneficiary:, evidence_type:,
        procedure_code: ProcedureCode::STUDENT_GRANT,
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
        access_point: AccessPoint.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
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
  end
end
