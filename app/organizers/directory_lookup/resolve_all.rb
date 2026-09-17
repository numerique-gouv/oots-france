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
        requirement.uuid == leading.requirement&.uuid ? leading : resolve(requirement.uuid)
      end
    end

    private

    def resolve(requirement_id = nil)
      Resolve.call(evidence_broker:, data_service_directory:,
        procedure_code: context.procedure_code, country_code: context.country_code, requirement_id:)
    end

    # The directories this sequence gives itself when its caller names none, in
    # the form `ApplicationInteractor` already uses for the gateway: a caller
    # passes only what varies, and a spec still overrides by keyword.
    def evidence_broker = context.evidence_broker ||= EvidenceBrokerClient.new

    def data_service_directory = context.data_service_directory ||= DataServiceDirectoryClient.new
  end
end
