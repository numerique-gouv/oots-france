# What the demonstration's form says of the identity FranceConnect+ attested.
#
# On the model of `DirectoryWording`: the screen's words, held where a spec of
# the view can reach them, and reading no request. It takes the identity rather
# than fetching it — the controller has already read the session.
#
# The values themselves are shown as they came: a name, a date, a place of birth
# are the portal's, and rewriting them would be asserting an identity nobody
# attested. Only what has no wording of its own is worded here — the sex, whose
# code is not a word, the provenance, which no claim spells out, and the absence
# of an identifier, which is a sentence rather than an empty cell.
class DemoIdentityWording
  def initialize(identity)
    @identity = identity
  end

  def gender
    return nil if identity.gender.blank?

    I18n.t("presenters.demo_identity.genders.#{identity.gender}")
  end

  # No claim names the country or the foreign identity provider, so neither is
  # named: what is attested is that the identity came through the eIDAS bridge.
  def provenance
    return I18n.t('presenters.demo_identity.provenance.european') if identity.european?

    I18n.t('presenters.demo_identity.provenance.unnamed')
  end

  # Said rather than left blank: FranceConnect+ documents no claim carrying the
  # eIDAS unique identifier of a European user, and chapter 2.1 §2.3.1.2
  # provides for a request that carries none. An empty line would read as an
  # oversight where this is the expected case.
  def eidas_identifier
    identity.eidas_identifier.presence || I18n.t('presenters.demo_identity.no_identifier')
  end

  def place_of_birth = identity.place_of_birth.presence

  private

  attr_reader :identity
end
