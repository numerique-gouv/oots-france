module Admin
  # Where an agent the guard admits, but whom nobody named administrator, lands
  # on opening the journal, the jobs or the access points: says who to ask.
  # « Afficher un message d'erreur explicite », « Donner une solution aux
  # utilisateurs bloqués » —
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/restriction_acces
  class RestrictedAccessController < BaseController
    def show
      render status: :forbidden
    end
  end
end
