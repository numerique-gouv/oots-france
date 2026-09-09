# What FranceConnect+ answers, before anything looks inside it.
#
# Every document the portal sends is a JSON **object** — the discovery document
# of OpenID Connect Discovery, the answer of `/token`, the claims set of a JWT
# (« The JWT Claims Set … is a JSON object », RFC 7519 §4) and the header of a
# JWE. A body that parses as an array, a number, `true` or `null` parses without
# error and then blows up on the first `[]`, three or four calls later, as a
# `TypeError` or a `NoMethodError` naming nothing a reader could act on.
#
# So the question is asked once, here, and asked of all four: the two clients of
# FranceConnect+ hand every parsed body through this before indexing it, and a
# malformed answer becomes the refusal the portal earned rather than a five
# hundred.
# https://datatracker.ietf.org/doc/html/rfc7519#section-4
module FranceConnectAnswer
  def self.object(parsed, subject)
    return parsed if parsed.is_a?(Hash)

    raise FranceConnectError,
      I18n.t('clients.france_connect_answer.not_an_object',
        subject: I18n.t("clients.france_connect_answer.subjects.#{subject}"), type: parsed.class)
  end
end
