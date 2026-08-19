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
  attr_reader :data_service

  def initialize(data_service:)
    @data_service = data_service
  end

  protected

  def template_name = '_evidence_type.xml.erb'
end
