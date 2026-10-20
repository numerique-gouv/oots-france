# The two names requirement 27 of chapter 1 §2 has the documents page show
# « before any request is made », and the title that page stands under, kept from
# the page to the click that follows.
#
# One concern for both, because the two addresses are two halves of one
# gesture: the documents page writes them and `RequestsController` reads them
# back, and a correspondence spread over two files holds only as long as both are
# read together. Reading them back rather than resolving them again keeps three
# directory queries off an address made to be asked over and over — and chapter
# 4.5.1 §2.3 leaves the `IssueDateTime` no material distance from the click.
#
# The title is one per page and stays in the session. What each card names is
# one row of `Demo::Card` per card, under the journey, with a line per evidence
# type of its combination: the session is a cookie bounded at four kibibytes,
# and a second card named in it would overflow it.
module HoldsDemoNames
  extend ActiveSupport::Concern

  # The cards are filed under the journey, which comes from there.
  include HoldsDemoJourney

  private

  # One row per card the page renders, nameable or not: the country it stands
  # in is kept either way, and a line that names nothing holds an invalid
  # `Demo::NamedEvidence`, which the click refuses to leave on.
  def remember_demo_names(procedure, wordings)
    session[:demo_procedure] = named_procedure_of(procedure).to_session
    wordings.each { |wording| remember_demo_name(wording) }
  end

  # One card resolved in a country: what it names now is what its buttons will
  # send, and its neighbours keep theirs.
  def remember_demo_name(wording)
    ::Demo::Card.remember(journey_id: journey.id, requirement_uuid: wording.requirement_uuid,
      card: card_names_of(wording), lines: wording.lines.map { |line| named_evidence_of(wording, line) })
  end

  def demo_card(requirement_uuid) = ::Demo::Card.find_by(journey_id: journey.id, requirement_uuid:)

  # What the card of this requirement named, a line per evidence type, and
  # nothing of its neighbours'. The requirement is passed rather than read off
  # whoever includes this, as `ReadsDemoRequest` passes it too: a page carries
  # one zone per requirement, and each answers for its own. A card the page
  # never rendered names nothing.
  def named_evidences(requirement_uuid) = demo_card(requirement_uuid)&.named_evidences.to_a

  def named_procedure = ::Demo::NamedProcedure.from_session(session[:demo_procedure])

  # The one crossing between what a screen says and what a row records, and the
  # reason it lives here: a presenter has no business knowing the register, and
  # the register no business knowing how a card words itself.
  def card_names_of(wording)
    { requirement_id: wording.requirement_id, requirement_name: wording.requirement,
      requirement_language: wording.requirement_language, country_code: wording.country_code,
      evidence_type_list_id: wording.combination_id }
  end

  def named_evidence_of(wording, line)
    ::Demo::NamedEvidence.new(
      **card_names_of(wording),
      evidence_type_id: line.evidence_type_id,
      evidence_type_name: line.evidence_type, evidence_type_language: line.evidence_type_language,
      provider_name: line.provider, provider_language: line.provider_language,
      provider_classifications: line.provider_classifications,
    )
  end

  def named_procedure_of(procedure)
    ::Demo::NamedProcedure.new(procedure_name: procedure.title, procedure_language: procedure.title_language)
  end
end
