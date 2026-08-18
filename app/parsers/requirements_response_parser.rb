# The requirements a procedure imposes, as the Evidence Broker returns them
# (chapter 3.2.4).
#
# Every parameter of that query is optional, so the same answer is either the
# requirements of one procedure in one jurisdiction, or — asked with nothing —
# the whole catalogue the Evidence Broker holds. `Directories::Catalogue` reads
# it the second way; `EvidenceRequest::Fetch` reads it the first, and takes
# only the identifiers, an identifier being what the second query needs.
class RequirementsResponseParser < CommonServicesResponseParser
  def requirement_identifiers = @read

  attr_reader :requirements

  private

  # The identifiers are what `@read` holds, so that an answer whose records
  # carry none is still rejected as unreadable — the guarantee the base class
  # states, unchanged by the rest being read alongside.
  def read
    @requirements = records(REQUIREMENT).map { |declared| build(declared) }
    @requirements.map(&:id)
  end

  def build(declared)
    Requirement.new(
      id: identifier(declared),
      descriptions: by_language(all(declared, './sdg:Name')),
      details: by_language(all(declared, './sdg:Description')),
      reference_frameworks: all(declared, './sdg:ReferenceFramework').map { |found| framework(found) },
    )
  end

  # Without it the second query would go out with an empty `requirement-id`,
  # and what came back would depend on how tolerant the directory happens to be.
  def identifier(declared)
    found = text(declared, './sdg:Identifier')
    raise CommonServicesError, I18n.t('parsers.requirements_response.requirement_without_id') if found.blank?

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
