# The French service provider asking for a piece of evidence — C1 of the
# four-corner model, on whose behalf the Evidence Requester issues the request.
#
# It also carries the URL where its own JWKS lives: the beneficiary token is
# signed by the requester, so its public keys have to be fetched from it.
class EvidenceRequester
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  REQUESTER = 'ER'.freeze
  INTERMEDIARY_PLATFORM = 'IP'.freeze

  attribute :id, :string
  attribute :name, :string
  attribute :url, :string
  attribute :type_id, :string
  attribute :language, :string

  attr_accessor :address

  validates :id, presence: true

  def initialize(attributes = {})
    @address = attributes.delete(:address) || Address.new
    super
  end

  # A named constructor, and not a default in `initialize`: the same class is
  # built from foreign messages, where a missing `schemeID` would then relabel
  # a foreign party as a French SIRET holder — a *valid* identity, which
  # nothing downstream catches before it travels back out.
  def self.french(id:, name:, url: nil)
    new(id:, name:, url:, type_id: IdentifierScheme::FRENCH, language: 'FR')
  end

  # OOTS-France declares itself as a second agent on every request it relays.
  # It has no SIRET of its own, hence the fallback scheme.
  def self.intermediary_platform
    new(
      id: 'OOTSFRANCE',
      name: 'OOTS-France Intermediary Platform',
      type_id: IdentifierScheme::FRENCH_FALLBACK,
      language: 'EN',
    )
  end

  def ebms_identity = EbmsIdentity.new(id:, type_id:)

  def jwks_url = "#{url}/auth/cles_publiques"
end
