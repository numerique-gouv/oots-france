# The last connectivity test France ran from the console towards one party of
# the PMode: an eDelivery AS4 test message of chapter 4.7 §3.1, sent from
# `AP_FR_01`, and what the gateway said of it.
#
# Kept here and not read back from the gateway alone: Domibus erases its history
# of test messages towards a party each time its own console tests that party
# (`TestService.deleteSentHistory`), and never notifies anything about a test
# message. A test is not an exchange, and nothing here touches `exchanges` or
# the article 17 log.
class ConnectivityTest < ApplicationRecord
  PENDING = 'pending'.freeze
  ACKNOWLEDGED = 'acknowledged'.freeze
  REFUSED_FOR_CONFIGURATION = 'refused_for_configuration'.freeze
  FAILED = 'failed'.freeze
  NO_VERDICT = 'no_verdict'.freeze
  NOT_SUBMITTED = 'not_submitted'.freeze

  OUTCOMES = [PENDING, ACKNOWLEDGED, REFUSED_FOR_CONFIGURATION, FAILED, NO_VERDICT, NOT_SUBMITTED].freeze

  # The gateway does not retry a test message (`UpdateRetryLoggingService`), so
  # no single attempt lasts this long: a test still without a verdict by then
  # has none to wait for.
  VERDICT_DEADLINE = 15.minutes

  validates :party_name, :party_identifier, :party_identifier_type, :requested_at, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }

  scope :pending, -> { where(outcome: PENDING) }
  scope :awaiting_verdict, -> { pending.where.not(message_id: nil) }
  scope :overdue, -> { pending.where(requested_at: ...VERDICT_DEADLINE.ago) }

  # A new test towards `party`, replacing the last one; `nil` where one is
  # already pending, which a second click or « all » must not restart.
  #
  # The lock holds only a row that exists: two first requests for a party both
  # find none, and the second fails on the unique index of `party_name` — the
  # only guard of its uniqueness, a validation letting both through. It is then
  # replayed, finds the first one's pending test, and starts nothing.
  def self.request(party)
    attempts = 0
    begin
      transaction(requires_new: true) { restart(party) }
    rescue ActiveRecord::RecordNotUnique
      retry if (attempts += 1) < 2
      raise
    end
  end

  def self.restart(party)
    test = lock.find_by(party_name: party.name) || new(party_name: party.name)
    return if test.persisted? && test.pending?

    test.update!(
      party_identifier: party.identifier, party_identifier_type: party.identifier_type,
      outcome: PENDING, requested_at: Time.current, message_id: nil,
      error_code: nil, error_detail: nil, submission_refusal: nil, verdict_read_at: nil
    )
    test
  end

  private_class_method :restart

  def pending? = outcome == PENDING

  def recipient = EbmsIdentity.new(id: party_identifier, type_id: party_identifier_type)

  def submitted!(message_id) = update!(message_id:)

  def acknowledged! = settle!(ACKNOWLEDGED)

  # `error` is the last one the gateway recorded, or `nil` where it recorded
  # none.
  def failed!(error)
    outcome = error&.configuration_refusal? ? REFUSED_FOR_CONFIGURATION : FAILED

    settle!(outcome, error_code: error&.code, error_detail: error&.detail)
  end

  def no_verdict! = settle!(NO_VERDICT)

  # The code and the message of the gateway's fault where it gave one, its text
  # otherwise — a connection that failed, a fault naming no code.
  def not_submitted!(refusal = nil, code: nil, detail: nil)
    settle!(NOT_SUBMITTED, submission_refusal: refusal, error_code: code, error_detail: detail)
  end

  private

  # Only the request this copy was read for: a verdict read over the network
  # can come back after the test was settled and asked again, and must not
  # close the new request with the old message's outcome. False where it no
  # longer applies.
  def settle!(outcome, **details)
    read_for = [message_id, requested_at]

    with_lock do
      current = pending? && [message_id, requested_at] == read_for
      update!(outcome:, verdict_read_at: Time.current, **details) if current
      current
    end
  end
end
