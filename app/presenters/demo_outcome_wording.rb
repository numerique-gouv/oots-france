# What the zone of the documents page says of the exchange it follows:
# which of the things that can happen did, and the values that go with it.
#
# Built on what the contract answered and on what the procedure was handed,
# never on this deployment's own state: the page is a service provider's screen,
# and it knows exactly what a service provider knows.
class DemoOutcomeWording
  # The states the page has something of its own to say about on the word of
  # the contract alone. An `unmatched` is said as a failure: chapter 4.10 §2.1
  # has the portal tell the user, and the page says the one refusal it has for
  # every failure. A `declined` is the user's own choice on the preview space —
  # chapter 4.9 §1, « if the user decides not to use any piece of evidence, the
  # evidence response shall contain an empty registry object list » — and is
  # said as such. Anything else — `pending`, `sent`, a `preview_required` the
  # procedure confirms as it reads it, and the `deferred` this procedure never
  # meets, asking only for `T1`, which France always serves with a document —
  # is still under way as far as the user is concerned. A contract `delivered`
  # is deliberately absent: the document in hand is what settles that one, and
  # `outcome` has already answered before reading here.
  OUTCOMES = {
    'failed' => :refused,
    'unmatched' => :refused,
    'declined' => :declined,
  }.freeze

  # The verbs a departure page can follow the link with: a link, or a form. A
  # `PUT`, which chapter 4.9 v1.2.3 §5 allows a correspondent, is one no HTML
  # form sends.
  PRESENTABLE_METHODS = %w[GET POST].freeze

  # How long the zone of the documents page keeps re-asking before it says so
  # and offers to ask again. The answer comes back on another connection and
  # nothing bounds how long that takes, so the deadline is the screen's and not
  # the exchange's: the exchange carries on, and the register keeps it.
  #
  # Counted here rather than in the browser because the state it qualifies is
  # read here: a tab reopened on a request made an hour ago must be told the
  # same thing as one that has been waiting two minutes, and a counter started
  # at `connect()` would call it fresh. Counted from the return when the user
  # went to preview the document: the time spent there is the user's.
  GIVE_UP_AFTER = 2.minutes

  # The contract unreachable: nothing is known of the exchange, and the page
  # says only what the register holds — the two identifiers it was given. A
  # wording all the same, so that the page has one shape and not two.
  def self.unanswered(request:, error: nil, clock: Clock.new)
    new(answer: Demo::ContractAnswer.unreached(error:), request:, clock:)
  end

  delegate :edm_error_code, to: :answer
  delegate :evidence?, :evidence_digest, :exchange_id, :conversation_id,
    :evidence_type_name, :evidence_type_language, :provider_name, :provider_language,
    :procedure_name, :procedure_language,
    :preview_address, :preview_description, :preview_description_language, to: :request

  # `unconfirmed`: the failure of the confirmation this reading led to, if it
  # failed — `ReadsDemoRequest#confirm_preview` says when one is made.
  def initialize(answer:, request:, unconfirmed: nil, clock: Clock.new)
    @answer = answer
    @request = request
    @unconfirmed = unconfirmed
    @clock = clock
  end

  # The evidence in hand settles it, whatever the state says. The two are
  # written by two processes with the handover between them: `SettleExchange`
  # marks the exchange delivered only once this procedure has answered the POST,
  # so the document is filed here first and a `delivered` with nothing to show
  # is the same instant read from the other side.
  def outcome
    return :delivered if evidence?

    settled = OUTCOMES[answer.exchange_status]

    return settled if settled
    return :unconfirmed if unconfirmed
    return departure if request.awaiting_return?

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

  # What the contract said when it would not answer: about the exchange, or
  # about the confirmation of its preview.
  def refusal = unconfirmed ? Array(unconfirmed[:errors]).join(' ') : answer.error

  def preview_form? = preview_method == 'POST'

  # The fields of the form a `POST` sends, which the contract hands as
  # `application/x-www-form-urlencoded` — `PreviewLink#body`.
  def preview_fields = URI.decode_www_form(request.preview_body.to_s)

  # A request still under way, or one whose document is in hand: the card then
  # stays in the country that request went to, since a card naming another over
  # a zone following it would say something no exchange rests on. Exactly the
  # states in which the zone offers no button; once it offers one again, the
  # country may change with it.
  #
  # The departure page is such a state: the request is under way, on the
  # preview space.
  def holds_country? = !unreadable? && %i[pending preview delivered].include?(outcome)

  # What the journey named before the request left, filed with it: the heading
  # says what was asked, of whom, and under which procedure, rather than naming
  # the page. The three of them, because the heading is one sentence and half a
  # sentence is worse than a title of our own — and the procedure's title is the
  # one a directory does not owe anyone, so a request may well carry the other
  # two without it.
  def named? = [evidence_type_name, provider_name, procedure_name].all?(&:present?)

  private

  # The departure page, with no deadline: the user is away on the preview space
  # for as long as it takes them, and nothing is expected back before they
  # return — or before the second exchange settles, which `outcome` has already
  # read. A link no form can follow is said rather than presented.
  def departure = PRESENTABLE_METHODS.include?(preview_method) ? :preview : :unpresentable

  # Chapter 4.9 v1.2.3 §4 has `PreviewMethod` absent mean a link, as
  # `PreviewLink#http_method` reads it.
  def preview_method = request.preview_method.presence || PreviewLink::GET

  # A request with no instant to count from has not been recorded, so nothing
  # has been asked and nothing can have waited.
  def waited_too_long?
    return false if request.waiting_since.nil?

    request.waiting_since + GIVE_UP_AFTER < clock.now
  end

  attr_reader :answer, :request, :unconfirmed, :clock
end
