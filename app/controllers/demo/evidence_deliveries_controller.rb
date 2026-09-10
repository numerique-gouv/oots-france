module Demo
  # Where the evidence is delivered to the demonstration procedure: the address
  # `DONNEES_REQUETEURS` publishes for it — `<URL_OOTS_FRANCE>/demo` — under the
  # path `EvidenceForwarder` appends, and the one an external service provider
  # exposes in its place.
  #
  # `ActionController::API` and not `ApplicationController`, for the reason
  # `DomibusNotificationsController` is: the caller is a server, there is no
  # session and therefore no CSRF protection to disable.
  #
  # Unauthenticated, and guarded by what it knows instead: a delivery naming an
  # exchange this procedure never opened is refused. Chapter 4.10 §4.1, which is
  # informative, asks only that such an event « is logged for investigation » —
  # refusing it as well is this procedure's own decision, taken so that the
  # refusal is legible from both ends. A real service provider would authenticate
  # the deployment it publishes this address to; what that authentication is, no
  # chapter says, and the demonstration would be inventing one.
  class EvidenceDeliveriesController < ActionController::API
    # A refusal a caller can act on, and one it cannot: an exchange this
    # procedure never opened will not become one, where a delivery carrying no
    # bytes is a call to make again.
    FAILURE_STATUSES = {
      demo_unplaceable: :not_found,
      demo_evidence_empty: :unprocessable_content,
    }.freeze

    def create
      result = ReceiveEvidence.call(
        exchange_id: params[:echange],
        conversation_id: params[:conversation],
        evidence: request.raw_post,
      )

      return head :created if result.success?

      head FAILURE_STATUSES.fetch(result.error[:key])
    end
  end
end
