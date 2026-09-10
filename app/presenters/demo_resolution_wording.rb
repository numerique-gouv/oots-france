# What the confirmation page of the demonstration says of the exchange about to
# be opened: who will provide the evidence, and of which type.
#
# Requirement 27 of chapter 1 §2 asks for exactly those two, and for them
# « before any request is made » — hence a page of its own, and hence
# `nameable?`, which the page reads to decide whether it may offer to confirm at
# all: unable to name them, it must not let the request leave.
#
# The values are shown as the directories publish them, in the language they
# publish them in: substituting a wording of our own would make the
# demonstration show something no exchange rests on.
class DemoResolutionWording
  def initialize(lookup)
    @lookup = lookup
  end

  def provider = provider_entry&.label.presence

  def evidence_type = lookup.evidence_type&.label.presence

  def nameable? = provider.present? && evidence_type.present?

  # The refusal of whichever step stopped the chain, in the shape the console's
  # other directory pages already render.
  def failure
    lookup.error if lookup.failure?
  end

  private

  attr_reader :lookup

  # `sdg:Publisher` names the organisation, which is what requirement 27 calls
  # the evidence provider; `sdg:AccessService` names the gateway carrying the
  # message to it, and is not a name for a user to read.
  #
  # A step that never ran leaves nothing on the context, and a step that ran and
  # failed leaves what it found: both are read here as « nothing to name ».
  def provider_entry = Array(lookup.data_services).first&.providers&.first
end
