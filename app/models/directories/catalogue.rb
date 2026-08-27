module Directories
  # Everything the Evidence Broker publishes, read in one query.
  #
  # Every parameter of the requirements query is optional (chapter 3.2.4), and
  # asked with none it answers the whole catalogue — in acceptance, 53
  # requirements carrying 687 declarations across 27 countries. That single
  # answer is what the console lists, from three angles: by procedure code, by
  # requirement, and by country.
  #
  # It is read once and held for the request being served. `CommonServicesQuery`
  # caches the body rather than what was read from it, so asking twice costs a
  # second parse of some six hundred kilobytes.
  class Catalogue
    # The only refusal a sweep goes through: the Evidence Broker refuses by this
    # code when it holds no information on a requirement. A member state that
    # knows it satisfies none says so differently — an explicitly empty list in
    # a successful answer (chapter 3.2.4) — and that one reaches the pages.
    EMPTY_RESULT_SET = 'EB:ERR:0001'.freeze

    def initialize(evidence_broker: nil)
      @evidence_broker = evidence_broker || EvidenceBrokerClient.new
    end

    def requirements = @requirements ||= @evidence_broker.requirements

    def requirement(uuid) = requirements.find { |found| found.uuid == uuid }

    def declarations = requirements.flat_map(&:reference_frameworks)

    def procedures = @procedures ||= Procedure.group(declarations)

    def procedure(code) = procedures.find { |found| found.code == code }

    def countries = declarations.filter_map { |declared| declared.country.presence }.uniq.sort

    def procedures_in(country_code) = Procedure.group(declarations_in(country_code))

    def declarations_in(country_code) = declarations.select { |declared| declared.country == country_code }

    # What a country publishes as a provider, which the Evidence Broker has no
    # query for: its own takes one requirement at a time (`EB:ERR:0002` without
    # it), so the whole catalogue is swept. The queries name no country, so the
    # page of every country reads the same cached answers.
    #
    # A requirement nobody satisfies is a result of the sweep — the directory
    # answers with an empty set — and not a refusal of the page: the next one
    # may be satisfied. Any other refusal is raised, since swallowing it would
    # drop a requirement for a reason that is not "this country publishes
    # nothing".
    #
    # Only a list carrying evidence types counts as published. A member state
    # declaring `NoMatch` (chapter 3.2.4) states the very opposite of what this
    # page announces, and counting it would put a requirement among those the
    # country satisfies — in the tally as much as in the listing. The
    # declaration is worth reading, on the page built around the requirement
    # rather than around the provider.
    def published_in(country_code)
      requirements.filter_map do |requirement|
        lists = lists_of(requirement).select { |list| list.country == country_code && list.published? }

        [requirement, lists] if lists.any?
      rescue CommonServicesError => e
        raise unless e.code == EMPTY_RESULT_SET

        nil
      end
    end

    private

    def lists_of(requirement) = @evidence_broker.evidence_type_lists(requirement_id: requirement.id)
  end
end
