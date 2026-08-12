# An `sdg:Agent` — the organisation behind one of the four corners.
#
# The same element serves the requester, the provider and the error provider,
# with two things varying: whether it carries an address, and which
# classification it declares. Both are decided by the message, because the TDD
# put different requirements on each — an address on ER, EP and ERRP
# (R-EDM-REQ-C073 and its counterparts), and no classification at all on the
# provider of a request.
class AgentBuilder < ApplicationBuilder
  attr_reader :identity, :names, :address, :classification

  def initialize(identity:, names: {}, address: nil, classification: nil)
    @identity = identity
    @names = names
    @address = address
    @classification = classification
  end

  protected

  def template_name = '_agent.xml.erb'
end
