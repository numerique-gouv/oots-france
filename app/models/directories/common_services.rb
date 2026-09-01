module Directories
  # The central directories the TDD define — the Evidence Broker, which maps a
  # procedure to the evidence types that satisfy it (chapter 3.2.4), and the
  # Data Service Directory, which maps an evidence type and a country to the
  # providers holding it (chapter 3.1.4). The Semantic Repository is consulted
  # when designing, not here.
  #
  # This is where a refusal becomes an exception the interactors already know:
  # both services answer 200 with a named code, and only a handful of those
  # codes mean "the caller asked for something that does not exist" rather than
  # "the directory is unwell".
  class CommonServices
    UNKNOWN_PROCEDURE = %w[EB:ERR:0001 EB:ERR:0005 EB:ERR:0006].freeze
    NO_PROVIDER = %w[DSD:ERR:0001 DSD:ERR:0002].freeze

    # The two refusals the second Evidence Broker query answers with, kept apart
    # because only one of them says anything about the country asked.
    # `EB:ERR:0001` — « The result set is empty » — is the directory holding no
    # information about this requirement there, and is the one a caller may hold
    # back. `EB:ERR:0002` answers a query that named no requirement: a fault of
    # ours, never a fact about a country, so it stays loud however many other
    # requirements publish. `Directories::Catalogue#published_in` draws the same
    # line for the same reason.
    NO_EVIDENCE_INFORMATION = %w[EB:ERR:0001].freeze
    MALFORMED_EVIDENCE_QUERY = %w[EB:ERR:0002].freeze

    # What a request needs to name what it asks for: the requirement it has to
    # declare (R-EDM-REQ-S011), and the evidence types that satisfy it.
    RequiredEvidence = Data.define(:requirement, :evidence_types) do
      # Whether the country asked answers this requirement with anything at all,
      # in the terms `EvidenceTypeList#published?` already uses of a single list.
      #
      # It does not say why an entry is empty, and cannot: a country declaring
      # `NoMatch` and a directory refusing the query both land here as no types.
      # Where the two must be told apart — nothing published for the procedure
      # at all — the refusal is raised instead of being returned, so a caller
      # never has to read it off this. Carrying the reason on each entry is
      # OOTS-54, which needs the lists themselves.
      def published? = evidence_types.any?
    end

    def initialize(evidence_broker: nil, data_service_directory: nil)
      @evidence_broker = evidence_broker || EvidenceBrokerClient.new
      @data_service_directory = data_service_directory || DataServiceDirectoryClient.new
    end

    # Two queries, and they do not take the same country: a procedure is ours,
    # so its requirements are read in our own jurisdiction, where the evidence
    # types that meet them are read in the country being asked.
    #
    # Every requirement of the procedure, and not the first: they are
    # conjunctive — « Each procedure has one or more specific requirements that
    # need to be fulfilled by the User that executes the procedure » (chapter
    # 3.2.3) — so one dropped is a piece of evidence that will be missing. The
    # second query takes `requirement-id` as MANDATORY (chapter 3.2.4), which is
    # why n requirements cost n calls and no batching is on offer.
    #
    # A requirement the directory holds nothing for is kept, empty: it is still
    # one the procedure rests on, and the count of them is what chapter 4.4
    # multiplies the conversation timeout by. Its refusal is held back and
    # becomes the answer only if no requirement published anything — the country
    # is asked about each requirement separately, so its silence about one is no
    # verdict on the others.
    #
    # The requirement comes back alongside the types because a request writes it
    # into its `Requirements` slot (R-EDM-REQ-S011): asking the Evidence Broker
    # again for it would be a second round trip for a value already in hand.
    def required_evidence_for_procedure(procedure_code, country_code)
      deferred = nil
      found = requirements(procedure_code)

      resolved = refusing(MALFORMED_EVIDENCE_QUERY, procedure_code, country_code) do
        found.map do |requirement|
          types = types_satisfying(requirement, procedure_code, country_code) { |held| deferred ||= held }

          RequiredEvidence.new(requirement:, evidence_types: types)
        end
      end

      raise deferred if deferred && resolved.none?(&:published?)

      resolved
    end

    # One service and not the providers it publishes: chapter 4.5.1 has a
    # request adopt this record into its `DataServiceEvidenceType`, identifier
    # and distribution included — things a provider on its own does not carry.
    #
    # The first that names a provider, rather than simply the first: a record
    # published without `sdg:AccessService` breaks R-DSD-RESP-S014, and writing
    # its identifier would pair it with a provider another record announced.
    def data_service(evidence_type_id, country_code)
      published = translating(NO_PROVIDER, CountryCodeNotFound,
        'models.directories.common_services.no_provider',
        evidence_type: evidence_type_id, country: country_code) do
        @data_service_directory.data_services(
          evidence_type_classification: evidence_type_id,
          country_code:,
        )
      end

      vetted(published.find { |service| service.providers.any? }, :announced_data_service)
    end

    private

    # Vetted here rather than when the directory was read: what this façade
    # hands back goes into a message, where the console lists what a directory
    # publishes as it publishes it — and the console does not come through here
    # (see `DirectoryLookup::Resolve`).
    def vetted(published, subject) = published&.validate!(subject, error: InvalidDirectoryEntry)

    # Every requirement is validated, not merely the one an exchange ends up
    # carrying: an identifier R-EDM-REQ-C008 refuses says the same thing about
    # the directory wherever it sits in the answer, and passing over it would
    # hide that until a correspondent rejected the message.
    def requirements(procedure_code)
      found = translating(UNKNOWN_PROCEDURE, ProcedureCodeNotFound,
        'models.directories.common_services.unknown_procedure', procedure: procedure_code) do
        @evidence_broker.requirements(
          procedure_code:, country_code: Settings.common_services_country_code,
        )
      end

      raise ProcedureCodeNotFound, "#{unknown_procedure(procedure_code)}." if found.empty?

      found.map { |requirement| vetted(requirement, :announced_requirement) }
    end

    # What the country publishes for this requirement, or nothing and the
    # refusal handed to the block for its caller to hold back. Only
    # `NO_EVIDENCE_INFORMATION` is caught here; every other refusal travels on
    # untranslated, for the envelope around the whole loop to raise on the spot.
    def types_satisfying(requirement, procedure_code, country_code)
      refusing(NO_EVIDENCE_INFORMATION, procedure_code, country_code) do
        @evidence_broker.evidence_types(requirement_id: requirement.id, country_code:)
      end
    rescue EvidenceTypeNotFound => e
      yield e
      []
    end

    # A refusal of the second query, said as the exception the interactors know.
    def refusing(codes, procedure_code, country_code, &)
      translating(codes, EvidenceTypeNotFound,
        'models.directories.common_services.no_evidence_type',
        procedure: procedure_code, country: country_code, &)
    end

    def unknown_procedure(code)
      I18n.t('models.directories.common_services.unknown_procedure', procedure: code)
    end

    # The wording travels as a key, and is built only once a refusal has to be
    # said: a message composed on the way in would be composed on every read
    # that succeeds, which is nearly all of them.
    def translating(codes, error, key, **interpolations)
      yield
    rescue CommonServicesError => e
      raise unless codes.include?(e.code)

      raise error, "#{I18n.t(key, **interpolations)} : #{e.message}."
    end
  end
end
