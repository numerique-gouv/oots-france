# The `sdg:Person` describing whom the evidence is about.
#
# The eIDAS identifier is emitted only when there is one: the requester's token
# does not always carry it, and an empty element would assert an identity that
# was never established.
class NaturalPersonBuilder < ApplicationBuilder
  attr_reader :person

  def initialize(person:)
    @person = person
  end

  protected

  def template_name = '_natural_person.xml.erb'
end
