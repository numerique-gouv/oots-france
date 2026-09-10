module Demo
  # What `GET /requete/pieceJustificative` answered the demonstration procedure,
  # read as a service provider's server would read it: a status, and whatever
  # the body carried.
  #
  # The body is a hash even when the answer carried no JSON at all — the feature
  # switch answers `Not Implemented Yet!` as plain text — so that reading a field
  # is always the same gesture. Held here rather than trusted from the caller:
  # a class that documents an invariant its callers must keep is a class that
  # loses it the day a second caller appears.
  class ContractAnswer
    ACCEPTED = 202

    attr_reader :status, :payload

    def initialize(status:, payload: {})
      @status = status
      @payload = payload.is_a?(Hash) ? payload : {}
    end

    # The status **and** the exchange it names. `EvidenceRequestsController`
    # answers `202` from `state_of`, which is built on an `Exchange` and so
    # always carries `echange`: an acceptance without one is a body that did not
    # arrive whole, and taking it for a success would show the user a request
    # that left while nothing can say which.
    def accepted? = status == ACCEPTED && exchange_id.present?

    def exchange_id = payload['echange']

    def conversation_id = payload['conversation']

    def error = payload['erreur']
  end
end
