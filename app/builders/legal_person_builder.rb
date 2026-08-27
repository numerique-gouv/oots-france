# The `sdg:LegalPerson` describing which organisation the evidence is about.
#
# `sdg:LegalPersonType` is an `xs:sequence`, so the order below is imposed: the
# optional `Identifier` precedes the mandatory `LegalPersonIdentifier`, and the
# obvious reading — mandatory first — produces a document a correspondent's
# schema validation refuses.
class LegalPersonBuilder < ApplicationBuilder
  attr_reader :person

  def initialize(person:)
    @person = person
  end

  protected

  def template_name = '_legal_person.xml.erb'
end
