module EvidenceRequest
  # Asks which organisation in the country holds that evidence. Only the first
  # provider is kept, for the same reason as the evidence type.
  class ResolveProvider < ApplicationInteractor
    def call
      context.provider = first_provider

      # The stubbed directory raises rather than returning an empty list, but a
      # real Evidence Broker need not: without this, a nil provider would
      # surface two steps later as an opaque NoMethodError.
      fail_with_error(:no_provider, errors: [context.country_code]) if context.provider.nil?
    rescue CountryCodeNotFound => e
      fail_with_error(:unknown_country, errors: [e.message])
    end

    private

    def first_provider
      context.common_services.providers(context.evidence_type.id, context.country_code).first
    end
  end
end
