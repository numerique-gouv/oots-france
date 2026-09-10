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

    # No `raise_error` middleware, here or on the state client: a refusal is an
    # answer to a service provider, and the page has to show the status and the
    # message it carried.
    def fetch(requester_id:, procedure_code:, country_code:, encrypted_beneficiary:, conversation_id: nil)
      response = connection.get("#{Settings.oots_france_url}#{PATH}", {
        idRequeteur: requester_id,
        codeDemarche: procedure_code,
        codePays: country_code,
        beneficiaire: encrypted_beneficiary,
        previsualisationRequise: NO_PREVIEW,
        idConversation: conversation_id,
      }.compact)

      ContractAnswer.from(response, path: PATH)
    end

    private

    attr_reader :connection
  end
end
