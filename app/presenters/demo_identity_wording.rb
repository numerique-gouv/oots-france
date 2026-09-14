# What the demonstration's form says of the identity FranceConnect+ attested.
#
# On the model of `DirectoryWording`: the screen's words, held where a spec of
# the view can reach them, and reading no request. It takes the identity rather
# than fetching it — the controller has already read the session.
#
# The values themselves are shown as they came: a name, a date, a place of birth
# are the portal's, and rewriting them would be asserting an identity nobody
# attested. Only what has no wording of its own is worded here — the sex, whose
# code is not a word.
class DemoIdentityWording
  def initialize(identity)
    @identity = identity
  end

  def gender
    return nil if identity.gender.blank?

    I18n.t("presenters.demo_identity.genders.#{identity.gender}")
  end

  def place_of_birth = identity.place_of_birth.presence

  private

  attr_reader :identity
end
