# The requirements a procedure imposes, as the Evidence Broker returns them
# (chapter 3.2.4).
#
# Only their identifiers are read, because only they are used: an identifier is
# what the second query takes. The name a requirement carries would belong to
# the `Requirements` slot of an outgoing request, which is stub 7 of
# `docs/reste_à_faire.md` and still written from a constant.
class RequirementsResponseParser < CommonServicesResponseParser
  def requirement_identifiers = @read

  private

  def read = records(REQUIREMENT).map { |declared| identifier(declared) }

  # Without it the second query would go out with an empty `requirement-id`,
  # and what came back would depend on how tolerant the directory happens to be.
  def identifier(declared)
    found = text_at(declared, './sdg:Identifier')&.strip
    raise CommonServicesError, "L'annuaire a rendu une exigence sans identifiant." if found.blank?

    found
  end
end
