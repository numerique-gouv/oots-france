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

    # The SDG regulation, article 14(3)(f), makes previewing the evidence the
    # user's right, and only « applicable Union or national law » exempts a
    # procedure from it (article 14(5)): none exempts this one.
    PREVIEW_POSSIBLE = 'true'.freeze
    OUTSIDE_PROCEDURE = 'true'.freeze

    def initialize(connection: Faraday.new)
      @connection = connection
    end

    # No `raise_error` middleware, here or on the state client: a refusal is an
    # answer to a service provider, and the page has to show the status and the
    # message it carried.
    # `requirement_id` names which of the procedure's requirements is being
    # asked for. Optional at the contract, and optional here: `compact` drops it
    # where the page had none to name, and the contract then answers the first
    # requirement the country publishes for.
    #
    # `specification` is the line of the journey, a parameter no French
    # procedure has to set: each screen of the demonstration plays one line.
    #
    # `outside_procedure` asks for the requirement whether or not the Evidence
    # Broker ties it to the procedure, another parameter no French procedure has
    # to set: a card says what it resolved, and the request goes to what it
    # showed.
    def fetch(requester_id:, procedure_code:, country_code:, encrypted_beneficiary:,
              conversation_id: nil, requirement_id: nil, specification: nil, outside_procedure: false)
      response = connection.get("#{Settings.oots_france_url}#{PATH}", {
        idRequeteur: requester_id,
        codeDemarche: procedure_code,
        codePays: country_code,
        beneficiaire: encrypted_beneficiary,
        previsualisationRequise: PREVIEW_POSSIBLE,
        idConversation: conversation_id,
        idExigence: requirement_id,
        specification:,
        exigenceHorsDemarche: (OUTSIDE_PROCEDURE if outside_procedure),
      }.compact)

      ContractAnswer.from(response, path: PATH)
    end

    private

    attr_reader :connection
  end
end
