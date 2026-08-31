# A conformance rule of the TDD, said as the link that lets one read it.
#
# The Schematron rather than the chapter, which carries the rule too: the wiki
# page is live and unversioned where this address is pinned to the `2.0.1` tag,
# the `.sch` is the text `scripts/validate_schematron.sh` actually runs, and the
# two have drifted on these very rules — the chapter lists `image/jpeg` twice in
# C039 and C041 where the assertion lists `image/jpeg` and `image/jpg`.
#
# The file follows from the identifier: at that tag, the set asserting a rule is
# named after it, minus the number — `DSD-RESP-C.sch` carries C039 and C041,
# `DSD-RESP-S.sch` carries S027, `EB-ERR.sch` carries `R-EB-ERR-005`. Only
# `MS-CLASS-SUB` numbers its rules with a letter without being split into a
# `-C`/`-S` pair, so there the letter belongs to the number, which no identifier
# can say on its own.
#
# No anchor on the assertion: GitLab addresses a line and not an `id`, and a
# line number kept by hand would point at a neighbouring rule the day it
# drifted, which is worse than the scroll it spares.
class TddRuleComponent < ViewComponent::Base
  SCHEMATRON_URL = 'https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/%<set>s.sch'.freeze

  UNSPLIT_SETS = %w[MS-CLASS-SUB].freeze

  def initialize(rule:)
    @rule = rule
    super()
  end

  attr_reader :rule

  def url = format(SCHEMATRON_URL, set:)

  private

  def set
    named = rule.delete_prefix('R-').sub(/-?\d+\z/, '')
    unsplit = named.sub(/-[A-Z]\z/, '')

    UNSPLIT_SETS.include?(unsplit) ? unsplit : named
  end
end
