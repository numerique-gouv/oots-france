# What the zone of the documents page says of the exchange it follows:
# which of the four things happened, and the values that go with it.
#
# Built on what the contract answered and on what the procedure was handed,
# never on this deployment's own state: the page is a service provider's screen,
# and it knows exactly what a service provider knows.
class DemoOutcomeWording
  # The two states the page has something of its own to say about on the word of
  # the contract alone. Anything else — `pending`, `sent`, and the `deferred`
  # this procedure never meets, asking only for `T1`, which France always serves
  # with a document — is still under way as far as the user is concerned. A
  # contract `delivered` is deliberately absent: the document in hand is what
  # settles that one, and `outcome` has already answered before reading here.
  OUTCOMES = {
    'failed' => :refused,
    'preview_required' => :preview,
  }.freeze

  # How long the zone of the documents page keeps re-asking before it says so
  # and offers to ask again. The answer comes back on another connection and
  # nothing bounds how long that takes, so the deadline is the screen's and not
  # the exchange's: the exchange carries on, and the register keeps it.
  #
  # Counted here rather than in the browser because the state it qualifies is
  # read here: a tab reopened on a request made an hour ago must be told the
  # same thing as one that has been waiting two minutes, and a counter started
  # at `connect()` would call it fresh.
  GIVE_UP_AFTER = 2.minutes

  # The contract unreachable: nothing is known of the exchange, and the page
  # says only what the register holds — the two identifiers it was given. A
  # wording all the same, so that the page has one shape and not two.
  def self.unanswered(request:, error: nil, clock: Clock.new)
    new(answer: Demo::ContractAnswer.unreached(error:), request:, clock:)
  end

  delegate :edm_error_code, :preview_location, to: :answer
  delegate :evidence?, :evidence_digest, :exchange_id, :conversation_id,
    :evidence_type_name, :evidence_type_language, :provider_name, :provider_language,
    :procedure_name, :procedure_language, to: :request

  def initialize(answer:, request:, clock: Clock.new)
    @answer = answer
    @request = request
    @clock = clock
  end

  # The evidence in hand settles it, whatever the state says. The two are
  # written by two processes with the handover between them: `SettleExchange`
  # marks the exchange delivered only once this procedure has answered the POST,
  # so the document is filed here first and a `delivered` with nothing to show
  # is the same instant read from the other side.
  def outcome
    return :delivered if evidence?

    settled = OUTCOMES.fetch(answer.exchange_status, :pending)

    return settled unless settled == :pending

    # An exchange still under way long after the click. Nothing went wrong that
    # anyone can name — which is why it is said as its own outcome rather than
    # folded into a refusal — and asking again is the only move chapter 4.4 §4.1
    # leaves: « a new unique request MUST be issued ».
    waited_too_long? ? :expired : :pending
  end

  # The contract itself refusing to answer — an exchange it does not know, the
  # feature switch closed. Distinguished from every outcome above: nothing is
  # known of the exchange, which is not the same as knowing it went nowhere.
  def unreadable? = !answer.readable?

  def refusal = answer.error

  def secure_preview? = WebAddress.new(preview_location).secure?

  # What the journey named before the request left, filed with it: the heading
  # says what was asked, of whom, and under which procedure, rather than naming
  # the page. The three of them, because the heading is one sentence and half a
  # sentence is worse than a title of our own — and the procedure's title is the
  # one a directory does not owe anyone, so a request may well carry the other
  # two without it.
  def named? = [evidence_type_name, provider_name, procedure_name].all?(&:present?)

  private

  # A request with no instant to count from has not been recorded, so nothing
  # has been asked and nothing can have waited.
  def waited_too_long?
    return false if request.created_at.nil?

    request.created_at + GIVE_UP_AFTER < clock.now
  end

  attr_reader :answer, :request, :clock
end
