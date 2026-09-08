# Publishes the public half of the key a service provider encrypts the
# beneficiary token for.
class AuthController < ApplicationController
  def cles_publiques = render(json: PublicKeySet.new(Settings.private_key_jwk).to_h)
end
