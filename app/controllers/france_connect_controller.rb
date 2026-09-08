# The three addresses of the demonstration procedure FranceConnect+ is given,
# and the only part of this application it reads or sends a user to.
# `docs/eidas_context.md` says why they answer to a caller holding no session.
#
# Whatever eventually happens on the two return pages is OOTS-179; that they
# answer at all is what lets the addresses be declared.
class FranceConnectController < ApplicationController
  # The « Client keys url » of the demonstration procedure. Distinct from the
  # key of `/auth/cles_publiques`, which opens the beneficiary token of a French
  # service provider — `Settings.france_connect_private_key_jwk` says why.
  def cles_publiques = render(json: PublicKeySet.new(Settings.france_connect_private_key_jwk).to_h)

  def retour_connexion; end

  def retour_deconnexion; end
end
