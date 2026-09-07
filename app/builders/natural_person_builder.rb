# The `sdg:Person` describing whom the evidence is about.
#
# The eIDAS identifier, the place of birth and the sex are emitted only when
# there is one: the requester's token does not always carry them, and an empty
# element would assert what was never established.
#
# Omitted for different reasons, though. `R-EDM-REQ-C038` asks for the
# identifier of whoever has one to give, in the `WARNING` role a `SHOULD` earns,
# where no rule of `EDM-REQ-C` asks after the other two under a `NaturalPerson`
# slot at all.
class NaturalPersonBuilder < ApplicationBuilder
  attr_reader :person

  def initialize(person:)
    @person = person
  end

  protected

  def template_name = '_natural_person.xml.erb'
end
