# One `sdg:Requirement` as the Evidence Broker publishes it (chapter 3.2.4),
# which both of its queries carry in their `Requirement` slot: the first around
# the procedures declaring it, the second around the evidence types satisfying
# it. Read the same way whichever answer it comes from.
module RequirementReading
  private

  def build_requirement(declared)
    Requirement.new(
      id: requirement_identifier(declared),
      descriptions: by_language(all(declared, './sdg:Name')),
      details: by_language(all(declared, './sdg:Description')),
      reference_frameworks: all(declared, './sdg:ReferenceFramework').map { |found| framework(found) },
    )
  end

  # Without it the second query would go out with an empty `requirement-id`,
  # and what came back would depend on how tolerant the directory happens to be.
  def requirement_identifier(declared)
    found = text(declared, './sdg:Identifier')
    raise CommonServicesError, I18n.t('parsers.requirement_reading.requirement_without_id') if found.blank?

    found
  end

  # Not validated, unlike the identifier above: a declaration missing its code
  # or its jurisdiction is one line of a console listing that cannot be placed,
  # where refusing here would take the whole answer down — and this reading is
  # on the path of every real request.
  #
  # An element the directory published empty reads as the empty string, where
  # one it left out reads as nil: both mean the same thing here, and both are
  # rendered as nil so that a caller places such a declaration by asking whether
  # it has a code or a jurisdiction, rather than by remembering that « » is not
  # one.
  def framework(found)
    ReferenceFramework.new(
      id: text(found, './sdg:Identifier'),
      procedure_code: text(found, './sdg:RelatedTo/sdg:Identifier').presence,
      country: text(found, './sdg:Jurisdiction/sdg:AdminUnitLevel1').presence,
      descriptions: by_language(all(found, './sdg:Title')),
      details: by_language(all(found, './sdg:Description')),
    )
  end
end
