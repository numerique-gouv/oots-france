# One block of the zone of a card on the documents page: where one evidence type
# is asked for, and where what became of the asking is said — the button, then
# the document, or why there is none.
#
# It holds only what changes. The evidence type and the provider requirement 27
# of chapter 1 §2 has named stand in the card above and never move, so they are
# not part of what an answer replaces; in a combination of several types, the
# block repeats the name of its own, which says which of them it reports on.
#
# One component for the five states because it is one place on the screen. A
# click is answered where it was made — the user's eye is on the button — and
# the zone around it answers its address with every block, so what arrives can
# replace what is there.
#
# Only `pending` and `preview` re-ask. A settled block carries no polling at all,
# which is what stops the asking: nothing has to decide to stop.
class DemoRequestComponent < ViewComponent::Base
  # What the wording under the button says, per outcome. `expired` is the screen's
  # own deadline rather than anything the exchange did — `DemoOutcomeWording`
  # says why. `unpresentable` and `unconfirmed` are a preview this page cannot
  # lead the user to, and asking again is all that is left. `unavailable` is a
  # failure no correspondent decided.
  FAILURES = {
    refused: 'refused', unavailable: 'unavailable', expired: 'expired', declined: 'declined',
    deferred: 'deferred', unpresentable: 'unpresentable', unconfirmed: 'unconfirmed',
  }.freeze

  # The endings that are nobody's failure, said in the place of a failure since
  # they too settle the request without a document: the user chose, on the
  # preview space, not to use the document, or the provider announced it for
  # later.
  INFORMATIVE = %i[declined deferred].freeze

  # The outcomes the zone says as something other than a failure.
  STANDING = %i[delivered pending preview].freeze

  # `evidence_type` is a `DemoRequestZoneComponent::Type`; `headed` a block
  # among others, which says the name of its type.
  def initialize(outcome:, requirement_uuid:, evidence_type:, headed: false, failure: nil)
    @outcome = outcome
    @requirement_uuid = requirement_uuid
    @evidence_type = evidence_type
    @headed = headed
    @failure = failure
    super()
  end

  # The address the button posts to — the zone's, which `RequestsController`
  # answers with every block — and the type it asks for. Parameters and not
  # segments of the path: the path is what `docs/espace_administration.md`
  # documents and what the end-to-end suite finds its form by.
  def button_path = helpers.admin_demo_demande_path(exigence: requirement_uuid, type: evidence_type.uuid)

  # The document this block's own request obtained. Chapter 1 §4.2 has it
  # « made available to the specific procedure end-user that issued the query »,
  # and the requirement and the type only say which of that user's requests is
  # meant.
  def evidence_path = helpers.admin_demo_justificatif_path(exigence: requirement_uuid, type: evidence_type.uuid)

  # Private: outside the class everything is read through the accessors that
  # apply the precedence of `refused_click?`, and a raw read would skirt it.
  private attr_reader :outcome, :failure

  attr_reader :requirement_uuid, :evidence_type

  def headed? = @headed

  # What the block is reporting: a click the contract turned away, or what
  # became of one it accepted. The two can stand together — a refused click
  # leaves the request before in the register — and the click is then the whole
  # of what this block has to say. No exchange holds such a refusal: only the
  # answer to that click says it.
  def refused_click? = failure.present?

  # Something was asked for this type: a request, or a click the contract
  # refused.
  def asked? = outcome.present? || refused_click?

  # `idle` before any click, `pending` while the answer is out, `preview` while
  # the user has the preview space to visit, `delivered` once the document is in
  # hand, `failed` for everything else — a refusal the contract returned, an
  # exchange that never opened, a wait this screen gave up on, a contract that
  # could not be read, a document the user chose not to use, a document
  # announced for later.
  def state
    return :failed if refused_click?
    return :idle if outcome.nil?
    return :failed if outcome.unreadable?

    STANDING.include?(outcome.outcome) ? outcome.outcome : :failed
  end

  def pending? = state == :pending

  def preview? = state == :preview

  # The departure page waits too: the second exchange may settle while the
  # user is away, and the zone then leaves it.
  def polling? = pending? || preview?

  def delivered? = state == :delivered

  def failed? = state == :failed

  # The label of the block's button, which is the same one throughout: asking
  # again after a refusal is a new request and not a retry of the old one —
  # chapter 4.4 §4.1, « a new unique request MUST be issued ».
  def submit_label = t("components.demo_request_zone.#{failed? ? 'retry' : 'submit'}")

  # The title of the alert, named by what happened. A failure that never opened
  # an exchange is named by its own interactor key, which is what says which of
  # the contract's refusals it was.
  def failure_title
    return t("interactors.failures.#{failure[:key]}") if refused_click?

    t("components.demo_request_zone.#{failure_name}_title")
  end

  # A sentence of the portal's own, and never what the contract said or what an
  # exception carried: those are written for whoever runs the deployment, in
  # French, and stay in the application log, where the reading and the
  # confirmation already write them. The one exception is the click refused
  # before any exchange opened, which names the refusal of the contract.
  def failure_body
    return Array(failure[:errors]).join(' ').presence if refused_click?
    return announcement if settled_outcome == :deferred

    t("components.demo_request_zone.#{failure_name}_body")
  end

  # The language of the alert: the click refused is said with the console's
  # French wording, everything else in the English of the procedure (RGAA 8.7).
  def failure_language = refused_click? ? 'fr' : 'en'

  # The `EDM:ERR:*` the correspondent returned, where there is one: it is the
  # only thing that says which refusal this was, and the component the journal
  # already uses glosses it.
  #
  # Nothing when the click itself was refused: no exchange was opened, so no
  # correspondent answered, and the outcome still standing beside it belongs to
  # the request before. Showing its code under another refusal's title would
  # name the wrong refusal. Nothing for an announcement either: chapter 4.5.2
  # §2.1 makes it a response carrying `ResponseAvailableDateTime`, and none of
  # the codes of chapter 4.5.3 names a deferral.
  def edm_error_code
    return nil if refused_click? || settled_outcome == :deferred

    outcome&.edm_error_code.presence
  end

  def failure_type = INFORMATIVE.include?(settled_outcome) ? :info : :error

  # What the departure page presents, read off the request the confirmation
  # filled. Public for the template, like the accessors above.
  delegate :preview_address, :preview_description, :preview_description_language, :preview_form?,
    :preview_fields, to: :outcome

  private

  # What the contract says became of the request, when that is what the block
  # reports: neither a refused click nor a contract that could not be read.
  def settled_outcome = (outcome.outcome unless refused_click? || outcome.unreadable?)

  # Chapter 4.5.2 §2.5: the portal « may use this information to inform the
  # user to pause the procedure and to return at a later point ».
  def announcement
    date = outcome.announced_for
    return t('components.demo_request_zone.deferred_undated_body') if date.nil?

    t('components.demo_request_zone.deferred_body',
      date: date.strftime(t('components.demo_request_zone.deferred_date')))
  end

  def failure_name = outcome.unreadable? ? 'unreadable' : FAILURES.fetch(outcome.outcome)
end
