Rails.application.routes.draw do
  root 'accueil#index'

  get '/auth/cles_publiques', to: 'auth#cles_publiques'

  # Le chemin est celui que les démarches appellent déjà ; il n'a pas de raison
  # de changer parce que l'implémentation, elle, change.
  get '/requete/pieceJustificative', to: 'evidence_requests#create'

  # L'échange se règle après coup, sur une autre connexion : la démarche relit
  # ici l'état de la conversation dont elle a reçu l'identifiant.
  get '/requete/:conversation_id', to: 'evidence_requests#show', as: :conversation

  # C'est Domibus qui appelle, depuis le réseau : la route est authentifiée.
  post '/domibus/notifications', to: 'domibus_notifications#create'
end
