module Demo
  # The return from FranceConnect+, from the authorization code to the identity
  # the demonstration holds.
  #
  # Everything that could make the identity not be the one this departure asked
  # for is checked here, and each check refuses the whole identification rather
  # than dropping what fails: a portal answers for the identity its request
  # carries (chapter 2.2 §2), and half an attested identity is not one.
  class CompleteIdentification < ApplicationInteractor
    def call
      refuse_announced_refusal
      check_state

      context.identity = identity_behind(client.exchange(context.code))
    rescue FranceConnectError, Faraday::Error => e
      refuse(e.message)
    end

    private

    def identity_behind(tokens)
      signed_id_token = token.signed(tokens.fetch('id_token'))
      claims = verified_id_token(signed_id_token)
      userinfo = token.open(client.userinfo(tokens.fetch('access_token')))
      check_same_person(claims, userinfo)

      accepted(claims, userinfo, signed_id_token)
    end

    def client = context.client ||= FranceConnectClient.new

    def token = context.token ||= FranceConnectToken.new(client:)

    def expected = context.expected.to_h.symbolize_keys

    # FranceConnect+ sends the browser back with `error` in place of `code` when
    # it declines: the reason is the portal's own, and is relayed rather than
    # replaced.
    def refuse_announced_refusal
      return if context.announced_error.blank?

      refuse(I18n.t('interactors.demo.complete_identification.refused_by_portal',
        error: context.announced_error, description: context.error_description.presence ||
          I18n.t('interactors.demo.complete_identification.no_description')))
    end

    # The departure this return belongs to. Absent, it is a return nothing in
    # this session asked for — a code replayed from history, or one someone else
    # obtained.
    def check_state
      return if expected[:state].present? && ActiveSupport::SecurityUtils.secure_compare(
        expected[:state].to_s, context.state.to_s
      )

      refuse(I18n.t('interactors.demo.complete_identification.unexpected_state'))
    end

    def verified_id_token(signed_id_token)
      claims = token.claims(signed_id_token, iss: client.issuer, verify_iss: true,
        aud: client.client_id, verify_aud: true)

      check_nonce(claims)
      check_level(claims)

      claims
    end

    def check_nonce(claims)
      return if expected[:nonce].present? && ActiveSupport::SecurityUtils.secure_compare(
        expected[:nonce].to_s, claims['nonce'].to_s
      )

      refuse(I18n.t('interactors.demo.complete_identification.unexpected_nonce'))
    end

    # « Il est de la responsabilité du fournisseur de service de s'assurer que le
    # niveau retourné est au moins égal ou supérieur à celui demandé. »
    def check_level(claims)
      return if FranceConnectIdentity.reaches?(claims['acr'], FranceConnectClient::REQUESTED_ACR)

      refuse(I18n.t('interactors.demo.complete_identification.level_too_low',
        reached: claims['acr'].presence || I18n.t('interactors.demo.complete_identification.no_level'),
        requested: FranceConnectClient::REQUESTED_ACR))
    end

    # The one use the pseudonym is put to: the two documents must speak of the
    # same person. It is never shown, and never stands in for an identifier.
    def check_same_person(claims, userinfo)
      return if claims['sub'].present? && claims['sub'] == userinfo['sub']

      refuse(I18n.t('interactors.demo.complete_identification.subjects_differ'))
    end

    def accepted(claims, userinfo, signed_id_token)
      identity = FranceConnectIdentity.new(id_token: claims, userinfo:, signed_id_token:).identity
      return identity if identity.valid?

      refuse(identity.errors.full_messages.join(', '))
    end

    def refuse(reason) = fail_with_error(:identification_refused, errors: [reason])
  end
end
