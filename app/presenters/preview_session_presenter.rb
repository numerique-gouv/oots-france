# What France's preview space says of one preview: where the user is at, what
# is asked of them, and the way back to their procedure.
class PreviewSessionPresenter
  # `first_request`: the request the preview answers, read already — what the
  # page says of who asks and for what.
  def initialize(session, first_request: nil)
    @session = session
    @first_request = first_request
  end

  # The state the page renders, one per outcome the user can meet.
  def state
    return :invalid if session.nil?
    return :expired if session.expired?
    return :open if session.openable?
    return :recorded if session.decided? || session.answered?

    :invalid
  end

  delegate :token, :return_location, to: :session

  # Chapter 4.9 §2, step 8: who asks, and for what, as the request said it.
  def requester_name = first_request.requester.name

  def evidence_title
    titles = first_request.evidence_type.descriptions
    titles['FR'] || titles['EN'] || titles.values.first
  end

  def document_size = ActiveSupport::NumberHelper.number_to_human_size(session.document_bytes.bytesize, locale: :fr)

  # Chapter 4.9 v1.2.3 §2, step 13: a 1.2 visit that brought no safe way back.
  def return_warning? = session.specification.preview_method_slot? && return_location.blank?

  def return_by_form? = session.return_method.in?(%w[POST PUT])

  # 2.0 learns the way back from the second request, which may not have come:
  # the page then says the procedure will take over, and asks again.
  def awaiting_return? = state == :recorded && return_location.blank? && !session.specification.preview_method_slot?

  private

  attr_reader :session, :first_request
end
