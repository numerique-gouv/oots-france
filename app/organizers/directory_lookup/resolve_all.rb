module DirectoryLookup
  # One resolution per requirement a procedure rests on — what a page offering a
  # card per requirement needs, and what `Resolve` on its own cannot say: how
  # many runs there are is only known once the first has answered, so this
  # sequence is written out instead of being declared with `organize`.
  #
  # The first requirement is the one that first run already walked — its own
  # opening step read the whole list — and the others are asked for by
  # identifier, which is what the console's resolution page does. The Evidence
  # Broker answer they share is cached, so each costs the two queries below it
  # and no more.
  #
  # Each requirement is resolved in its own country, `countries` naming it by
  # UUID and `country_code` standing for any it does not name: a portal asks
  # the user which member state each evidence is to come from (step 16 of
  # chapter 1 §10.1), and chapter 3.2.4 §4.3 has the second query « reflect the
  # country and jurisdiction of the Evidence Provider ». The first run is
  # reused only for its own requirement in its own country.
  #
  # A refusal stays where it fell, on the resolution it belongs to: chapter 4.4
  # §4.2.2 has « different basic flows … executed sequentially and/or in
  # parallel », so no card waits on its neighbour, and a Data Service Directory
  # refusing one requirement leaves the others on screen. An outage carries no
  # code, and `Refusing` raises it past this object whole.
  class ResolveAll < ApplicationOrganizer
    def call
      leading = resolve
      context.requirements = Array(leading.requirements)
      context.resolutions = context.requirements.map do |requirement|
        country_code = country_of(requirement.uuid)

        reusable?(leading, requirement, country_code) ? leading : resolve(requirement.uuid, country_code)
      end
    end

    private

    def resolve(requirement_id = nil, country_code = context.country_code)
      Resolve.call(evidence_broker:, data_service_directory:,
        procedure_code: context.procedure_code, country_code:, requirement_id:)
    end

    def reusable?(leading, requirement, country_code)
      requirement.uuid == leading.requirement&.uuid && country_code == context.country_code
    end

    def country_of(uuid) = context.countries.to_h.fetch(uuid, context.country_code)

    # The directories this sequence gives itself when its caller names none, in
    # the form `ApplicationInteractor` already uses for the gateway: a caller
    # passes only what varies, and a spec still overrides by keyword.
    def evidence_broker = context.evidence_broker ||= EvidenceBrokerClient.new

    def data_service_directory = context.data_service_directory ||= DataServiceDirectoryClient.new
  end
end
