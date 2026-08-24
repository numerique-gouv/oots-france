Rails.application.routes.draw do
  root 'accueil#index'

  # The probe continuous integration polls, once it has started the compose
  # stack, to learn when the application answers.
  get '/up', to: 'rails/health#show', as: :rails_health_check

  get '/auth/cles_publiques', to: 'auth#cles_publiques'

  # The path is the one the procedures already call; it has no reason to change
  # because the implementation behind it does.
  get '/requete/pieceJustificative', to: 'evidence_requests#create'

  # The exchange settles afterwards, on another connection: the procedure reads
  # back here the state of the exchange whose identifier it was given. The
  # route is greedy: whatever must live under /requete is declared before it.
  get '/requete/:exchange_id', to: 'evidence_requests#show', as: :exchange

  # Domibus is the caller, and it calls from the network: the route is
  # authenticated.
  post '/domibus/notifications', to: 'domibus_notifications#create'

  namespace :admin do
    root to: 'home#show'
    resource :session, only: %i[new create destroy]

    # The log is walked through its events: what one exchange adds up to is
    # read on its own page, under `/admin/journal/exchanges`, which both
    # directions feed.
    namespace :journal do
      root to: 'events#index'
      resource :subjects, only: :show
      resources :events, only: :show
      resources :exchanges, only: %i[index show]
    end

    # The pages carry short identifiers only — a procedure code, the last
    # segment of a Semantic Repository URL. The whole identifier names a
    # different host in acceptance and in production.
    namespace :common_services do
      root to: 'catalogue#show'
      # What a country draws from a procedure is a page of its own, and not a
      # filter: a procedure imposes the same requirements nowhere. It is reached
      # by two paths, which show the same thing and each of which keeps its own
      # breadcrumb — one descends from a procedure to a country, or the reverse,
      # and the path walked is not rewritten along the way.
      resources :procedures, only: %i[index show], param: :code do
        get 'countries/:country_code', to: 'procedures#country', as: :country
      end
      # A country has no page of its own: it has two roles, and each has one.
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
