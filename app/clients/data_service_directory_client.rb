# The Data Service Directory: who, in a country, holds an evidence type, and
# at which access point (chapter 3.1.4).
#
# `specification` is what makes version negotiation happen at the directory
# rather than here: the service returns only the access services declaring that
# `ConformsTo`, so an empty result means no correspondent speaks our version.
class DataServiceDirectoryClient
  DATA_SERVICES_QUERY =
    'urn:fdc:oots:dsd:ebxml-regrep:queries:dataservices-by-evidencetype-and-jurisdiction'.freeze

  def initialize(query: nil)
    @query = query || CommonServicesQuery.new(CommonServicesInstance::DATA_SERVICE_DIRECTORY)
  end

  def data_services(evidence_type_classification:, country_code:)
    @query.search(
      {
        queryId: DATA_SERVICES_QUERY,
        'evidence-type-classification': evidence_type_classification,
        'country-code': country_code,
        specification: EdmSpecification::IDENTIFIER,
      },
      parser: DataServicesResponseParser,
    ).providers
  end
end
