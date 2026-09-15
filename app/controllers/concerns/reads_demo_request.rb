# The request the demonstration's session is following, and what the contract
# says of it — what the zone of the documents page is built on.
#
# Chapter 1 §4.2: « Any evidences that are returned in response are made
# available to the specific procedure end-user that issued the query for those
# evidences. » The session is what says which user issued which query, so the
# identifier is read from there and never from the request — a zone taking it
# from a parameter would report on whoever guessed a UUID.
#
# Nothing here redirects: a session following no request is the ordinary state
# of the page before the press, and the zone then offers the press and nothing
# else.
module ReadsDemoRequest
  extend ActiveSupport::Concern

  private

  def exchange_id = session[:demo_exchange].presence

  # `defined?` and not `||=`: a session following an exchange the register does
  # not carry must ask once and be answered `nil` once.
  def demo_request
    return @demo_request if defined?(@demo_request)

    @demo_request = ::Demo::Request.find_by(exchange_id:)
  end

  # `nil` where nothing has been asked yet, which is the one state the contract
  # is not consulted for. An outage is not that state — the request exists, and
  # the zone says the outage where it would say a refusal.
  def demo_outcome
    return @demo_outcome if defined?(@demo_outcome)

    @demo_outcome = read_demo_outcome
  end

  def read_demo_outcome
    return nil if demo_request.nil?

    DemoOutcomeWording.new(answer: state_client.fetch(demo_request.exchange_id), request: demo_request)
  rescue DemoContractError => e
    # Logged as much as shown, like the interactors of `Demo::`: the zone tells
    # the user of the outage, and the log is the only place it remains once the
    # screen is closed. The client that raises does not log, the trace belonging
    # to whoever knows which reading it fell in.
    Rails.logger.warn(I18n.t('controllers.reads_demo_request.unanswered', error: e.message))

    DemoOutcomeWording.unanswered(request: demo_request, error: e.message)
  end

  def state_client = @state_client ||= ::Demo::ExchangeStateClient.new
end
