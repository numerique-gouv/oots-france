module EvidenceRequest
  # Resolves the provider's access point in the PMode, which is where the
  # message is actually addressed.
  class ResolveAccessPoint < ApplicationInteractor
    def call
      context.recipient = context.gateway.find_access_point(context.provider.access_point_id)
    rescue RecipientNotFound => e
      fail_with_error(:unknown_recipient, errors: [e.message])
    # The same gateway outage one step later is reported as a 502; reporting it
    # as an unhandled 500 here would depend on which step happened to hit it.
    rescue Faraday::Error, JSON::ParserError => e
      fail_with_error(:gateway_refused, errors: [e.message])
    end
  end
end
