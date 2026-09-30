module Demo
  # The demonstration procedure confirming the preview a correspondent asked for,
  # over HTTP and through the published contract —
  # `POST /requete/:exchange_id/previsualisation`, the second call
  # `docs/oots_context.md` gives a French service provider.
  #
  # The beneficiary token goes again, the exchange never having kept it, and the
  # address the user is to be brought back to: chapter 4.9 §5 has the portal
  # « Recognize, in the first flow, evidence error response messages … that
  # contain a "PreviewLocation" slot », and France then sends the second request
  # and answers the link to present.
  class PreviewConfirmationClient
    PATH = '/requete/%<exchange_id>s/previsualisation'.freeze

    def initialize(connection: Faraday.new)
      @connection = connection
    end

    def confirm(exchange_id:, encrypted_beneficiary:, resume_location:)
      path = format(PATH, exchange_id: CGI.escape(exchange_id.to_s))
      response = connection.post("#{Settings.oots_france_url}#{path}",
        URI.encode_www_form(beneficiaire: encrypted_beneficiary, adresseRetour: resume_location),
        'Content-Type' => 'application/x-www-form-urlencoded')

      ContractAnswer.from(response, path:)
    rescue Faraday::Error => e
      raise DemoContractError, I18n.t('clients.demo.preview_confirmation_client.unreachable', error: e.message)
    end

    private

    attr_reader :connection
  end
end
