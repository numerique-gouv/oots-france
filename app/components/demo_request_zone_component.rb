# The zone of the documents page where the document is asked for and where
# what became of the asking is said: the button, then the document, or why there
# is none.
#
# It holds only what changes. The evidence type and the provider requirement 27
# of chapter 1 §2 has named stand in the card above and never move, so they are
# not part of what an answer replaces.
#
# One component for the five states because it is one place on the screen. A
# click is answered where it was made — the user's eye is on the button — and
# the address it re-asks answers this same zone, so what arrives can replace
# what is there.
#
# Only `pending` and `preview` re-ask. A settled zone carries no polling at all,
# which is what stops the asking: nothing has to decide to stop.
#
# One zone per requirement the page can name, each on its own two addresses:
# `requirement_uuid` is what says which requirement this button asks for and
# which request this zone reports on. A page carries several, and none of them
# knows anything of the others.
class DemoRequestZoneComponent < ViewComponent::Base
  # What the wording under the button says, per outcome. `expired` is the screen's
  # own deadline rather than anything the exchange did — `DemoOutcomeWording`
  # says why. `unpresentable` and `unconfirmed` are a preview this page cannot
  # lead the user to, and asking again is all that is left.
  FAILURES = {
    refused: 'refused', expired: 'expired', declined: 'declined',
    unpresentable: 'unpresentable', unconfirmed: 'unconfirmed',
  }.freeze

  # The one ending that is nobody's failure: the user chose, on the preview
  # space, not to use the document.
  INFORMATIVE = %i[declined].freeze

  # The outcomes the zone says as something other than a failure.
  STANDING = { delivered: :delivered, pending: :pending, preview: :preview }.freeze

  def initialize(outcome:, requirement_uuid:, failure: nil)
    @outcome = outcome
    @requirement_uuid = requirement_uuid
    @failure = failure
    super()
  end

  # The address the button posts to, and the one the browser re-asks while it
  # waits — the same one, `RequestsController` answering both. A parameter and
  # not a segment of the path: the path is what `docs/espace_administration.md`
  # documents and what the end-to-end suite finds its form by.
  def button_path = helpers.admin_demo_demande_path(exigence: requirement_uuid)

  # The document this zone's own request obtained. Chapter 1 §4.2 has it
  # « made available to the specific procedure end-user that issued the query »,
  # and the requirement only says which of that user's requests is meant.
  def evidence_path = helpers.admin_demo_justificatif_path(exigence: requirement_uuid)

  # Private: outside the class everything is read through the accessors that
  # apply the precedence of `refused_the_click?`, and a raw read would skirt it.
  private attr_reader :outcome, :failure

  attr_reader :requirement_uuid

  # `idle` before any click, `pending` while the answer is out, `preview` while
  # the user has the preview space to visit, `delivered` once the document is in
  # hand, `failed` for everything else — a refusal the contract returned, an
  # exchange that never opened, a wait this screen gave up on, a contract that
  # could not be read, a document the user chose not to use.
  def state
    return :failed if refused_the_click?
    return :idle if outcome.nil?
    return :failed if outcome.unreadable?

    STANDING.fetch(outcome.outcome, :failed)
  end

  def pending? = state == :pending

  def preview? = state == :preview

  # The departure page waits too: the second exchange may settle while the
  # user is away, and the zone then leaves it.
  def polling? = pending? || preview?

  def delivered? = state == :delivered

  def failed? = state == :failed

  # The label of the one button, which is the same one throughout: asking
  # again after a refusal is a new request and not a retry of the old one —
  # chapter 4.4 §4.1, « a new unique request MUST be issued ».
  def submit_label = t("components.demo_request_zone.#{failed? ? 'retry' : 'submit'}")

  # The title of the alert, named by what happened. A failure that never opened
  # an exchange is named by its own interactor key, which is what says which of
  # the contract's refusals it was.
  def failure_title
    return t("interactors.failures.#{failure[:key]}") if refused_the_click?
    return t('components.demo_request_zone.unreadable') if outcome.unreadable?

    t("components.demo_request_zone.#{FAILURES.fetch(outcome.outcome)}_title")
  end

  def failure_body
    return Array(failure[:errors]).join(' ').presence if refused_the_click?
    return outcome.refusal.presence if said_by_the_contract?

    t("components.demo_request_zone.#{FAILURES.fetch(outcome.outcome)}_body")
  end

  # The `EDM:ERR:*` the correspondent returned, where there is one: it is the
  # only thing that says which refusal this was, and the component the journal
  # already uses glosses it.
  #
  # Nothing when the click itself was refused: no exchange was opened, so no
  # correspondent answered, and the outcome still standing beside it belongs to
  # the journey before — `RequestsController#refuse` leaves the session where it
  # was. Showing its code under another refusal's title would name the wrong
  # refusal.
  def edm_error_code
    return nil if refused_the_click?

    outcome&.edm_error_code.presence
  end

  def failure_type = !refused_the_click? && !outcome.unreadable? && INFORMATIVE.include?(outcome.outcome) ? :info : :error

  # What the departure page presents, read off the request the confirmation
  # filled. Public for the template, like the accessors above.
  delegate :preview_address, :preview_description, :preview_description_language, :preview_form?,
    :preview_fields, to: :outcome

  private

  # What the zone is reporting: a click the contract turned away, or what became
  # of one it accepted. The two can stand together — a refused click leaves the
  # exchange of the journey before in session — and the click is then the whole
  # of what this zone has to say.
  def refused_the_click? = failure.present?

  # The two failures only the contract's own message can explain: it could not
  # be read, or it refused the confirmation of the preview.
  def said_by_the_contract? = outcome.unreadable? || outcome.outcome == :unconfirmed
end
