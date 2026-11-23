# Whether France's preview space lets a browser through without identifying
# again. Chapter 4.9 §1 leaves the re-authentication to the provider — « This
# is an implementation and/or policy decision » — and, the type asked for aside
# (`ServedEvidenceType.reauthentication_waived?`, which waives it for whoever
# opens the address and is decided before this is asked), this deployment
# waives it in one case: the demonstration procedure, identified by the fake
# FranceConnect+, opening the preview of its own request on a deployment that
# re-authenticates by the real one, whose sandbox knows none of the fake's
# identities.
#
# The request must be one the procedure made in this browser's journey: the
# fake accepts an identity typed by hand, and the subject's name and birth date
# alone would otherwise open the preview of a request someone else made. And
# the identity must still be the subject of the request, as step 18 checks of
# a re-authentication (`IdentityMatch`).
class PreviewDispensation
  # The name `Settings::FRANCE_CONNECT` declares the fake FranceConnect+ under.
  FAKE = 'fake'.freeze

  # `identity`: the `Demo::UserIdentity` the browser holds, or `nil`.
  # `journey`: the `Demo::Journey` its session holds, or `nil`.
  # `beneficiary`: the subject the first request names.
  # `instance`: the FranceConnect+ the space would send the browser to.
  def initialize(identity:, journey:, preview_session:, beneficiary:, instance:)
    @identity = identity
    @journey = journey
    @preview_session = preview_session
    @beneficiary = beneficiary
    @instance = instance
  end

  attr_reader :identity

  def granted?
    attested_by_the_fake? && reauthenticates_elsewhere? && requested_in_this_journey? &&
      IdentityMatch.new(identity, beneficiary).match?
  end

  private

  attr_reader :journey, :preview_session, :beneficiary, :instance

  def attested_by_the_fake? = identity&.valid? && identity.france_connect == FAKE

  def reauthenticates_elsewhere? = instance.present? && instance.name != FAKE

  def requested_in_this_journey?
    journey&.valid? && Demo::Request.previewed_at(journey_id: journey.id, location: preview_session.location).exists?
  end
end
