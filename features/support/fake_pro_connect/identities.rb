module FakeProConnect
  # An agent the fake identifies: what a test identity provider of the
  # integration answers for whoever types an address there.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/identifiants-fi-test
  Identity = Data.define(:sub, :email, :given_name, :usual_name)

  # Two, and two only: one whose address is in the domain a development machine
  # admits, and one whose address is not — the two outcomes of a sign-in.
  module Identities
    ALL = [
      Identity.new(sub: 'faux-proconnect-camille-agent', email: 'camille.agent@numerique.gouv.fr',
        given_name: 'Camille', usual_name: 'Agent'),
      Identity.new(sub: 'faux-proconnect-camille-exterieure', email: 'camille.agent@exemple.fr',
        given_name: 'Camille', usual_name: 'Extérieure'),
    ].freeze

    def self.find(sub) = ALL.find { |identity| identity.sub == sub }
  end
end
