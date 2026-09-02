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

    # What a country publishes as a provider.
    def published_in(country_code)
      requirements.filter_map do |requirement|
        published = lists_of(requirement).select { |list| list.country == country_code }

        [requirement, published] if published.any?
      end
    end

    # The other way round: the countries publishing for one requirement. Sorted
    # here rather than in the page, a listing of jurisdictions having no order
    # of its own to read.
    def publishing_countries(requirement)
      lists_of(requirement).filter_map { |list| list.country.presence }.uniq.sort
    end

    private

    # What the Evidence Broker holds on each requirement, swept once and held
    # for the request being served: the console asks it two opposite questions
    # — what a country publishes, and who publishes for a requirement — and
    # neither can be put to the directory for the catalogue at once. Its query
    # answers one requirement at a time, `requirement-id` being the only
    # mandatory parameter of chapter 3.2.4, and no query of the Evidence Broker
    # starts from a country at all. The queries name no country, so every page
    # reads the same cached answers.
    #
    # Keyed by identifier and not by the requirement: `Requirement` carries no
    # value equality, so an object key would answer nothing for an instance
    # built anywhere else, exactly as `requirement(uuid)` and `procedure(code)`
    # address theirs by what names them.
    #
    # Only lists carrying evidence types are kept. A member state declaring
    # `NoMatch` (chapter 3.2.4) states the very opposite of what both questions
    # ask, and counting it would put a requirement among those a country
    # satisfies — in a tally as much as in a listing. The declaration is worth
    # reading, on the page built around the requirement rather than around the
    # provider.
    def published_lists
      @published_lists ||= requirements.to_h { |requirement| [requirement.id, swept(requirement)] }
    end

    def lists_of(requirement) = published_lists.fetch(requirement.id, [])

    # A requirement nobody satisfies is a result of the sweep — `EB:ERR:0001`
    # is « the result set is empty » — and not a refusal of the page: the next
    # one may be satisfied. Any other refusal is raised, since swallowing it
    # would drop a requirement for a reason that is not "nobody publishes for
    # it", and raised naming the requirement it fell on: fifty-three questions
    # were asked, and the page would otherwise report the refusal of none in
    # particular.
    def swept(requirement)
      @evidence_broker.evidence_type_lists(requirement_id: requirement.id).select(&:published?)
    rescue CommonServicesError => e
      return [] if e.code == EMPTY_RESULT_SET

      raise CommonServicesError.new(
        I18n.t('models.directories.catalogue.swept', requirement: requirement.uuid, error: e.message),
        code: e.code,
      )
    end
  end
end
