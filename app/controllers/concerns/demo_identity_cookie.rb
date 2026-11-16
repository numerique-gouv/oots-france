# Where the browser keeps the identity FranceConnect+ attested: two cookies of
# their own and not the session, because the cookie store bounds each cookie at
# four kibibytes. The attributes go in one, the signed ID Token the sign-out
# hands back in the other, which fills a large part of a cookie once encrypted.
# Encrypted like the session, unreadable to a script, and written nowhere on
# the server: `Demo::UserIdentity` is personal data.
#
# The two are written and deleted together, and read only together: a browser
# that kept one without the other holds no identity.
module DemoIdentityCookie
  extend ActiveSupport::Concern

  COOKIES = %i[demo_identity demo_id_token].freeze

  private

  def demo_identity
    attributes = cookies.encrypted[:demo_identity]
    id_token = cookies.encrypted[:demo_id_token]
    return nil if attributes.nil? || id_token.nil?

    ::Demo::UserIdentity.from_cookie(attributes.merge('id_token' => id_token))
  end

  def keep_demo_identity(identity)
    keep_encrypted(:demo_identity, identity.to_cookie.except('id_token'))
    keep_encrypted(:demo_id_token, identity.id_token)
  end

  def forget_demo_identity = COOKIES.each { |name| cookies.delete(name) }
end
