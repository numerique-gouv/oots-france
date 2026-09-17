# The two names requirement 27 of chapter 1 §2 has the documents page show
# « before any request is made », and the title that page stands under, kept from
# the page to the click that follows.
#
# One concern for the two keys, because the two addresses are two halves of one
# gesture: the documents page writes them and `RequestsController` reads them
# back, and a correspondence spread over two files holds only as long as both are
# read together. Reading them back rather than resolving them again keeps three
# directory queries off an address made to be asked over and over — and chapter
# 4.5.1 §2.3 leaves the `IssueDateTime` no material distance from the click.
#
# What is held is `Demo::NamedEvidence` and `Demo::NamedProcedure`, in the
# vocabulary the request carries: this is the one place the words of the screen
# and the words of the register meet.
module HoldsDemoNames
  extend ActiveSupport::Concern

  private

  # One entry per card that can be clicked, under the UUID its address carries.
  # Whatever a card cannot name it cannot offer to confirm, so it is not written
  # at all, and the click that finds nothing under its own UUID is sent back to
  # the page.
  def remember_demo_names(procedure, wordings)
    session[:demo_procedure] = named_procedure_of(procedure).to_session
    session[:demo_named] = wordings.select(&:nameable?)
      .to_h { |wording| [wording.requirement_uuid, named_evidence_of(wording).to_session] }
  end

  # What the card of this requirement named, and nothing of its neighbours'. The
  # requirement is passed rather than read off whoever includes this, as
  # `ReadsDemoRequest` passes it too: a page carries one zone per requirement,
  # and each answers for its own.
  def named_evidence(requirement_uuid)
    ::Demo::NamedEvidence.from_session(session[:demo_named].presence&.dig(requirement_uuid))
  end

  def named_procedure = ::Demo::NamedProcedure.from_session(session[:demo_procedure])

  # The names a request goes out with: `Demo::RequestEvidence::NAMED` reads each
  # off its context under the name it carries here.
  def demo_names(requirement_uuid)
    named_evidence(requirement_uuid).attributes.merge(named_procedure.attributes).symbolize_keys
  end

  # The one crossing between what a screen says and what a row records, and the
  # reason it lives here: a presenter has no business knowing the register, and
  # the register no business knowing how a card words itself.
  def named_evidence_of(wording)
    ::Demo::NamedEvidence.new(
      evidence_type_name: wording.evidence_type, evidence_type_language: wording.evidence_type_language,
      provider_name: wording.provider, provider_language: wording.provider_language,
      requirement_id: wording.requirement_id, requirement_name: wording.requirement,
      requirement_language: wording.requirement_language,
    )
  end

  def named_procedure_of(procedure)
    ::Demo::NamedProcedure.new(procedure_name: procedure.title, procedure_language: procedure.title_language)
  end
end
