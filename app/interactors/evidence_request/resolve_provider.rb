module EvidenceRequest
  # Asks the Data Service Directory which service delivers that evidence in the
  # country, which organisation stands behind it, and through which access point
  # the message reaches them.
  #
  # The service comes already chosen: the directories façade drops the records
  # that name no access point, which is an integrity matter rather than a
  # choice. Only the first provider is kept, and that one for the same reason as
  # the evidence type — chapter 4.10.
  class ResolveProvider < ApplicationInteractor
    def call
      resolve
    rescue CountryCodeNotFound => e
      fail_with_error(:unknown_country, errors: [e.message])
    rescue InvalidDirectoryEntry => e
      fail_with_error(:invalid_directory_entry, errors: [e.message])
    rescue CommonServicesError => e
      fail_with_error(:common_services_refused, errors: [e.message])
    end

    private

    def resolve
      service = context.common_services.data_service(context.evidence_type.id, context.country_code)
      provider = service&.providers&.first

      # The directory answers a refusal rather than an empty list, but nothing
      # obliges it to: without this, a nil provider would surface two steps
      # later as an opaque NoMethodError.
      return fail_with_error(:no_provider, errors: [context.country_code]) if provider.nil?

      keep(service, provider)
    end

    # The access point comes from the directory with the provider, so the
    # message has its recipient without a second lookup.
    def keep(service, provider)
      context.data_service = service
      context.provider = provider
      context.recipient = provider.access_point
    end
  end
end
