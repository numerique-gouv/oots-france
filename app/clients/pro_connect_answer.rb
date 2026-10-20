# What ProConnect answers, before anything looks inside it: the discovery
# document, the answer of `/token`, the claims set of a JWT and a UserInfo
# response are all JSON **objects**, and a body that parses as anything else
# would blow up three calls later on the first `[]`, naming nothing. Asked once,
# here, for the reason `FranceConnectAnswer` gives.
# https://datatracker.ietf.org/doc/html/rfc7519#section-4
module ProConnectAnswer
  def self.object(parsed, subject)
    return parsed if parsed.is_a?(Hash)

    raise ProConnectError,
      I18n.t('clients.pro_connect_answer.not_an_object',
        subject: I18n.t("clients.pro_connect_answer.subjects.#{subject}"), type: parsed.class)
  end
end
