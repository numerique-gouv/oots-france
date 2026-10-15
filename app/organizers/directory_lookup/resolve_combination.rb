module DirectoryLookup
  # The chain `Resolve` walks, for every evidence type of the combination the
  # user chose: chapter 3.2.2 §2.3 — « at least one Evidence for each Evidence
  # Type specified in one Evidence Type List MUST be provided » — so a card
  # names a provider for each, and `lines` holds one resolution per type, in
  # the order of the list.
  #
  # The Data Service Directory is asked once per type: chapter 3.1.4 §4.4.3.3
  # has `evidence-type-classification` once per query, so the questions of a
  # `DSD:ERR:0005` are a type's and not the combination's, and
  # `provider_classifications` names the answers by evidence type UUID. A line
  # refused leaves its neighbours standing, each holding its own failure.
  #
  # Starts from a `requirement` the caller holds — chapter 3.2.4 §4.3 bases the
  # second query of the Evidence Broker « on a requirement that is known to the
  # Procedure Portal or that is determined via the Evidence Broker's first
  # query » — and from the procedure otherwise, as `Resolve` does. A step that
  # fails before the types are known stops the chain, with no line, and is the
  # failure of this context.
  class ResolveCombination < ApplicationOrganizer
    def call
      context.lines = []
      choose_combination

      context.lines = context.evidence_type_list.evidence_types.map { |type| resolve_line(type) }
    end

    private

    def choose_combination
      context.alternatives_offered = true

      FetchRequirements.call!(context) unless context.requirement
      FetchEvidenceTypes.call!(context)
    end

    def resolve_line(type)
      FetchProviders.call(context.to_h.except(:lines, :provider_classifications)
        .merge(evidence_type: type, provider_classification_answers: context.provider_classifications.to_h.fetch(type.uuid, {})))
    end
  end
end
