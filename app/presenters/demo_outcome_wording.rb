# What the tracking page of the demonstration says of the exchange it follows:
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

  # Chapter 4.9 §4: « specify secure HTTP ("https://") as transport. The use of
  # "http://" URIs is not allowed. » An address the chapter forbids is shown as
  # the text it already was, and never offered as a step of the journey.
  # Stricter than `ApplicationHelper#external_link`, which admits `http` because
  # the console archives what a correspondent wrote rather than sending anyone
  # there.
  SECURE_PREVIEW = %r{\Ahttps://}

  # The contract unreachable: nothing is known of the exchange, and the page
  # says only what the register holds — the two identifiers it was given. A
  # wording all the same, so that the page has one shape and not two.
  def self.unanswered(request:) = new(answer: Demo::ContractAnswer.unreached, request:)

  delegate :edm_error_code, :preview_location, to: :answer
  delegate :evidence?, :evidence_digest, :exchange_id, :conversation_id, to: :request

  def initialize(answer:, request:)
    @answer = answer
    @request = request
  end

  # The evidence in hand settles it, whatever the state says. The two are
  # written by two processes with the handover between them: `SettleExchange`
  # marks the exchange delivered only once this procedure has answered the POST,
  # so the document is filed here first and a `delivered` with nothing to show
  # is the same instant read from the other side.
  def outcome
    return :delivered if evidence?

    OUTCOMES.fetch(answer.exchange_status, :pending)
  end

  # The contract itself refusing to answer — an exchange it does not know, the
  # feature switch closed. Distinguished from every outcome above: nothing is
  # known of the exchange, which is not the same as knowing it went nowhere.
  def unreadable? = !answer.readable?

  def refusal = answer.error

  def secure_preview? = preview_location.to_s.match?(SECURE_PREVIEW)

  private

  attr_reader :answer, :request
end
