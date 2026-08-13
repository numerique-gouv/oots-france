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
    resources :conversations, only: %i[index show]
  end

  mount GoodJob::Engine => '/admin/jobs', as: :admin_jobs
end
