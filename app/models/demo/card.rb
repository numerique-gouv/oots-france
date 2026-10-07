module Demo
  # One card of the documents page, as a journey last saw it: the member state
  # it stands in, and what it named there — what its button sends.
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
  # half fills. Nothing in it identifies the user.
  class Card < ApplicationRecord
    self.table_name = 'demo_cards'

    NAMES = Demo::NamedEvidence.attribute_names.map(&:to_sym).freeze

    # Upserted on the pair the table holds unique: two choices landing on the
    # same card in the same instant leave one row, the last written, where an
    # insert would fail on the index. `upsert` runs no validation, and this
    # model declares none: the table's `null: false` are what is checked.
    def self.remember(journey_id:, requirement_uuid:, named_evidence:)
      upsert(named_evidence.attributes.symbolize_keys.merge(journey_id:, requirement_uuid:), # rubocop:disable Rails/SkipsModelValidations
        unique_by: %i[journey_id requirement_uuid], update_only: NAMES)
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

    def named_evidence = Demo::NamedEvidence.new(slice(*NAMES))

    # The requirement as the row keeps it, which is what an added card is
    # resolved from: no first query lists it, and the second takes nothing more
    # than its identifier.
    def requirement
      Requirement.new(id: requirement_id,
        descriptions: requirement_language.present? ? { requirement_language => requirement_name } : {})
    end
  end
end
