# The link a portal presents to the user once France has emitted the second
# request of a preview: where to go, with which HTTP verb, and what to send.
#
# France composes it rather than the portal because the return address is
# France's own — chapter 4.9 v1.2.3 §1 lets the portal's duties « be provided by
# Intermediary Platforms ». On 2.0 the return address travels in the
# `ReturnLocation` slot and the link is the preview address as received. On 1.2
# it travels in the link itself, chapter 4.9 v1.2.3 §5: « Add the return address,
# in encoded form, as a value of the "returnurl" query parameter », with
# `returnmethod=GET`, « appended to the existing query component » for a `GET`,
# and « in the request body » for a `POST` or a `PUT`.
class PreviewLink
  # The verb a link is followed with, and the only one the return address of
  # this deployment answers.
  GET = 'GET'.freeze

  def initialize(location:, return_location:, specification:, preview_method: nil)
    @location = location
    @return_location = return_location
    @specification = specification
    @preview_method = preview_method
  end

  def address = appended? ? with_return_query : location

  # Chapter 4.9 v1.2.3 §4 has `PreviewMethod` absent mean nothing in particular:
  # a link, followed as links are.
  def http_method = earlier_line? ? (preview_method || GET) : GET

  # The form a `POST` or a `PUT` sends, as `application/x-www-form-urlencoded`.
  def body
    return_query if earlier_line? && http_method != GET
  end

  private

  attr_reader :location, :return_location, :specification, :preview_method

  def earlier_line? = !specification.return_location_slot?

  def appended? = earlier_line? && http_method == GET

  # Chapter 4.9 v1.2.3 §4: « https:// is to be quoted as https%3A%2F%2F ».
  def return_query = URI.encode_www_form(returnurl: return_location, returnmethod: GET)

  def with_return_query
    separator = if location.end_with?('?', '&') then ''
                elsif location.include?('?') then '&'
                else '?'
                end

    "#{location}#{separator}#{return_query}"
  end
end
