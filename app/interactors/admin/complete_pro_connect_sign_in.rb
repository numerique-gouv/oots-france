module Admin
  # The return from ProConnect, from the authorization code to the agent it
  # identifies, and whether the console admits them.
  #
  # Every check refuses the whole sign-in: a return that does not verify opens
  # nothing. The refusal of an agent whose address is outside the admitted
  # domains is a failure of its own — the sign-in did verify, and the agent is
  # told nominally why they are turned away — which carries the ID Token, so
  # that their ProConnect session can be ended with it.
  class CompleteProConnectSignIn < ApplicationInteractor
    def call
      refuse_announced_refusal
      check_state

      admit(identified_agent(client.exchange(context.code)))
    rescue ProConnectError, Faraday::Error => e
      refuse(e.message)
    end

    private

    def identified_agent(tokens)
      context.id_token = tokens.fetch('id_token')
      userinfo = token.userinfo_claims(*client.userinfo(tokens.fetch('access_token')))
      check_same_person(verified_id_token, userinfo)

      Agent.new(email: email(userinfo))
    end

    def verified_id_token = token.id_token_claims(context.id_token, nonce: expected[:nonce])

    # ProConnect filters nothing: « c'est à vous de vérifier si l'utilisateur
    # authentifié a le droit d'accéder à votre service », after the claims are
    # verified and on the server.
    # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/restriction_acces
    def admit(agent)
      context.agent = agent
      return if agent.admitted_by?(Settings.proconnect_agent_domains)

      fail_with_error(:agent_refused, errors: [agent.email], email: agent.email, id_token: context.id_token)
    end

    def client = context.client ||= ProConnectClient.new(instance: context.instance)

    def token = context.token ||= ProConnectToken.new(client:)

    def expected = context.expected.to_h.symbolize_keys

    # ProConnect sends the browser back with `error` in place of `code` when it
    # declines: the reason is its own, and goes to the log as it stands.
    def refuse_announced_refusal
      return if context.announced_error.blank?

      refuse(I18n.t('interactors.admin.complete_pro_connect_sign_in.refused_by_provider',
        error: context.announced_error, description: context.error_description.to_s))
    end

    # Absent or different, it is a return nothing in this session asked for.
    def check_state
      return if expected[:state].present? &&
                ActiveSupport::SecurityUtils.secure_compare(expected[:state].to_s, context.state.to_s)

      refuse(I18n.t('interactors.admin.complete_pro_connect_sign_in.unexpected_state'))
    end

    # « The sub Claim in the UserInfo Response MUST be verified to exactly match
    # the sub Claim in the ID Token; if they do not match, the UserInfo Response
    # values MUST NOT be used. »
    # https://openid.net/specs/openid-connect-core-1_0.html#UserInfoResponse
    def check_same_person(claims, userinfo)
      return if claims['sub'].present? && claims['sub'] == userinfo['sub']

      refuse(I18n.t('interactors.admin.complete_pro_connect_sign_in.subjects_differ'))
    end

    def email(userinfo)
      address = userinfo['email']
      return address if address.is_a?(String) && address.present?

      refuse(I18n.t('interactors.admin.complete_pro_connect_sign_in.no_email'))
    end

    def refuse(reason) = fail_with_error(:sign_in_failed, errors: [reason])
  end
end
