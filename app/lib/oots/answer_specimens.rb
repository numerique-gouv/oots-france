module Oots
  # Every kind of answer France sends back to one received request, body and
  # header, as `AnswerBuilder` assembles it in production: what the
  # cross-validation rules confront with that request.
  class AnswerSpecimens
    include Enumerable

    def initialize(received, errors:, preview_location:, clock:, uuid:)
      @received = received
      @errors = errors
      @preview_location = preview_location
      @uuid = uuid
      @answers = AnswerBuilder.new(message: received, request_id: request.request_id, clock:, uuid:)
    end

    # Yields the name of each specimen, its body and its header.
    def each
      yield 'reponse', *served
      query_responses.each { |name, body| yield name, *answered(body, EbmsAction::EXECUTE_QUERY_RESPONSE) }
      refusals.each { |name, body| yield name, *answered(body, EbmsAction::EXCEPTION_RESPONSE) }
    end

    private

    attr_reader :received, :errors, :preview_location, :uuid, :answers

    def request = received.body

    # In the order `EvidenceProvision::ChooseAnswer#served` draws them: the
    # reference first, then the body.
    def served
      reference = OutgoingEnvelopeBuilder.payload_reference(uuid.next)
      body = answers.evidence_response(beneficiary: request.beneficiary, evidence_type: request.evidence_type,
        evidence_reference: reference)

      answered(body, EbmsAction::EXECUTE_QUERY_RESPONSE, attachment: answers.attachment(body, '%PDF-'))
    end

    def query_responses = { 'reponseVide' => answers.empty_response, 'reponseDifferee' => answers.deferred_response }

    def refusals
      errors.transform_values { answers.error_response(it) }
        .merge('erreurPrevisualisationRequise' => answers.error_response(EdmException::AUTHORIZATION, preview_location:))
    end

    def answered(body, action, **) = [body.render, answers.envelope(body, action, **).header]
  end
end
