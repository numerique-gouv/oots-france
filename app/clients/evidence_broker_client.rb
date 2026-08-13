# The Evidence Broker: which evidence satisfies a procedure, in a given
# jurisdiction (chapter 3.2.4).
#
# Two queries, and they chain: a procedure yields requirements, a requirement
# yields the evidence types that meet it. The country of the first is the
# requester's jurisdiction, that of the second the provider's.
class EvidenceBrokerClient
  REQUIREMENTS_QUERY =
    'urn:fdc:oots:eb:ebxml-regrep:queries:requirements-by-procedure-and-jurisdiction'.freeze
  EVIDENCE_TYPES_QUERY =
    'urn:fdc:oots:eb:ebxml-regrep:queries:evidence-types-by-requirement-and-jurisdiction'.freeze

  def initialize(query: nil)
    @query = query || CommonServicesQuery.new(CommonServicesInstance::EVIDENCE_BROKER)
  end

  def requirement_identifiers(procedure_code:, country_code:)
    @query.search(
      { queryId: REQUIREMENTS_QUERY, 'procedure-id': procedure_code, 'country-code': country_code },
      parser: RequirementsResponseParser,
    ).requirement_identifiers
  end

  def evidence_types(requirement_id:, country_code:)
    @query.search(
      { queryId: EVIDENCE_TYPES_QUERY, 'requirement-id': requirement_id, 'country-code': country_code },
      parser: EvidenceTypesResponseParser,
    ).evidence_types
  end
end
