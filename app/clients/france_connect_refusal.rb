# What FranceConnect+ says of a refusal, when it says anything.
#
# `/token` motivates an error with a JSON object carrying `error`, and
# optionally `error_description` and `error_uri` (RFC 6749 §5.2); `/userinfo`
# answers a call it cannot read the same way — « 400 — document JSON décrivant
# l'origine de l'erreur de format ». Those three fields are the first thing the
# support of FranceConnect asks for, and the message the HTTP client raises
# with — « the server responded with status 400 for POST …/token » — carries
# none of them.
#
# `reason` is `nil` when the body is not that: a maintenance page, an array, an
# object naming no `error`, or a connection that never got an answer at all. The
# caller then relays the raising of the HTTP client, which names the status and
# the address.
# https://datatracker.ietf.org/doc/html/rfc6749#section-5.2
# https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-endpoints/
# https://docs.partenaires.franceconnect.gouv.fr/fs/fs-integration/integration-erreurs/
class FranceConnectRefusal
  def initialize(error, url)
    @error = error
    @url = url
  end

  # The sentence shown and journalised, in the words the portal chose. Four
  # sentences and not one recomposed from pieces: a translated fragment is never
  # concatenated, and an absent field must leave no empty label behind it.
  def reason
    return if announced.nil?

    I18n.t("clients.france_connect_refusal.#{shape}",
      url: @url, status: @error.response_status, error: announced, **motivation)
  end

  private

  # Read off `motivation` rather than off the fields again, so that the sentence
  # chosen and the values interpolated into it cannot disagree on which fields
  # the portal answered.
  def shape
    return :refused_fully if motivation.key?(:description) && motivation.key?(:uri)
    return :refused_described if motivation.key?(:description)
    return :refused_documented if motivation.key?(:uri)

    :refused
  end

  def motivation = @motivation ||= { description:, uri: }.compact

  def announced = text('error')

  def description = text('error_description')

  def uri = text('error_uri')

  # RFC 6749 §5.2 makes each of the three a string. Anything else motivates
  # nothing a human could act on, and is shown neither as itself nor as its
  # class.
  def text(name)
    value = body[name]

    value.presence if value.is_a?(String)
  end

  # Only a JSON object counts, as everywhere else the portal is read:
  # `FranceConnectAnswer` asks the same question of the four documents it sends.
  def body
    @body ||= parsed.is_a?(Hash) ? parsed : {}
  end

  def parsed
    JSON.parse(@error.response_body.to_s)
  rescue JSON::ParserError
    nil
  end
end
