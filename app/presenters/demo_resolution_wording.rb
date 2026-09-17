# What the documents page of the demonstration says of one requirement of the
# procedure: what it is, who would provide the evidence satisfying it, and of
# which type.
#
# Requirement 27 of chapter 1 §2 asks for exactly those two, and for them
# « before any request is made » — hence a page of its own, and hence
# `nameable?`, which the page reads to decide whether it may offer to confirm at
# all: unable to name them, it must not let the request leave.
#
# The values are shown as the directories publish them, in the language they
# publish them in: substituting a wording of our own would make the
# demonstration show something no exchange rests on.
class DemoResolutionWording
  # English first, where the console reads French first: these pages are the
  # portal, and their reader is a user of another Member State.
  LANGUAGES = %w[EN FR].freeze

  def initialize(lookup)
    @lookup = lookup
  end

  def provider = provider_entry&.label(languages: LANGUAGES).presence

  # The language of each value, where the directory published one: a wording in
  # another language than the sentence around it carries its own `lang`, failing
  # which a screen reader pronounces French as English (RGAA 8.7). Nothing when
  # the value itself is nothing.
  def provider_language
    provider_entry&.label_language(languages: LANGUAGES) if provider.present?
  end

  def evidence_type = lookup.evidence_type&.label(languages: LANGUAGES).presence

  def evidence_type_language
    lookup.evidence_type&.label_language(languages: LANGUAGES) if evidence_type.present?
  end

  # What the procedure has to satisfy, which is what a card stands under. Read
  # whatever the steps below answered: a requirement no country serves is still
  # one the procedure rests on, and the card says so rather than disappearing.
  #
  # The evidence type is what satisfies it, and requirement 27 has it named too,
  # so a requirement the directory named in no language falls back on it rather
  # than leaving the card headless.
  def requirement = requirement_label.presence || evidence_type

  # The language of what the card actually stands under, fallback included: a
  # `lang` that described the requirement while the evidence type is shown would
  # be worse than none.
  def requirement_language
    return evidence_type_language if requirement_label.blank?

    lookup.requirement.label_language(languages: LANGUAGES)
  end

  def nameable? = provider.present? && evidence_type.present?

  # The requirement as the Evidence Broker names it, where `requirement` above
  # is what the card stands under. The identifier is what goes out in
  # `idExigence` — a caller has no business cutting a URL up — and the UUID is
  # what the console and `DirectoryLookup` already pass between themselves, so
  # it is what the page's own addresses carry.
  def requirement_id = lookup.requirement&.id

  def requirement_uuid = lookup.requirement&.uuid

  # The refusal of whichever step stopped the chain, in the shape the console's
  # other directory pages already render.
  def failure
    lookup.error if lookup.failure?
  end

  # What « nobody publishes this here » looks like. Chapter 3.2.4 has a directory
  # with nothing to give refuse rather than answer empty, so the usual shape is
  # the refusal the two central directories reserve for it — the one
  # `CommonServicesError#nothing_published?` recognises, which `DirectoryLookup`
  # puts on the failure it hands back. The other shape is a list that came back
  # empty, which the steps name themselves.
  #
  # Any other refusal is a directory declining to answer, and saying « no
  # provider » of it would state as settled something nobody established.
  PUBLISHES_NOTHING = %i[no_evidence_type no_provider].freeze

  def published_nothing?
    PUBLISHES_NOTHING.include?(failure&.dig(:key)) || failure&.dig(:nothing_published).present?
  end

  private

  attr_reader :lookup

  def requirement_label
    return @requirement_label if defined?(@requirement_label)

    @requirement_label = lookup.requirement&.label(languages: LANGUAGES)
  end

  # `sdg:Publisher` names the organisation, which is what requirement 27 calls
  # the evidence provider; `sdg:AccessService` names the gateway carrying the
  # message to it, and is not a name for a user to read.
  #
  # A step that never ran leaves nothing on the context, and a step that ran and
  # failed leaves what it found: both are read here as « nothing to name ».
  def provider_entry = Array(lookup.data_services).first&.providers&.first
end
