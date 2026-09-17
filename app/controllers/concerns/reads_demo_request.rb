# The requests the demonstration's session is following, one per requirement of
# the procedure it has asked for, and what the contract says of each — what the
# zone of a card on the documents page is built on.
#
# Chapter 1 §4.2: « Any evidences that are returned in response are made
# available to the specific procedure end-user that issued the query for those
# evidences. » The session is what says which user issued which query, so the
# exchange identifier is read from there and never from the request — a zone
# taking it from a parameter would report on whoever guessed a UUID. The
# requirement, which does travel in a parameter, only says which of the
# session's own exchanges is meant.
#
# Nothing here redirects: a session following no request for a requirement is
# the ordinary state of its card before the press, and the zone then offers the
# press and nothing else.
module ReadsDemoRequest
  extend ActiveSupport::Concern

  private

  # Keyed by the UUID of the requirement, which is what the page's addresses
  # carry. One entry per requirement asked for: chapter 4.4 §4.2.2 has « different
  # basic flows … executed sequentially and/or in parallel », so an exchange
  # under way on one requirement says nothing about its neighbours.
  def exchange_ids = session[:demo_exchanges].presence || {}

  def demo_request_for(requirement_uuid)
    asked_once(:@demo_requests, requirement_uuid) do
      exchange_id = exchange_ids[requirement_uuid].presence

      exchange_id && ::Demo::Request.find_by(exchange_id:)
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

    DemoOutcomeWording.new(answer: state_client.fetch(request.exchange_id), request:)
  rescue DemoContractError => e
    # Logged as much as shown, like the interactors of `Demo::`: the zone tells
    # the user of the outage, and the log is the only place it remains once the
    # screen is closed. The client that raises does not log, the trace belonging
    # to whoever knows which reading it fell in.
    Rails.logger.warn(I18n.t('controllers.reads_demo_request.unanswered', error: e.message))

    DemoOutcomeWording.unanswered(request:, error: e.message)
  end

  def state_client = @state_client ||= ::Demo::ExchangeStateClient.new
end
