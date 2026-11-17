# An identity, as a page shows it to the user it describes: on the
# demonstration procedure, the one the authentication attested, as the last page
# before an exchange; on the preview space, the one the registry wrote into the
# evidence (chapter 4.10 §5.1, step 20).
#
# Every attribute is shown and none is offered as a field: on the demonstration
# procedure, chapter 2.2 §2 makes the portal answerable for the identity in the
# request matching the one the eID means yielded.
#
# Where the source yields them, the card sets apart by its shape rather than by
# a second heading what the authentication adds to the civil identity: under a
# rule, in the mention register, the level it reached and the eIDAS identifier,
# in grey at the far end of the same line — what the request will carry, not
# what the user recognises themself by. The registry yields neither.
#
# An attribute the source does not carry has no row: an empty value would read
# as one held blank. The country an attested identity comes from never appears,
# because no claim names it.
class IdentityCardComponent < ViewComponent::Base
  # The identity alone: what a screen says of it is derived from it here rather
  # than beside it, so that no caller can hand the card two objects describing
  # two different people.
  #
  # `labels`: what a caller names an attribute where its source names it
  # otherwise — the registry's « nom de naissance » is not the « nom » an
  # authentication yields.
  def initialize(identity:, labels: {})
    @identity = identity
    @wording = IdentityWording.new(identity)
    @labels = labels
    super()
  end

  def civil
    filled(
      family_name: identity.family_name,
      given_name: identity.given_name,
      birthdate: identity.birthdate,
      place_of_birth: wording.place_of_birth,
      gender: wording.gender,
    )
  end

  # A badge rather than a row: it is the one value of the card a correspondent
  # weighs rather than reads — chapter 2.1 §2.1 has the level of assurance of
  # the eID means « included in the evidence request », and §1 has each evidence
  # type registered in the Data Service Directory carry the level it asks for —
  # and a badge is what the DSFR gives a value read at a glance.
  def level = identity.level_of_assurance.presence

  def level_label = t('components.identity_card.attributes.level_of_assurance')

  def eidas_identifier
    value = identity.eidas_identifier.presence
    t('components.identity_card.eidas_identifier_html', value:) if value
  end

  private

  attr_reader :identity, :wording, :labels

  def filled(attributes)
    attributes.filter_map do |name, value|
      [labels.fetch(name) { t("components.identity_card.attributes.#{name}") }, value] if value.present?
    end
  end
end
