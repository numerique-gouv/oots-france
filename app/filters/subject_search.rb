# The three fields a canonical subject key is built from, as a form submits them.
#
# Three exact fields and not a search bar: `evidence_subject_key` is encrypted
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

  # A string, so that the key composes exactly as `NaturalPerson` wrote it — and
  # validated for it, because this is the one field whose wrong format yields a
  # wrong answer rather than an error: `25/11/1965` composes a key that matches
  # nobody, and the page would say so as if the person had never been asked about.
  validates :date_of_birth,
    format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: :format },
    allow_blank: true

  # All three or none: the key is the whole of a person, and a search missing
  # one field is a search nobody made.
  def complete? = attributes.values.all?(&:present?)

  def key = AuditEvent.subject_key(**attributes.symbolize_keys)

  # Whether a question was actually put to the journal. The page needs it as
  # much as the query does: « aucun échange ne concerne cette personne » is a
  # statement about the person, and it must not be made about a search that
  # never ran — a criterion lost on the way in leaves the three fields filled.
  def searched? = valid? && complete?

  def events
    return AuditEvent.none unless searched?

    AuditEvent.about_subject(key)
  end
end
