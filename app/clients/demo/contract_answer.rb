module Demo
  # What the requester contract answered the demonstration procedure, read as a
  # service provider's server would read it: a status, and whatever the body
  # carried.
  #
  # The body is a hash even when the answer carried no JSON at all — the feature
  # switch answers `Not Implemented Yet!` as plain text — so that reading a field
  # is always the same gesture. Held here rather than trusted from the caller:
  # a class that documents an invariant its callers must keep is a class that
  # loses it the day a second caller appears.
  #
  # Both calls of the contract land here, the one that opens an exchange and the
  # one that reads its state back, because both answer the same document: the
  # fields are those `EvidenceRequestsController#state_of` writes.
  class ContractAnswer
    ACCEPTED = 202

    # The one status `state_of` answers when it knows the exchange, and the
    # placeholder for the contract not having answered at all. Here rather than
    # in the caller that asks the question: what a status means for this contract
    # is this class's business, as `ACCEPTED` already is.
    READABLE = 200
    UNREACHED = 0

    def self.unreached = new(status: UNREACHED)

    attr_reader :status, :payload

    # The reading of a Faraday response, kept here and not in each client: two
    # clients call this contract and a body that is no JSON object is the same
    # non-answer to both.
    def self.from(response, path:)
      new(status: response.status, payload: parsed_hash(response, path))
    end

    def self.parsed_hash(response, path)
      parsed = JSON.parse(response.body.to_s)

      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError => e
      Rails.logger.warn(I18n.t('clients.demo.contract_answer.unreadable',
        path:, status: response.status, error: e.message))

      {}
    end
    private_class_method :parsed_hash

    def initialize(status:, payload: {})
      @status = status
      @payload = payload.is_a?(Hash) ? payload : {}
    end

    # The status **and** the two identifiers it names. `EvidenceRequestsController`
    # answers `202` from `state_of`, which is built on an `Exchange` and so
    # always carries both: an acceptance missing either is a body that did not
    # arrive whole, and taking it for a success would show the user a request
    # that left while nothing can say which — or file a register row the
    # procedure could never place a delivery against, both identifiers being what
    # it correlates on.
    def accepted? = status == ACCEPTED && exchange_id.present? && conversation_id.present?

    def readable? = status == READABLE

    def exchange_id = payload['echange']

    def conversation_id = payload['conversation']

    def error = payload['erreur']

    # What `state_of` adds when the contract is asked about an exchange rather
    # than for a new one. `exchange_status` and not `status`, which this class
    # already owes to HTTP.
    def exchange_status = payload['statut']

    def edm_error_code = payload['codeErreur']

    def preview_location = payload['adressePrevisualisation']
  end
end
