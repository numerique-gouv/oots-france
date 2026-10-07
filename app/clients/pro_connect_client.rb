# ProConnect, as the administration space calls it to identify an agent: an
# OpenID Connect provider in Authorization Code Flow, known by its discovery
# document alone (`OpenidDiscovery`), so that the fake of the repository, the
# integration and the production are a change of `ProConnectInstance`.
# https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
class ProConnectClient
  include OpenidDiscovery

  # The address, and nothing else: the console asks an agent for nothing more.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/scope-claims
  SCOPES = 'openid email'.freeze

  # What `/token` must have answered for the exchange to have happened, checked
  # where it arrives rather than as a `KeyError` far from here.
  GRANTED = %w[access_token id_token].freeze

  def initialize(instance:, connection: nil)
    @instance = instance
    @connection = connection
  end

  delegate :client_id, to: :instance

  # Never derived from the request: ProConnect refuses an address it was not
  # declared, and these are the two the deployment declares to it.
  def redirect_uri = url_for(Rails.application.routes.url_helpers.admin_pro_connect_retour_connexion_path)

  def post_logout_redirect_uri
    url_for(Rails.application.routes.url_helpers.admin_pro_connect_retour_deconnexion_path)
  end

  # The six parameters and no seventh: « tout paramètre supplémentaire dans
  # l'URL génèrera une erreur Y000400 ».
  def authorization_url(state:, nonce:)
    with_query(endpoint('authorization_endpoint'), {
      response_type: 'code', client_id:, redirect_uri:, scope: SCOPES, state:, nonce:,
    })
  end

  # `client_secret_post`: the credentials travel in the body.
  def exchange(code)
    answer = post(endpoint('token_endpoint'), {
      grant_type: 'authorization_code', code:, redirect_uri:, client_id:, client_secret: instance.client_secret,
    })

    granted(answer.body)
  end

  # The body and the type it was answered with: ProConnect answers « soit un
  # JSON […] soit un JWT, signé », and only the `Content-Type` says which.
  def userinfo(access_token)
    answer = get(endpoint('userinfo_endpoint'), {}, 'Authorization' => "Bearer #{access_token}")

    [answer.body, answer.headers['content-type']]
  end

  def end_session_url(id_token_hint:, state:)
    with_query(endpoint('end_session_endpoint'), { id_token_hint:, state:, post_logout_redirect_uri: })
  end

  private

  # Read and never published: it carries the `client_secret`.
  attr_reader :instance

  def granted(body)
    tokens = ProConnectAnswer.object(JSON.parse(body), :grant)
    missing = GRANTED.reject { |name| tokens[name].is_a?(String) && !tokens[name].empty? }
    return tokens if missing.empty?

    raise ProConnectError, I18n.t('clients.pro_connect_client.incomplete_grant', names: missing.join(', '))
  rescue JSON::ParserError => e
    raise ProConnectError, I18n.t('clients.pro_connect_client.unreadable_grant', error: e.message)
  end

  def url_for(path) = "#{Settings.oots_france_url}#{path}"

  def discovery_error = ProConnectError

  def discovery_scope = 'pro_connect_client'

  def cache_namespace = 'pro_connect'

  def document(body) = ProConnectAnswer.object(JSON.parse(body), :discovery)
end
