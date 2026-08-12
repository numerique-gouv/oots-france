module EvidenceRequest
  # Asks the Data Service Directory which organisation in the country holds
  # that evidence, and through which access point the message reaches it.
  #
  # Only the first provider is kept, for the same reason as the evidence type.
  class ResolveProvider < ApplicationInteractor
    def call
      provider = first_provider

      # The directory answers a refusal rather than an empty list, but nothing
      # obliges it to: without this, a nil provider would surface two steps
      # later as an opaque NoMethodError.
      return fail_with_error(:no_provider, errors: [context.country_code]) if provider.nil?

      context.provider = provider
      context.recipient = provider.access_point
    rescue CountryCodeNotFound => e
      fail_with_error(:unknown_country, errors: [e.message])
    rescue CommonServicesError => e
      fail_with_error(:common_services_refused, errors: [e.message])
    end

    private

    def first_provider
      context.common_services.providers(context.evidence_type.id, context.country_code).first
    end
  end
end
