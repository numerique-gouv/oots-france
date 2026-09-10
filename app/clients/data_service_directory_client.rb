# The Data Service Directory: who, in a country, holds an evidence type, and
# at which access point (chapter 3.1.4).
#
# No `specification` parameter, and that is what lets France pick a version per
# correspondent: chapter 3.1.4 § 4.2.2 has a query omitting it come back with
# every Data Service using an OOTS EDM specification, whatever its version, and
# the `sdg:ConformsTo` each answer carries is then what decides.
class DataServiceDirectoryClient
  DATA_SERVICES_QUERY =
    'urn:fdc:oots:dsd:ebxml-regrep:queries:dataservices-by-evidencetype-and-jurisdiction'.freeze

  def initialize(query: nil)
    @query = query || CommonServicesQuery.new(CommonServicesInstance::DATA_SERVICE_DIRECTORY)
  end

  # Everything the directory publishes about the pairing: what a request adopts
  # into its `DataServiceEvidenceType`, the organisations delivering it, and the
  # level of assurance no message carries but an operator reads.
  def data_services(evidence_type_classification:, country_code:)
    read(evidence_type_classification:, country_code:).data_services
  end

  private

  def read(evidence_type_classification:, country_code:)
    @query.search(
      {
        queryId: DATA_SERVICES_QUERY,
        'evidence-type-classification': evidence_type_classification,
        'country-code': country_code,
      },
      parser: DataServicesResponseParser,
    )
  end
end
