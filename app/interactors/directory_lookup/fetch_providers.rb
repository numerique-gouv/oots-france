module DirectoryLookup
  # The organisations holding that evidence in that country, and the access
  # points reaching them.
  #
  # The version parameter is the one a real request sends, so a gateway
  # speaking another version of the EDM is absent here exactly as it would be
  # there.
  class FetchProviders < ApplicationInteractor
    include Refusing

    def call
      context.data_services = published

      fail_with_error(:no_provider, errors: [context.country_code]) if context.data_services.empty?
    rescue CommonServicesError => e
      refuse(e)
    end

    private

    def published
      context.data_service_directory.data_services(
        evidence_type_classification: context.evidence_type.id, country_code: context.country_code,
      )
    end
  end
end
