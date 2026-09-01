# The subject the journal is questioned about, as a form submits it: the three
# fields of a natural person, or the eIDAS identifier of an organisation — the
# two subjects chapter 4.5.1 allows.
#
# Exact fields and not a search bar: `evidence_subject_key` is encrypted
# deterministically, which makes equality queryable and nothing else — no
# prefix, no fragment, no "every Dupont". Searching on a part would take a
# second deterministic column, so a wider equality leak.
class SubjectSearch
  include ActiveModel::Model
  include ActiveModel::Attributes
  include SubmittedCriteria

  attribute :family_name, :string
  attribute :given_name, :string
  attribute :date_of_birth, :string
  # Chapter 4.5.1's own name for the identifier, and deliberately not
  # `eidas_identifier`: a natural person carries one too, so a shared name would
  # let one address fill both forms of the page.
  attribute :legal_person_identifier, :string

  # The writing chapter 4.5.1 gives the slot, which is what the journal composed
  # its key from.
  ISO_DATE = /\A(\d{4})-(\d{2})-(\d{2})\z/

  validate :reject_unreadable_date_of_birth
  validate :reject_both_identities

  def person = attributes.symbolize_keys.slice(*AuditEvent::SUBJECT_FIELDS)

  # All three or none: the key is the whole of a person, and a search missing
  # one field is a search nobody made.
  def complete_person? = person.values.all?(&:present?)

  def organisation? = legal_person_identifier.present?

  # One identity or the other, never both and never neither.
  def complete? = complete_person? ^ organisation?

  def key
    return AuditEvent.subject_key(**person) if complete_person?

    AuditEvent.legal_subject_key(eidas_identifier: legal_person_identifier)
  end

  # Whether a question was actually put to the journal. The page needs it as
  # much as the query does: « aucun événement ne concerne ce sujet » is a
  # statement about the subject, and it must not be made about a search that
  # never ran — a criterion lost on the way in leaves the fields filled.
  def searched? = valid? && complete?

  # Which of the two forms was submitted, so the results name the subject they
  # are about instead of « ce sujet » — the vocabulary of the two legends and of
  # the button the event page arrives by. Only asked once `searched?` holds:
  # neither form filled is a question about nobody.
  def subject_kind = complete_person? ? :person : :organisation

  def events
    return AuditEvent.none unless searched?

    AuditEvent.about_subject(key)
  end

  private

  # The one field whose wrong writing yields a wrong answer rather than an
  # error: `25/11/1965` composes a key that matches nobody, and the page would
  # say so as if the person had never been asked about.
  #
  # The organisation's identifier needs no such rule: it has one writing, the
  # one that arrived, and the case is folded away — so « aucun événement » is
  # the true answer to an identifier nothing carries.
  def reject_unreadable_date_of_birth
    return if date_of_birth.blank? || iso_date?

    errors.add(:date_of_birth, :format)
  end

  # The shape and the calendar both, neither being enough alone: `1990-13-32`
  # has the shape and is no date, and each composes a key matching nobody.
  def iso_date?
    year, month, day = ISO_DATE.match(date_of_birth)&.captures

    year.present? && Date.valid_date?(year.to_i, month.to_i, day.to_i)
  end

  # Two forms on one page are one query string, so a forged address can carry
  # both identities. Refused rather than arbitrated, in the spirit of
  # `SubmittedCriteria`: honouring one and dropping the other would answer a
  # question nobody asked, under a heading claiming the opposite.
  def reject_both_identities
    return unless organisation? && person.values.any?(&:present?)

    errors.add(:base, :both_identities)
  end
end
