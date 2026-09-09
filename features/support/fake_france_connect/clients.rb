module FakeFranceConnect
  # A service provider declared to the fake, with what FranceConnect+ holds of
  # one: the addresses it may be sent back to, and the scopes it may ask for.
  #
  # `client_id` and `client_secret` are the fake's own constants and not
  # environment variables: they are the demonstration procedure's credentials,
  # and it is OOTS-179 that will have `app/` read them. Declaring the variables
  # now would be building for a caller that does not exist.
  Client = Data.define(:id, :secret, :redirect_uris, :post_logout_redirect_uris, :scopes) do
    def declares_redirect?(uri) = redirect_uris.include?(uri)

    def declares_post_logout_redirect?(uri) = post_logout_redirect_uris.include?(uri)

    def grants?(requested) = (requested - scopes).empty?
  end

  # The two clients, and two rather than one: the second exists so that the
  # same identity can be shown to yield a different `sub` under another
  # `client_id`, which is what makes the pseudonym per service provider.
  module Clients
    SCOPES = %w[openid given_name family_name birthdate gender birthplace preferred_username profile].freeze

    PRIMARY_ID = 'oots-france-demarche'.freeze
    SECONDARY_ID = 'oots-france-demarche-secondaire'.freeze

    SECRETS = {
      PRIMARY_ID => 'faux-france-connect-secret-de-la-demarche',
      SECONDARY_ID => 'faux-france-connect-secret-du-second-client',
    }.freeze

    # The three addresses `config/routes.rb` already declares for FranceConnect+.
    # Reading them off the procedure's own base URL is what makes swapping the
    # fake for the sandbox a change of environment and of nothing else.
    def self.all(procedure_url)
      SECRETS.map do |id, secret|
        Client.new(id: id, secret: secret, scopes: SCOPES,
          redirect_uris: ["#{procedure_url}/demo/franceconnect/retour_connexion"],
          post_logout_redirect_uris: ["#{procedure_url}/demo/franceconnect/retour_deconnexion"])
      end
    end
  end
end
