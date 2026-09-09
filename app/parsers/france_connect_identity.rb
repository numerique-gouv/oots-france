# From the claims FranceConnect+ issues to the identity the demonstration holds.
#
# Two sources and not one: the ID Token attests the authentication — its level,
# its provenance, the pseudonym — where the UserInfo response carries the
# attributes the requested scopes cover. The portal publishes them apart, and
# reading them apart is what lets the two be checked against each other.
class FranceConnectIdentity
  # The ACR values FranceConnect+ maps the eIDAS levels onto, in increasing
  # order, and what each one is called in `LevelsOfAssurance-CodeList`. `eidas1`
  # is absent because the portal refuses it, and a European identity reaches it
  # at substantial or high and nowhere else.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-eidas-acr/
  LEVELS_OF_ASSURANCE = { 'eidas2' => 'Substantial', 'eidas3' => 'High' }.freeze

  # The claim the eIDAS unique identifier would arrive in.
  #
  # **Not documented by FranceConnect+**: « Données d'identité d'un usager
  # européen » lists `sub`, `given_name`, `family_name`, `birthdate`,
  # `birthplace` and `gender`, and names no identifier at all. The name is the
  # `PersonIdentifier` attribute of the eIDAS minimum data set transposed into
  # the snake_case the portal writes its claims in, and it is to be confirmed
  # with the FranceConnect team along with the rest of the manual verification
  # on the sandbox — `docs/eidas_context.md` carries that check.
  #
  # Nothing sends it today, so the nominal path is an identity held without an
  # identifier, which chapter 2.1 §2.3.1.2 provides for. The reader exists so
  # that what does arrive is validated rather than carried into a request
  # `R-EDM-REQ-C040` (FATAL) would refuse. The `sub` never stands in for it: it
  # is a pseudonym of the portal, per service provider.
  PERSON_IDENTIFIER = 'person_identifier'.freeze

  # Whether the level actually reached is at least the one asked for, which
  # « il est de la responsabilité du fournisseur de service » to check.
  def self.reaches?(reached, requested)
    order = LEVELS_OF_ASSURANCE.keys
    reached_rank = order.index(reached)

    !reached_rank.nil? && reached_rank >= order.index(requested)
  end

  def initialize(id_token:, userinfo:, signed_id_token:)
    @id_token = id_token
    @userinfo = userinfo
    @signed_id_token = signed_id_token
  end

  def identity = Demo::UserIdentity.new(**attested, **declared)

  private

  attr_reader :id_token, :userinfo, :signed_id_token

  # What the authentication itself says, all of it read from the ID Token: the
  # level reached, the path taken, the pseudonym, and the token that ends the
  # session.
  def attested
    { level_of_assurance: LEVELS_OF_ASSURANCE[id_token['acr']], provenance:,
      subject: id_token['sub'], id_token: signed_id_token }
  end

  # The attributes themselves, all of them from the UserInfo response, named as
  # FranceConnect+ names them.
  def declared
    { given_name: userinfo['given_name'], family_name: userinfo['family_name'],
      birthdate: userinfo['birthdate'], gender: userinfo['gender'],
      place_of_birth: userinfo['birthplace'],
      eidas_identifier: userinfo[PERSON_IDENTIFIER].presence }
  end

  # An array of strings, which is what the claim is and what the portal's own
  # sources return — the page describing the European flow words it as a single
  # value. `Array()` reads both without inventing either.
  def provenance
    Array(id_token['amr']).find { |method| method == Demo::UserIdentity::EUROPEAN }
  end
end
