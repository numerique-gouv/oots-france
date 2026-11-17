# What the identity card says of an identity: the one FranceConnect+ attested on
# the demonstration procedure, the one the registry wrote on the preview space.
#
# On the model of `DirectoryWording`: the screen's words, held where a spec of
# the view can reach them, and reading no request. It takes the identity the
# caller already holds.
#
# The values themselves are shown as their source wrote them: rewriting them
# would be asserting an identity nobody attested. Only what has no wording of
# its own is worded here — the sex, whose code is not a word.
class IdentityWording
  def initialize(identity)
    @identity = identity
  end

  def gender
    return nil if identity.gender.blank?

    I18n.t("presenters.identity.genders.#{identity.gender}")
  end

  def place_of_birth = identity.place_of_birth.presence

  private

  attr_reader :identity
end
