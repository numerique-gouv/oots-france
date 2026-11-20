module Admin
  module Demo
    # Where a sign-in card of the demonstration leads: the European flow of the
    # FranceConnect+ that card names, which the browser is handed straight over
    # to.
    #
    # `POST` and not `GET`: starting a flow writes the `state` and the `nonce` a
    # return will be checked against, and a link the browser prefetched or
    # replayed would overwrite those of a flow under way. The name of the
    # FranceConnect+ travels in the body of that same submission.
    #
    # The line, the procedure and the entrance of the page the flow leaves from
    # are kept beside the `state` and the `nonce`: the return, whose addresses
    # name none of them, opens the journey in them.
    #
    # The button of the identity card ends that flow and nothing else: the
    # operator's session stays open, and the walk is replayed under another
    # identity without going back through ProConnect.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class IdentificationsController < Admin::BaseController
      include DemoIdentityCookie
      include EndsFranceConnectSession
      include RefusesIdentification

      # A FranceConnect+ the entrance does not offer leads nowhere, as one the
      # deployment does not declare: the public entrance offers the fake alone.
      def create
        instance = offered_instance

        return redirect_to(demo_path(:home)) if instance.nil?

        result = ::Demo::StartIdentification.call(instance:)

        return refuse_identification(result, version:, procedure:, entrance: demo_entrance) unless result.success?

        remember_departure(result, instance)

        redirect_to result.authorization_url, allow_other_host: true
      end

      # The identity, the journey and its cards are forgotten before the end of
      # the session is prepared, so that a portal that cannot be reached never
      # leaves them held. The sign-out ends the journey, so the next sign-in
      # opens a new conversation even for the same identity — a boundary
      # chapter 4.4 §4.3.2 leaves to the portal: « The Procedure Portal defines
      # session boundaries ».
      def destroy
        identity = demo_identity(demo_entrance)
        forget_journey

        url = end_of_france_connect_session(identity)
        return leave_for(url) if url

        flash[:alert] = :'controllers.admin.demo.identifications.not_closed' if identity
        redirect_to demo_path(:home, version:, procedure:)
      end

      private

      def offered_instance = demo_entrance.france_connect_instances.find { it.name == params[:france_connect] }

      # FranceConnect+ has a single return address for every sign-out: the
      # session keeps the home the agent left from, for that return to send
      # them back to.
      def leave_for(url)
        session[:france_connect_logout_home] = demo_path(:home, version:, procedure:)
        redirect_to url, allow_other_host: true
      end

      def forget_journey
        forget_demo_identity(demo_entrance)
        journey = ::Demo::Journey.from_session(session.delete(demo_entrance.journey_key))
        ::Demo::Card.forget(journey.id) if journey
      end

      def remember_departure(result, instance)
        session[:france_connect] = { state: result.state, nonce: result.nonce, name: instance.name, version:,
                                     procedure:, entrance: demo_entrance.name }
      end

      def version = params[:version]

      def procedure = params[:procedure]
    end
  end
end
