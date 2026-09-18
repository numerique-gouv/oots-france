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
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class IdentificationsController < Admin::BaseController
      include RefusesIdentification

      def create
        instance = Settings.france_connect_instance(params[:france_connect])

        return redirect_to(admin_demo_root_path) if instance.nil?

        result = ::Demo::StartIdentification.call(instance:)

        return refuse_identification(result) unless result.success?

        session[:france_connect] = { state: result.state, nonce: result.nonce, name: instance.name }

        redirect_to result.authorization_url, allow_other_host: true
      end
    end
  end
end
