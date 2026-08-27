# The `sdg:DataServiceEvidenceType` naming what is being asked for.
#
# Everything it holds comes from the Data Service Directory: chapter 4.5.1 has
# this slot « adopted from the QueryResponse of the Data Services Directory »,
# down to the titles and the distribution. The Evidence Broker only says which
# evidence type to look a service up for.
#
# The default namespace declared on the element is odd — it redeclares rim on a
# `sdg:` element that needs it for nothing — but it is what correspondents
# receive today, and dropping it is a change to the payloads, to be made
# against the TDD examples and the Schematron rules rather than in passing.
class EvidenceTypeBuilder < ApplicationBuilder
  attr_reader :data_service, :associated_documents

  def initialize(data_service:, associated_documents: [])
    @data_service = data_service
    @associated_documents = AssociatedDocument.vetted(associated_documents)
  end

  # Omitted rather than refused where the requested format is unstructured:
  # R-EDM-REQ-C107 (FATAL) forbids writing it there, R-DSD-RESP-C067 keeps a
  # conformant directory from publishing one there in the first place, and
  # chapter 4.5.1 asks for the element to be left out — not for the exchange to
  # be abandoned over a value that can simply be left unsaid.
  def conformance
    data_service.distribution_conforms_to if data_service.structured_distribution?
  end

  protected

  def template_name = '_evidence_type.xml.erb'
end
