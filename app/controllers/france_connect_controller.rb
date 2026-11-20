# The three addresses of the demonstration procedure FranceConnect+ is given,
# and the only part of this application it reads or sends a user to.
# `docs/eidas_context.md` says why they answer to a caller holding no session.
class FranceConnectController < ApplicationController
  include ChosenLanguage
  include DemoIdentityCookie
  include RecognisesAdministrator
  include RefusesIdentification

  # The « Client keys url » of the demonstration procedure. Distinct from the
  # key of `/auth/cles_publiques`, which opens the beneficiary token of a French
  # service provider — `Settings.france_connect_private_key_jwk` says why.
  def cles_publiques = render(json: PublicKeySet.new(Settings.france_connect_private_key_jwk).to_h)

  # Redirects rather than renders, whichever way it goes: an authorization code
  # is single use, and leaving in the history a page that carries one invites
  # replaying it.
  #
  # Identifying opens a journey, and the requests the session was following
  # belonged to the one before: the new journey has an identifier of its own, so
  # every zone offers the button again rather than the document the previous
  # journey obtained. The conversation is not dropped with it — chapter 4.4
  # §4.3.2 has it « SHOULD be reused for combined flows » and forbids reuse only
  # « if the user authenticates with a different identity », which `Demo::Journey`
  # compares before carrying it over.
  #
  # This is the one place the journey is written, and the instant the identity
  # exists is the earliest it could be: the conversation « Identifies a single
  # uniquely authenticated user » (chapter 4.4 §4.3.2), which nothing posted
  # before the authentication could claim to do. A click writes nothing further.
  #
  # The journey plays the line and the procedure of the sign-in page the flow
  # left from, under its entrance, which the departure kept with the `state`:
  # these addresses are declared to FranceConnect+ once and for all, and name
  # none of the three.
  def retour_connexion
    expected = session.delete(:france_connect)
    specification, procedure, entrance = departed_walk(expected)
    result = completed_identification(expected)

    return refuse_identification(result, version: specification&.segment, procedure:, entrance:) unless result.success?
    return refuse_incomplete_departure(entrance) if specification.nil? || procedure.nil?

    open_journey(result.identity, specification, procedure, entrance)

    redirect_to demo_path(:documents, entrance:, version: specification.segment, procedure:)
  end

  # A page, where the other return is a redirection: after the console's
  # sign-out FranceConnect+ brings back here a user with no session left, and
  # there is nothing to send them on to. After the identity card's, the console
  # is still open, and the agent goes back to the home of the procedure they
  # left — once the `state` says the return is that sign-out's.
  def retour_deconnexion
    expected = session.delete(:france_connect_logout)
    home = session.delete(:france_connect_logout_home)

    @acknowledged = expected.present? && params[:state] == expected
    return unless @acknowledged && home

    redirect_to home, notice: :'controllers.france_connect.signed_out'
  end

  private

  # An identification that succeeded from a departure that kept no line or no
  # admitted procedure opens no journey: none of its pages would have an
  # address. Said and logged like the other refusals.
  def refuse_incomplete_departure(entrance)
    Rails.logger.warn(LogLine.t('controllers.france_connect.incomplete_departure'))
    reason = t('controllers.france_connect.incomplete_departure')

    redirect_to demo_path(:root, entrance:), flash: { alert: :'interactors.failures.identification_refused', details: [reason] }
  end

  def departed_walk(expected)
    departure = expected.to_h.symbolize_keys
    entrance = expected ? Demo::Entrance.named(departure[:entrance]) : unattributed_entrance

    [EdmSpecification.from_segment(departure[:version]), departure[:procedure].presence_in(ProcedureCode::ADMITTED),
     entrance]
  end

  # A return this browser kept no departure for: the console to an agent it
  # admits, and to anyone else the public entrance where it is open, rather
  # than a console login they have no account for.
  def unattributed_entrance
    if Demo::Entrance::PUBLIC.open? && !administrator_signed_in?
      Demo::Entrance::PUBLIC
    else
      Demo::Entrance::CONSOLE
    end
  end

  def open_journey(identity, specification, procedure_code, entrance)
    previous = Demo::Journey.from_session(session[entrance.journey_key])
    Demo::Card.forget(previous.id) if previous

    session[entrance.journey_key] = Demo::Journey.opened(previous:, subject: identity.subject, specification:,
      procedure_code:).to_session
    keep_demo_identity(identity, entrance)
  end

  def completed_identification(expected)
    Demo::CompleteIdentification.call(
      code: params[:code], state: params[:state], expected:,
      announced_error: params[:error], error_description: params[:error_description],
    )
  end
end
