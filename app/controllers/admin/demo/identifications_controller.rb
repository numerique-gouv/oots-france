module Admin
  module Demo
    # Where the single sign-in button of the demonstration leads: the European
    # flow of FranceConnect+, which the browser is handed straight over to.
    #
    # `POST` and not `GET`: starting a flow writes the `state` and the `nonce` a
    # return will be checked against, and a link the browser prefetched or
    # replayed would overwrite those of a flow under way.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class IdentificationsController < Admin::BaseController
      def create
        result = ::Demo::StartIdentification.call

        return refuse(result) unless result.success?

        session[:france_connect] = { state: result.state, nonce: result.nonce }

        redirect_to result.authorization_url, allow_other_host: true
      end

      private

      def refuse(result)
        redirect_to admin_demo_root_path,
          flash: { alert: :"interactors.failures.#{result.error[:key]}", details: result.error[:errors] }
      end
    end
  end
end
