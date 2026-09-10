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
      include RefusesIdentification

      def create
        result = ::Demo::StartIdentification.call

        return refuse_identification(result) unless result.success?

        session[:france_connect] = { state: result.state, nonce: result.nonce }

        redirect_to result.authorization_url, allow_other_host: true
      end
    end
  end
end
