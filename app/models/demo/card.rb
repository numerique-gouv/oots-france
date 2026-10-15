module Demo
  # One card of the documents page, as a journey last saw it: the member state
  # it stands in, the combination it chose there, and what it named for each of
  # its evidence types — what its buttons send.
  #
  # Requirement 27 of chapter 1 §2 — « The user is provided with information
  # about name of evidence provider and evidence type for confirmation, before
  # any request is made » — so the click reads back what the card showed rather
  # than resolving it anew. One row per card, never one per page: chapter 4.4
  # §4.2.2 has « different basic flows … executed sequentially and/or in
  # parallel », and a card never writes over its neighbour.
  #
  # Chapter 1 §4.2 leaves « Procedure and session state management » to the
  # portal without saying where; here it is a table rather than the session,
  # which the cookie store bounds at four kibibytes and the identity already
  # half fills. Nothing in it names the user; the answers to the questions of the
  # Data Service Directory may describe them, and are kept in clear like the
  # identities and the documents of the demonstration, all fabricated.
  class Card < ApplicationRecord
    self.table_name = 'demo_cards'

    # What a card names whatever its lines name, and what each line names: one
    # line per evidence type of its combination, each what one request sends.
    CARD_NAMES = %i[requirement_id requirement_name requirement_language country_code evidence_type_list_id].freeze
    LINE_NAMES = (Demo::NamedEvidence.attribute_names - CARD_NAMES.map(&:to_s)).freeze

    # Upserted on the pair the table holds unique: two choices landing on the
    # same card in the same instant leave one row, the last written, where an
    # insert would fail on the index. `upsert` runs no validation, and this
    # model declares none: the table's `null: false` are what is checked.
    #
    # `card` holds the `CARD_NAMES`, and `lines` one `Demo::NamedEvidence` per
    # evidence type. A click on « Request the documents » made for another
    # combination than the one now named says nothing of this one.
    def self.remember(journey_id:, requirement_uuid:, card:, lines:)
      upsert(card.slice(*CARD_NAMES).merge(journey_id:, requirement_uuid:, evidence_types: lines.map { |line| line.attributes.slice(*LINE_NAMES) }), # rubocop:disable Rails/SkipsModelValidations
        unique_by: %i[journey_id requirement_uuid], update_only: [*CARD_NAMES, :evidence_types])
      where(journey_id:, requirement_uuid:).where('requested_evidence_type_list_id IS DISTINCT FROM evidence_type_list_id')
        .update_all(requested_evidence_type_list_id: nil) # rubocop:disable Rails/SkipsModelValidations
    end

    # The click on « Request the documents », kept for the combination the card
    # names: a refusal of the contract opens no exchange, and the zone would
    # otherwise forget, at the next reload, that its types are now asked for one
    # by one.
    def self.request_the_combination(journey_id:, requirement_uuid:)
      where(journey_id:, requirement_uuid:).update_all('requested_evidence_type_list_id = evidence_type_list_id') # rubocop:disable Rails/SkipsModelValidations
    end

    # A card the operator added to the page, beyond those the Evidence Broker
    # lists for the procedure: it carries its requirement, which is all its
    # resolution starts from, and stands in the country given — the one its
    # last request went to, when it had one. Named in the first of `languages`
    # the directory publishes. Inserted rather than upserted: the page offers no
    # requirement it already carries, and the unique index settles two additions
    # racing each other.
    def self.add(journey_id:, requirement:, country_code:, languages:)
      create!(journey_id:, requirement_uuid: requirement.uuid, requirement_id: requirement.id,
        requirement_name: requirement.label(languages:), requirement_language: requirement.label_language(languages:),
        country_code:, added_at: Time.current)
    end

    # The added cards of the journey, in the order they were added.
    def self.added(journey_id) = where(journey_id:).where.not(added_at: nil).order(:added_at, :id)

    def self.forget(journey_id) = where(journey_id:).delete_all

    # The member state each card of the journey stands in, by requirement.
    def self.countries(journey_id) = where(journey_id:).pluck(:requirement_uuid, :country_code).to_h

    # The combination each card of the journey names, by requirement, where it
    # names one.
    def self.evidence_type_lists(journey_id)
      where(journey_id:).where.not(evidence_type_list_id: nil).pluck(:requirement_uuid, :evidence_type_list_id).to_h
    end

    # The answers each card of the journey was resolved on, by requirement and
    # then by evidence type UUID, where it was asked something.
    def self.provider_classifications(journey_id)
      where(journey_id:).to_h { |card| [card.requirement_uuid, card.provider_classifications] }.compact_blank
    end

    def named_evidences
      evidence_types.map { |line| Demo::NamedEvidence.new(slice(*CARD_NAMES).merge(line.slice(*LINE_NAMES))) }
    end

    def provider_classifications
      named_evidences.to_h { |named| [named.evidence_type_uuid, named.provider_classifications] }.compact_blank
    end

    def requested? = requested_evidence_type_list_id.present? && requested_evidence_type_list_id == evidence_type_list_id

    # The requirement as the row keeps it, which is what an added card is
    # resolved from: no first query lists it, and the second takes nothing more
    # than its identifier.
    def requirement
      Requirement.new(id: requirement_id,
        descriptions: requirement_language.present? ? { requirement_language => requirement_name } : {})
    end
  end
end
