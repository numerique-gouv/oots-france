# The `sdg:Person` describing whom the evidence is about.
#
# The eIDAS identifier, the place of birth and the sex are emitted only when
# there is one: the requester's token does not always carry them, and an empty
# element would assert what was never established.
#
# Omitted for different reasons, though. `R-EDM-REQ-C038` asks for the
# identifier of whoever has one to give, in the `WARNING` role a `SHOULD` earns,
# where nothing asks for the other two at all. What governs those two is their
# content once written: `R-EDM-REQ-C092` (FATAL) holds `sdg:PlaceOfBirth` to two
# characters wherever it appears, and no rule at all judges `sdg:Gender` under a
# `NaturalPerson` slot.
class NaturalPersonBuilder < ApplicationBuilder
  attr_reader :person

  def initialize(person:)
    @person = person
  end

  protected

  def template_name = '_natural_person.xml.erb'
end
