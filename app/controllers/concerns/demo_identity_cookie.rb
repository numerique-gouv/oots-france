# Where the browser keeps the identity FranceConnect+ attested: two cookies of
# their own and not the session, because the cookie store bounds each cookie at
# four kibibytes. The attributes go in one, the signed ID Token the sign-out
# hands back in the other, which fills a large part of a cookie once encrypted.
# Encrypted like the session, unreadable to a script, and written nowhere on
# the server: `Demo::UserIdentity` is personal data.
#
# The two are written and deleted together, and read only together: a browser
# that kept one without the other holds no identity. Each entrance of
# `Demo::Entrance` has its own two, so that identifying on one leaves the other
# as it was.
module DemoIdentityCookie
  extend ActiveSupport::Concern

  COOKIES = ::Demo::Entrance::ALL.flat_map(&:cookies).freeze

  private

  def demo_identity(entrance)
    attributes = cookies.encrypted[entrance.identity_cookie]
    id_token = cookies.encrypted[entrance.id_token_cookie]
    return nil if attributes.nil? || id_token.nil?

    ::Demo::UserIdentity.from_cookie(attributes.merge('id_token' => id_token))
  end

  def keep_demo_identity(identity, entrance)
    keep_encrypted(entrance.identity_cookie, identity.to_cookie.except('id_token'))
    keep_encrypted(entrance.id_token_cookie, identity.id_token)
  end

  def forget_demo_identity(entrance) = entrance.cookies.each { |name| cookies.delete(name) }
end
