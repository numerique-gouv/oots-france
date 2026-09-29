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
    # The line of the page the flow leaves from is kept beside the `state` and
    # the `nonce`: the return, whose addresses name no line, opens the journey
    # in it.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class IdentificationsController < Admin::BaseController
      include RefusesIdentification

      def create
        instance = Settings.france_connect_instance(params[:france_connect])

        return redirect_to(admin_demo_home_path) if instance.nil?

        result = ::Demo::StartIdentification.call(instance:)

        return refuse_identification(result, version:) unless result.success?

        remember_departure(result, instance)

        redirect_to result.authorization_url, allow_other_host: true
      end

      private

      def remember_departure(result, instance)
        session[:france_connect] = { state: result.state, nonce: result.nonce, name: instance.name, version: }
      end

      def version = params[:version]
    end
  end
end
