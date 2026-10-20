module EvidenceRequest
  # Asks the Data Service Directory which service delivers that evidence in the
  # country, which organisation stands behind it, and through which access point
  # the message reaches them.
  #
  # The service comes already chosen: the directories façade drops the records
  # that name no access point, which is an integrity matter rather than a
  # choice. Only the first provider is kept: chapter 3.1.4 gives no rule for
  # choosing among several.
  class ResolveProvider < ApplicationInteractor
    def call
      resolve
    rescue CountryCodeNotFound => e
      fail_with_error(:unknown_country, errors: [e.message])
    rescue InvalidDirectoryEntry => e
      fail_with_error(:invalid_directory_entry, errors: [e.message])
    rescue ProviderClassificationRequired => e
      fail_with_error(:provider_classification_required, errors: [e.message])
    rescue CommonServicesError => e
      fail_with_error(:common_services_refused, errors: [e.message])
    end

    private

    def resolve
      service = common_services.data_service(context.evidence_type.id, context.country_code,
        classifications: answers)
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
      context.provider_classifications = answered(service)
    end

    # The user's answers to a `DSD:ERR:0005`, by question UUID, which the caller
    # passes along when it asked the questions itself.
    def answers = context.provider_classification_answers.to_h

    # What the request writes in its `EvidenceProviderClassification` slot: each
    # classification the service was matched on and the user answered, adopted
    # from the directory's answer with the user's value — chapter 4.5.1 §3.4.
    def answered(service)
      given = EvidenceProviderClassification.answers_for(service.classifications, answers)

      service.classifications.filter_map do |classification|
        classification.answered(given[classification.id]) if given.key?(classification.id)
      end
    end

    def common_services = context.common_services ||= Directories::CommonServices.new
  end
end
