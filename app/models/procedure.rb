# An SDG procedure code, and everything the Evidence Broker says under it.
#
# The directory publishes no procedure as such: what it holds are the
# declarations member states make — `ReferenceFramework` —, each naming the
# code it maps onto. A procedure is the grouping of those declarations, and is
# therefore built rather than read.
#
# The code is the only part of any of this a request carries, in its
# `codeDemarche`.
class Procedure
  attr_reader :code, :declarations

  # Sorted on the letters and the number apart, so that `X10` follows `X9`
  # rather than `X1`. A declaration published without a code is left out: it
  # belongs to no procedure, and a heading with no name is worse than a line
  # missing from a listing.
  #
  # Blank rather than nil: this holds whatever the caller built its declarations
  # from, and a procedure named « » would reach the path helper, which refuses
  # it.
  def self.group(declarations)
    declarations.group_by(&:procedure_code)
      .reject { |code, _| code.blank? }
      .sort_by { |code, _| [code.sub(/\d+\z/, ''), code[/\d+\z/].to_i] }
      .map { |code, declared| new(code:, declarations: declared) }
  end

  def initialize(code:, declarations:)
    @code = code
    @declarations = declarations
  end

  # A declaration published without its jurisdiction belongs to no country, so
  # listing it would show one entry more than `#countries` announces. Both read
  # the same grouping rather than each applying the rule for itself.
  def declarations_by_country
    declarations.select { |declared| declared.country.present? }.group_by(&:country).sort.to_h
  end

  def countries = declarations_by_country.keys

  def requirements = declarations.filter_map(&:requirement).uniq(&:id)

  # Grouped by requirement and not by declaration: a country files several
  # declarations resting on the same one, and a requirement count is what the
  # pages leading here announce.
  def declared_requirements(country)
    declarations.select { |one| one.country == country }.group_by { |one| one.requirement&.id }
  end
end
