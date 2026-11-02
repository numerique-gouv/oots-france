# What the browser holds of the identity FranceConnect+ attested, read as the
# application reads it: the cookies are encrypted, and a request spec only sees
# their ciphertext.
module DemoIdentityCookieReader
  def held_demo_identity
    jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash).encrypted
    attributes = jar[:demo_identity]
    attributes&.merge('id_token' => jar[:demo_id_token])&.symbolize_keys
  end

  # Whichever of the two cookies the browser still holds, whatever they say.
  def demo_identity_cookies = cookies.to_hash.slice('demo_identity', 'demo_id_token').compact_blank

  # What the browser sends back of each cookie, name included.
  def held_cookie_size(name) = "#{name}=#{cookies[name.to_s]}".bytesize

  # Every cookie the last response wrote, by name, with the size of what it
  # wrote: the cookie store refuses past four kibibytes.
  def written_cookie_sizes = written_cookies.to_h { |cookie| [cookie[/\A[^=]+/], cookie.split(';').first.bytesize] }

  # The `Set-Cookie` line the last response wrote for one cookie, attributes
  # included.
  def written_cookie(name) = written_cookies.find { |cookie| cookie.start_with?("#{name}=") }

  def written_cookies = Array(response.headers['Set-Cookie']).flat_map { |header| header.split("\n") }
end

RSpec.configure do |config|
  config.include DemoIdentityCookieReader, type: :request
end
