# One interactive preview of chapter 4.9 §2, provider side: the address France
# issued with its `EDM:ERR:0002`, what it keeps to answer the second request
# the way the user decides, and where the user is at.
#
# The only record of this side that keeps a subject, because the chapter asks
# for it: the document the user sees must be the one the answer carries
# (§3), and `retention_downloaded="0"` erases a request from the gateway the
# instant it is read. What carries the subject is encrypted like
# `AuditEvent#evidence_subject` and emptied once nothing remains to answer; the
# rest — the address, where the user is at, where to send them back — is
# destroyed at T2 + T3, after which the address is one France never issued.
class PreviewSession < ApplicationRecord
  # The two answers chapter 4.9 §1 offers the user for each piece of evidence.
  ACCEPTED = 'accepted'.freeze
  REFUSED = 'refused'.freeze
  DECISIONS = [ACCEPTED, REFUSED].freeze

  # `pending` until the user decides, `decided` until the answer has gone,
  # then `answered`; `expired` where T2 or T3 ran out first.
  STATUSES = %w[pending decided answered expired].freeze
  HOLDING = %w[pending decided].freeze

  SUBJECT = %i[first_request second_request second_message_id document evidence_id evidence_issued_at decision].freeze

  encrypts(*SUBJECT)

  attribute :specification, EdmSpecification::Type.new

  validates :token, :location, :exchange_id, :conversation_id, :specification, :issued_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :decision, inclusion: { in: DECISIONS }, allow_nil: true

  # T2 of chapter 4.4 §4.4.3, counted from the issue: neither visited in time
  # nor joined by a second request.
  scope :past_redirection, lambda {
    where(status: HOLDING, second_request_sent_at: nil, issued_at: ...Settings.preview_redirection_timeout.ago)
  }

  # T3, counted from the ebMS stamp of the second request as T1 is from the
  # first (chapter 4.10 §6.1), with the user still to decide.
  scope :past_decision, -> { where(status: 'pending', second_request_sent_at: ...Settings.preview_decision_timeout.ago) }

  scope :past_retention, -> { where(issued_at: ...retention.ago) }

  # The row an answer is held on, which the expiry sweep of T1 must leave be.
  scope :holding, -> { where(status: HOLDING).where.not(answering_exchange_id: nil) }

  def self.retention = Settings.preview_redirection_timeout + Settings.preview_decision_timeout

  def self.location_for(token) = "#{Settings.oots_france_url}/previsualisation/#{token}"

  # `exchange_id` names the row the first request opened: on the 1.2 line, one
  # France minted, the header carrying none.
  def self.issue(token:, exchange_id:, conversation_id:, specification:, first_request:, document:, evidence_id:,
                 evidence_issued_at:)
    create!(
      token:, location: location_for(token), issued_at: Time.current,
      exchange_id:, conversation_id:, specification:, first_request:,
      document: Base64.strict_encode64(document), evidence_id:, evidence_issued_at: evidence_issued_at.iso8601(6)
    )
  end

  def document_bytes = document && Base64.strict_decode64(document)

  def evidence_instant = evidence_issued_at && Time.zone.iso8601(evidence_issued_at)

  def pending? = status == 'pending'

  def decided? = status == 'decided'

  def answered? = status == 'answered'

  # Chapter 4.9 §2, step 14: the link expires with T2 where no second request
  # came, with T3 where the user has not decided since it did.
  def expired?
    return true if status == 'expired'
    return issued_at < Settings.preview_redirection_timeout.ago if second_request_sent_at.nil? && status.in?(HOLDING)

    pending? && second_request_sent_at < Settings.preview_decision_timeout.ago
  end

  # Chapter 4.9 §4: a first visit within T2, a revisit until expiry, and no
  # interaction once the choice has been made.
  def openable?
    pending? && !expired? && (first_visited_at.present? || issued_at >= Settings.preview_redirection_timeout.ago)
  end

  # Chapter 4.9 §2, step 12, and 4.7 §2.5.2: the second request names an
  # address still waiting for its answer, under the same `ExchangeId` on the
  # line that carries one. On 1.2 the address alone ties the two.
  def continued_by?(carried_exchange_id)
    return false if answered?

    !specification.exchange_named_in_header? || carried_exchange_id == exchange_id
  end

  def holds?(message_id) = second_message_id.present? && second_message_id == message_id

  def visited!
    update!(first_visited_at: Time.current) if first_visited_at.nil?
  end

  def remember_return!(location, method)
    update!(return_location: location, return_method: method)
  end

  # The second request is kept, and the decision read, under the lock
  # `decide!` takes: whichever comes second answers, and only one does.
  def hold!(raw:, sent_at:, message_id:, answering:, return_location:)
    with_lock do
      unless holds?(message_id)
        update!(second_request: raw, second_message_id: message_id, second_request_sent_at: sent_at,
          answering_exchange_id: answering&.exchange_id, return_location: return_location || self.return_location)
      end

      decision
    end
  end

  # Nil when the choice can no longer be made; otherwise whether the second
  # request is waiting on it, and has then to be answered.
  def decide!(accepted:)
    with_lock do
      return nil unless openable?

      update!(decision: accepted ? ACCEPTED : REFUSED, status: 'decided')
      second_request.present?
    end
  end

  def conclude!
    update!(status: expired? ? 'expired' : 'answered', **SUBJECT.index_with(nil))
  end

  # What the answer to a second request still needs is kept until it is sent,
  # the timeout exception of step 14 answering it too.
  def expire!
    with_lock do
      next false unless expired? && status.in?(HOLDING)

      kept = second_request.present? ? %i[second_request second_message_id] : []
      update!(status: 'expired', **(SUBJECT - kept).index_with(nil))
    end
  end
end
