module DirectoryLookup
  # One resolution per requirement a procedure rests on — what a page offering a
  # card per requirement needs, and what `ResolveCombination` on its own cannot
  # say: how many runs there are is only known once the requirements are read,
  # so this sequence is written out instead of being declared with `organize`.
  #
  # The requirements are read once, and each run starts from the one it is
  # handed: chapter 3.2.4 §4.3 bases the second query of the Evidence Broker
  # « on a requirement that is known to the Procedure Portal or that is
  # determined via the Evidence Broker's first query ».
  #
  # Each requirement is resolved in its own country, `countries` naming it by
  # UUID and `country_code` standing for any it does not name: a portal asks
  # the user which member state each evidence is to come from (step 16 of
  # chapter 1 §10.1), and chapter 3.2.4 §4.3 has the second query « reflect the
  # country and jurisdiction of the Evidence Provider ».
  #
  # Each card offers the user the combinations its country publishes — chapter
  # 3.2.2 §2.3 — and `evidence_type_lists` names by requirement UUID the one the
  # user chose on it. `provider_classifications` names by requirement UUID, then
  # by evidence type UUID, the user's answers to the questions the Data Service
  # Directory asked on it, which `FetchProviders` asks it again with.
  #
  # A refusal stays where it fell, on the resolution it belongs to: chapter 4.4
  # §4.2.2 has « different basic flows … executed sequentially and/or in
  # parallel », so no card waits on its neighbour, and a Data Service Directory
  # refusing one requirement leaves the others on screen. An outage carries no
  # code, and `Refusing` raises it past this object whole.
  class ResolveAll < ApplicationOrganizer
    def call
      context.requirements = Array(FetchRequirements.call(evidence_broker:, procedure_code: context.procedure_code).requirements)
      context.resolutions = context.requirements.map { |requirement| resolve(requirement) }
    end

    private

    def resolve(requirement)
      uuid = requirement.uuid

      ResolveCombination.call(evidence_broker:, data_service_directory:, requirement:, country_code: country_of(uuid),
        evidence_type_list_id: context.evidence_type_lists.to_h[uuid], provider_classifications: answers_of(uuid))
    end

    def country_of(uuid) = context.countries.to_h.fetch(uuid, context.country_code)

    def answers_of(uuid) = context.provider_classifications.to_h.fetch(uuid, {})

    # The directories this sequence gives itself when its caller names none, in
    # the form `ApplicationInteractor` already uses for the gateway: a caller
    # passes only what varies, and a spec still overrides by keyword.
    def evidence_broker = context.evidence_broker ||= EvidenceBrokerClient.new

    def data_service_directory = context.data_service_directory ||= DataServiceDirectoryClient.new
  end
end
