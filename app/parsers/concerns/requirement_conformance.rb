# What chapter 4.6 asks of the `Requirements` slot of a received request: that
# the slot is there, that each element of its collection carries a requirement,
# that each identifier is a Semantic Repository URL, and that each wording names
# a language of the code list.
#
# Apart from the parser, as `AgentConformance` is: `EvidenceRequestParser` would
# otherwise carry the rules of four slots at once, and does not fit — the class
# tripped `Metrics/ClassLength` the day the `EvidenceProvider` rules landed
# beside these.
#
# `AgentConformance` is included for one method, `require_language`: four pairs
# of rules make its two assertions, and two of them judge the wordings below,
# which are not agents. It is declared here rather than left to the parser, in
# which both modules happen to meet — that coincidence would resolve the call
# just as well, and would break silently the day this module is included
# anywhere else.
#
# Refusals go through `refuse`, which the parser including this defines.
module RequirementConformance
  include OotsNamespaces
  include AgentConformance

  # `R-EDM-REQ-C008`, copied from the Schematron dot for dot. Its assertion
  # escapes the point of the optional midfix and no other, so every remaining
  # `.` matches any character at all and `https://sr-oots.tech.ec.europa.eu/…`
  # satisfies the rule. `Requirement::IDENTIFIER` escapes them, deliberately:
  # it governs what France sends, where this governs what France may refuse,
  # and refusing what a FATAL rule admits is the failure this reader exists to
  # avoid.
  #
  # Lower-case hexadecimal, the assertion carrying no `i` flag, and anchored on
  # the whole string: `matches()` without `m` reads `^` and `$` as its ends,
  # which in Ruby are `\A` and `\z`.
  REQUIREMENT_IDENTIFIER = %r{\Ahttps://sr(?:\.[a-zA-Z]+)?.oots.tech.ec.europa.eu/requirements/
                              [a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z}x

  # The wordings a requirement carries, each under the row of
  # `AgentConformance::RULES` that names the two rules judging its language —
  # `R-EDM-REQ-C010`/`C009` for the name, `C094`/`C093` for the description.
  # One row per element rather than two twin methods: the same pair of
  # assertions judges both, and only the identifiers and the French sentence
  # differ.
  REQUIREMENT_WORDINGS = { 'Name' => :requirement_name, 'Description' => :requirement_description }.freeze

  private

  # Every requirement the slot carries, and no count of them: `R-EDM-REQ-S011`
  # numbers the slot, and nothing numbers its elements, so a request naming
  # three obligations is as conformant as one naming a single one.
  #
  # `R-EDM-REQ-S037` is the one thing each element owes, and it is refused here
  # rather than passed over: its context is the `rim:Element`, which exists —
  # it came out of the collection — so the assertion does fire on it, unlike
  # `C008`, whose own context node is missing when there is no identifier to
  # judge. An element carrying no `sdg:Requirement` is therefore a request the
  # rule refuses, not a nothing there is nothing to say about.
  #
  # Reached only once the slot is known to be there, `validate!` running the
  # `REQUIRED_SLOTS` loop first — `slot_elements` raises on an absent slot
  # under a sentence that names no rule, where `S011` is what refuses it.
  def require_conformant_requirements
    slot_elements('Requirements', request).each do |element|
      required = all(element, './sdg:Requirement')
      refuse('R-EDM-REQ-S037', 'parsers.evidence_request.element_without_requirement') if required.empty?

      required.each do |requirement|
        require_requirement_identifier(requirement)
        require_requirement_wordings(requirement)
      end
    end
  end

  # Each `sdg:Identifier` that is there, and silence on a requirement carrying
  # none: the context of `R-EDM-REQ-C008` is the identifier itself, so its
  # absence triggers no assertion — the shape `require_agent_country` and
  # `require_beneficiary_identifier_scheme` take for the same reason.
  #
  # `squish` is `normalize-space`, which the assertion applies before matching.
  def require_requirement_identifier(requirement)
    all(requirement, './sdg:Identifier').each do |identifier|
      id = identifier.text.squish
      next if id.match?(REQUIREMENT_IDENTIFIER)

      refuse('R-EDM-REQ-C008', 'parsers.evidence_request.requirement_id_unexpected',
        id: id.presence || I18n.t('parsers.evidence_request.unnamed_requirement_id'))
    end
  end

  # Every wording of every kind, and not the first alone: `RequirementType`
  # makes `sdg:Name` `1..n` and `sdg:Description` `0..n`, and each of them is
  # judged on its own — `C010` and `C094` on the element, `C009` and `C093` on
  # its `lang`, which is the attribute node their contexts name.
  def require_requirement_wordings(requirement)
    REQUIREMENT_WORDINGS.each do |element_name, wording|
      all(requirement, "./sdg:#{element_name}").each { |element| require_language(element, wording) }
    end
  end
end
