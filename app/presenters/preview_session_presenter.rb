# What France's preview space says of one preview: where the user is at, what
# is asked of them, and the way back to their procedure.
class PreviewSessionPresenter
  # `first_request`: the request the preview answers, read already — what the
  # page says of who asks and for what. `verdict`: what the identity check
  # said of this browser (`RecognisesPreviewIdentity::VERDICTS`), or nil
  # before it. `unavailable`: FranceConnect+ could not be reached.
  def initialize(session, first_request: nil, verdict: nil, unavailable: false)
    @session = session
    @first_request = first_request
    @verdict = verdict
    @unavailable = unavailable
  end

  # The state the page renders, one per outcome the user can meet.
  def state
    return :invalid if session.nil?
    return :unavailable if unavailable
    return :refused if refused?

    lifecycle
  end

  delegate :token, :return_location, to: :session

  def segment = session.specification.segment

  # Chapter 4.9 §2, steps 15-17: nothing of the request is shown before the
  # user has identified again — a page that names who asks, the document, the
  # way back. Asked while the subject is kept to check against, until the
  # answer goes; what says the link is spent, or the evidence refused, needs
  # none.
  def identification_required?
    verdict.nil? && (state == :open || (state.in?(%i[recorded unmatched]) && !session.answered?))
  end

  # Whether the request is still there to name who asks, and for what: it goes
  # with the answer, and the page then says only the outcome.
  def names_request? = first_request.present?

  # Chapter 4.9 §2, step 8: who asks, and for what, as the request said it.
  def requester_name = first_request.requester.name

  def evidence_title
    titles = first_request.evidence_type.descriptions
    titles['FR'] || titles['EN'] || titles.values.first
  end

  def document_size = ActiveSupport::NumberHelper.number_to_human_size(session.document_bytes.bytesize)

  # Chapter 4.9 v1.2.3 §2, step 13: a 1.2 visit that brought no safe way back.
  def return_warning? = session.specification.preview_method_slot? && return_location.blank?

  def return_by_form? = session.return_method.in?(%w[POST PUT])

  # Once the choice is made the space has nothing more to show: the user is
  # sent straight back to the procedure whenever a redirection can carry them.
  # A form cannot be redirected to, and the page stays only to submit it.
  def leaves_by_redirection? = follows_return? && return_location.present? && !return_by_form?

  # The way back is offered to the browser that made the choice, and to the one
  # whose failed check concluded the address (steps 19-20) — never to another,
  # the way back being someone else's.
  def offers_return?
    case state
    when :recorded, :unmatched then verdict == :confirmed
    when :refused then verdict == :refused && session.identification_failed?
    else false
    end
  end

  # 2.0 learns the way back from the second request, which may not have come:
  # the page then says the procedure will take over, and asks again.
  def awaiting_return? = offers_return? && return_location.blank? && !session.specification.preview_method_slot?

  # Taken on its own once known after a choice; after a refusal the user reads
  # first why the evidence cannot be provided (article 16(3) of implementing
  # regulation 2022/1463), and where no document matches them, that none does
  # (chapter 2.1 §3.3).
  def follows_return? = state == :recorded && offers_return?

  private

  def lifecycle
    return :expired if session.expired?
    return :open if session.openable?
    return :invalid unless session.decided? || session.answered?

    session.unmatched? ? :unmatched : :recorded
  end

  # Chapter 4.9 §2, steps 19-20: this browser failed the identity check, or
  # someone's failure concluded the address.
  def refused? = verdict.in?(%i[refused rejected]) || session.identification_failed?

  attr_reader :session, :first_request, :verdict, :unavailable
end
