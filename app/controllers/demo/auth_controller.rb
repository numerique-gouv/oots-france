module Demo
  # Where the demonstration procedure publishes the keys authenticating the
  # beneficiary token it signs — the mirror of `AuthController`, which publishes
  # what a service provider encrypts *for* this component.
  #
  # Under `/demo` and outside `/admin`, so it answers a caller holding no
  # session: OOTS-France reads it as it reads any requester's, by appending
  # `/auth/cles_publiques` to the URL `DONNEES_REQUETEURS` declares. A route the
  # operator's session guarded would refuse the very component that has to read
  # it.
  class AuthController < ApplicationController
    def cles_publiques
      render(json: PublicKeySet.new(Settings.demo_signing_key_jwk, use: PublicKeySet::SIGNATURE).to_h)
    end
  end
end
