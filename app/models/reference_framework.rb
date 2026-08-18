# A national procedure, as the Evidence Broker publishes it: the declaration by
# which a member state says one of its procedures rests on a requirement
# (chapter 3.2.4). It is what the glossary calls a *démarche*.
#
# `procedure_code` is the SDG code the declaration maps onto — `R1`, `T2`, and
# `00` for the test procedure — and it is the only part of this a request
# carries. The identifier and the title belong to the member state, which is
# why two countries declaring the same code publish nothing alike: Germany
# titles its own `R1` declaration after registering a birth, Lithuania names a
# `T2` one after the admission platform that runs it.
class ReferenceFramework
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Described

  attribute :id, :string
  attribute :procedure_code, :string
  attribute :country, :string

  attr_reader :descriptions, :details
  # Written back by `Requirement`, which the directory nests these inside.
  attr_accessor :requirement

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    super
  end
end
