module Demo
  # What `GET /requete/pieceJustificative` answered the demonstration procedure,
  # read as a service provider's server would read it: a status, and whatever
  # the body carried.
  #
  # The body is a hash even when the answer carried no JSON at all — the feature
  # switch answers `Not Implemented Yet!` as plain text — so that reading a field
  # is always the same gesture, and the status alone decides what happened.
  class ContractAnswer
    ACCEPTED = 202

    attr_reader :status, :payload

    def initialize(status:, payload: {})
      @status = status
      @payload = payload
    end

    def accepted? = status == ACCEPTED

    def exchange_id = payload['echange']

    def conversation_id = payload['conversation']

    def error = payload['erreur']
  end
end
