Rails.application.routes.draw do
  root 'accueil#index'

  # The probe continuous integration polls, once it has started the compose
  # stack, to learn when the application answers.
  get '/up', to: 'rails/health#show', as: :rails_health_check

  get '/auth/cles_publiques', to: 'auth#cles_publiques'

  # The addresses of the demonstration procedure, outside `/admin` and so
  # outside what `AdminAuthentication` closes. `docs/eidas_context.md` says why
  # the three FranceConnect+ ones answer publicly.
  #
  # The fourth is what makes the procedure a requester like any other: OOTS-France
  # reads a requester's signing keys under the URL `DONNEES_REQUETEURS` declares
  # for it, and the procedure declares `<URL_OOTS_FRANCE>/demo`.
  scope :demo, as: :demo do
    get 'auth/cles_publiques', to: 'demo/auth#cles_publiques'
    get 'franceconnect/cles_publiques', to: 'france_connect#cles_publiques'
    get 'franceconnect/retour_connexion', to: 'france_connect#retour_connexion'
    get 'franceconnect/retour_deconnexion', to: 'france_connect#retour_deconnexion'

    # Where the evidence is delivered to the procedure. `EvidenceForwarder`
    # appends this path to the URL a requester publishes, and carries on it the
    # two identifiers chapter 4.4 §4.3.2 defines; it is
    # therefore the address of a service provider's server, and no more part of
    # the console than the four above.
    post 'oots/document', to: 'demo/evidence_deliveries#create'
  end

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

    # The demonstration procedure: the front half of an Online Procedure Portal,
    # played by the operator. It is the one corner of the console that does not
    # observe an exchange — `docs/espace_administration.md` says why it is
    # nonetheless here.
    namespace :demo do
      root to: 'home#show'
      # `create` and not `show`: starting the European flow writes the `state`
      # and the `nonce` its return is checked against, which a prefetched or
      # replayed GET would overwrite.
      resource :identification, only: :create
      # The form the user comes back to, identified. Named in French like the
      # other paths of this repository, and carried by an English class.
      #
      # `create` is where the explicit request of chapter 1 §3.3 is read: given,
      # it leads to the confirmation; withheld, it leads nowhere and nothing is
      # asked of anyone.
      resource :demande, only: %i[show create], controller: 'grant_requests'
      # The last page before an exchange exists. `show` names the provider and
      # the evidence type the directories resolve, which requirement 27 of
      # chapter 1 asks for « before any request is made » ; `create` **is** the
      # explicit request, and the request leaves as it is pressed — chapter
      # 4.5.1 §2.7 ties `IssueDateTime` to that instant.
      resource :confirmation, only: %i[show create], controller: 'confirmations'
      # Where the journey ends, and the only page of it that may be reloaded at
      # will: chapter 4.4 §4.1 requires a new request for a new answer, so this
      # one reads and never asks.
      resource :suivi, only: :show, controller: 'trackings'
      # The evidence itself, under the page that offers it rather than beside
      # it: nothing reaches it without the exchange that page is following.
      get 'suivi/justificatif', to: 'evidences#show', as: :suivi_justificatif
    end

    # The log is walked through its events, and only through them: the listing
    # is the one at the root, narrowed by whichever identifier one holds. An
    # exchange and a conversation have a page each, reached from an event —
    # they group these events, and neither is a listing one starts from.
    namespace :journal do
      root to: 'events#index'
      resource :subjects, only: :show
      resources :events, only: :show
      resources :exchanges, only: :show
      resources :conversations, only: :show
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
