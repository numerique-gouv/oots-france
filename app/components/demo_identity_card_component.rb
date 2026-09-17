# The identity the authentication attested, as the last page before an exchange
# shows it to the user it describes.
#
# Chapter 2.2 §2 makes the portal answerable for the identity in the request
# matching the one the eID means yielded, so every attribute is shown and none
# is offered as a field.
#
# They are not all of one kind, and the card says so by its shape rather than by
# a second heading: the civil identity is what the user recognises themself by,
# and under a rule, in the mention register, the one thing the authentication
# adds to it — the level it reached.
#
# An attribute the authentication did not yield has no row: an empty value would
# read as one the portal holds blank. Two never appear at all, whatever they
# hold. The eIDAS identifier, because a portal has no reason to show its user a
# technical identifier they cannot act on — `NaturalPerson` still carries it
# into the request wherever one is held, and FranceConnect+ documents no claim
# carrying it for a European user anyway. The country the identity comes from,
# because no claim names it: all that could be said is that the user came
# through the European flow, which is what they clicked a button to do.
class DemoIdentityCardComponent < ViewComponent::Base
  # The identity alone: what a screen says of it is derived from it here rather
  # than beside it, so that no caller can hand the card two objects describing
  # two different people.
  def initialize(identity:)
    @identity = identity
    @wording = DemoIdentityWording.new(identity)
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

  def level_label = t('components.demo_identity_card.attributes.level_of_assurance')

  private

  attr_reader :identity, :wording

  def filled(attributes)
    attributes.filter_map do |name, value|
      [t("components.demo_identity_card.attributes.#{name}"), value] if value.present?
    end
  end
end
