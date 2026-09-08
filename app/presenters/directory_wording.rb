# How the pages reading the central directories word a country and a procedure.
#
# The section's controller carried these as `helper_method`s, which put the
# wording of a screen where neither a spec of the view nor a component could
# reach it. They read no `params` and no request — only the two code lists —
# so a spec hands them over directly, as `CountryWording` next door already
# asks.
#
# It holds `CountryWording` rather than extending it: that one is French
# agreeing with what the code list publishes, and knows nothing of a screen,
# where most of the methods here render a component.
#
# The two code lists are handed in rather than read: they come from an HTTP
# client the controller already holds for its own pages, and a presenter that
# fetched them would be a presenter no spec could freeze.
class DirectoryWording
  def initialize(names:, articles:, procedures: {})
    @names = names
    @procedures = procedures
    @wording = CountryWording.new(names:, articles:)
  end

  # For a heading, which cannot carry a label: a `<p>` has no business inside
  # an `<h2>`. The rule itself belongs to the component.
  def named_country(code) = CountryTagComponent.label(code, @names[code])

  # The flag alone before what a heading is about: the country is named in the
  # breadcrumb just above, and spelling it out again would say it twice on one
  # screen.
  def flagged(code, subject) = [CountryTagComponent.flag(code), subject].compact.join(' ')

  def in_country(code) = @wording.in(code)

  def named_or_code(code) = @wording.named(code)

  def declaration_summary(**) = @wording.declaration(**)

  # The wording of a procedure code, which the directory does not publish: it
  # returns the code alone, and the wording lives in the code list.
  def named_procedure(code) = ProcedureComponent.label(code, @procedures[code])

  def procedure_hint(code) = ProcedureComponent.hint(@procedures[code])

  # Where a heading has the room the listings do not.
  def full_named_procedure(code) = ProcedureComponent.label(code, @procedures[code], limit: nil)
end
