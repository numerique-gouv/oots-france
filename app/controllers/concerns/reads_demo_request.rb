# The requests the demonstration's journey has made, one per requirement of the
# procedure it has asked for, and what the contract says of each — what the zone
# of a card on the documents page is built on.
#
# Chapter 1 §4.2: « Any evidences that are returned in response are made
# available to the specific procedure end-user that issued the query for those
# evidences. » The journey held in the session is what says which user issued
# which query, so a request is looked up under it and never named by the
# incoming one — a zone taking an exchange identifier from a parameter would
# report on whoever guessed a UUID. The requirement, which does travel in a
# parameter, only says which of this journey's own requests is meant.
#
# Nothing here redirects: a session following no request for a requirement is
# the ordinary state of its card before any click, and the zone then offers the
# button and nothing else.
module ReadsDemoRequest
  extend ActiveSupport::Concern

  # The journey a request is looked up under comes from there, so the dependency
  # is declared rather than left to whoever includes this: a controller taking
  # this concern alone would fail at the first card. `ActiveSupport::Concern`
  # includes it once however many of the two a controller names.
  include HoldsDemoJourney

  private

  # Read from the register, under the journey and the requirement: a click writes
  # a row naming this journey, so two clicks made in the same instant each file
  # their own and neither can lose the other.
  #
  # The requirement is the UUID the page's addresses carry, and the journey is
  # never one of them. Chapter 4.4 §4.2.2 has « different basic flows … executed
  # sequentially and/or in parallel », so a request under way on one requirement
  # says nothing about its neighbours.
  #
  # The latest and not the only one: asking again is « a new unique request »
  # (chapter 4.4 §4.1), so a requirement clicked twice has two rows, and the
  # zone reports on the one its last click opened. Two rows of the same instant
  # are told apart by the order they were written in, which is what `id` says.
  def demo_request_for(requirement_uuid)
    asked_once(:@demo_requests, requirement_uuid) do
      ::Demo::Request.where(journey_id: journey.id, requirement_uuid:).order(:created_at, :id).last
    end
  end

  # `nil` where nothing has been asked yet, which is the one state the contract
  # is not consulted for. An outage is not that state — the request exists, and
  # the zone says the outage where it would say a refusal.
  def demo_outcome_for(requirement_uuid)
    asked_once(:@demo_outcomes, requirement_uuid) { read_demo_outcome(demo_request_for(requirement_uuid)) }
  end

  # One answer per requirement, and `key?` rather than a truthiness test: a
  # requirement whose answer is `nil` — a session following an exchange the
  # register no longer carries, or one that has asked for nothing — must be
  # asked once and answered `nil` once, not asked again at every card.
  def asked_once(store, requirement_uuid)
    answered = instance_variable_get(store) || instance_variable_set(store, {})
    return answered[requirement_uuid] if answered.key?(requirement_uuid)

    answered[requirement_uuid] = yield
  end

  def read_demo_outcome(request)
    return nil if request.nil?

    state = state_client.fetch(request.exchange_id)
    log_unreadable(request, state) unless state.readable?

    DemoOutcomeWording.new(answer: state, request:, unconfirmed: confirm_preview(request, state))
  rescue DemoContractError => e
    # Logged as much as shown, like the interactors of `Demo::`: the zone tells
    # the user of the outage, and the log is the only place it remains once the
    # screen is closed. The client that raises does not log, the trace belonging
    # to whoever knows which reading it fell in.
    Rails.logger.warn(I18n.t('controllers.reads_demo_request.unanswered', error: e.message))

    DemoOutcomeWording.unanswered(request:, error: e.message)
  end

  # The one write a reading leads to: chapter 4.9 §5 has the portal recognise
  # the preview the first flow asks for and present a link to it, and the
  # contract hands that link only in its answer to the confirmation. Asked until
  # it succeeds — the link kept on the request says it did — and never again
  # after that, however often the zone reads the state. Confirming is not asking
  # again: it is the second round trip of the same exchange (chapter 4.9 §2
  # step 12).
  #
  # The user comes back to this page, under the line of the journey: an address
  # without its segment is one the walk no longer serves. What went wrong, if
  # anything, is returned for the zone to say.
  def confirm_preview(request, state)
    return nil unless state.preview_required? && !request.preview_link?

    result = ::Demo::ConfirmPreview.call(request:, state:, identity:, resume_location: demo_resume_location)

    result.error unless result.success?
  end

  def demo_resume_location = "#{Settings.oots_france_url}#{admin_demo_documents_path(version: journey.specification.segment)}"

  # What the contract answered when it would not say the state — an exchange it
  # does not know, the feature switch closed: the zone says only that it could
  # not read it, and this line is where the reason remains.
  def log_unreadable(request, state)
    Rails.logger.warn(I18n.t('controllers.reads_demo_request.unreadable',
      exchange: request.exchange_id, status: state.status, error: state.error))
  end

  def state_client = @state_client ||= ::Demo::ExchangeStateClient.new
end
