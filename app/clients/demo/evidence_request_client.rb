module Demo
  # The demonstration procedure calling `GET /requete/pieceJustificative` over
  # HTTP, exactly as the server of a French service provider would.
  #
  # Over HTTP and not through `EvidenceRequest::Fetch`, which sits one method
  # call away: going through the contract is what makes the demonstration prove
  # something. Calling the organizer directly would exercise neither the token,
  # nor the key publication, nor the query string a real caller has to get
  # right.
  class EvidenceRequestClient
    PATH = '/requete/pieceJustificative'.freeze

    # The demonstration asks for the evidence itself, never for a preview: the
    # preview space of chapter 4.9 is not implemented here. Written out rather
    # than omitted — `EvidenceRequestsController` reads a bare parameter as true.
    NO_PREVIEW = 'false'.freeze

    def initialize(connection: Faraday.new)
      @connection = connection
    end

    def fetch(requester_id:, procedure_code:, country_code:, encrypted_beneficiary:, conversation_id: nil)
      response = connection.get("#{Settings.oots_france_url}#{PATH}", {
        idRequeteur: requester_id,
        codeDemarche: procedure_code,
        codePays: country_code,
        beneficiaire: encrypted_beneficiary,
        previsualisationRequise: NO_PREVIEW,
        idConversation: conversation_id,
      }.compact)

      ContractAnswer.new(status: response.status, payload: payload(response))
    end

    private

    attr_reader :connection

    # No `raise_error` middleware: a refusal is an answer here, and the page has
    # to show the status and the message it carried. Only a body that is no JSON
    # object at all becomes nothing — the feature switch answers in plain text.
    def payload(response)
      parsed = JSON.parse(response.body.to_s)

      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError => e
      Rails.logger.warn(I18n.t('clients.demo.evidence_request_client.unreadable',
        path: PATH, status: response.status, error: e.message))

      {}
    end
  end
end
