Rails.application.routes.draw do
  root 'accueil#index'

  # La sonde que l'intégration continue interroge, après avoir démarré la
  # composition, pour savoir quand l'application répond.
  get '/up', to: 'rails/health#show', as: :rails_health_check

  get '/auth/cles_publiques', to: 'auth#cles_publiques'

  # Le chemin est celui que les démarches appellent déjà ; il n'a pas de raison
  # de changer parce que l'implémentation, elle, change.
  get '/requete/pieceJustificative', to: 'evidence_requests#create'

  # L'échange se règle après coup, sur une autre connexion : la démarche relit
  # ici l'état de la conversation dont elle a reçu l'identifiant. La route est
  # gloutonne : tout ce qui doit vivre sous /requete se déclare avant elle.
  get '/requete/:conversation_id', to: 'evidence_requests#show', as: :conversation

  # C'est Domibus qui appelle, depuis le réseau : la route est authentifiée.
  post '/domibus/notifications', to: 'domibus_notifications#create'

  namespace :admin do
    root to: 'home#show'
    resource :session, only: %i[new create destroy]
    resources :conversations, only: %i[index show]

    # Les pages ne portent que des identifiants courts — un code de démarche,
    # le dernier segment d'une URL du Semantic Repository. L'identifiant entier
    # nomme un hôte différent en acceptation et en production.
    namespace :common_services do
      root to: 'catalogue#show'
      # Ce qu'un pays tire d'une démarche est une page à soi, et non un filtre :
      # une démarche n'impose les mêmes exigences nulle part. Elle s'atteint par
      # deux chemins, qui montrent la même chose et dont chacun garde son fil
      # d'Ariane — on descend d'une démarche vers un pays, ou l'inverse, et le
      # chemin parcouru ne se réécrit pas en cours de route.
      resources :procedures, only: %i[index show], param: :code do
        get 'countries/:country_code', to: 'procedures#country', as: :country
      end
      # Un pays n'a pas de page à lui : il a deux rôles, et chacun la sienne.
      resources :countries, only: :index, param: :code do
        get 'procedures', to: 'countries#procedures'
        get 'procedures/:procedure_code', to: 'countries#procedure', as: :procedure
        get 'requirements', to: 'countries#requirements'
      end
      resource :resolution, only: :show
      resources :requirements, only: %i[index show] do
        get 'procedures', to: 'requirements#procedures'
        get 'countries/:country_code', to: 'requirements#country', as: :country
        get 'evidence_types/:id/providers', to: 'providers#index', as: :evidence_type_providers
      end
    end
  end

  mount GoodJob::Engine => '/admin/jobs', as: :admin_jobs
end
