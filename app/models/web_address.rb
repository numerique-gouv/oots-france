# An address a correspondent declared, and the two questions this application
# asks of one. They are not the same question, and answering both in one place
# is what keeps the difference readable.
#
# `openable?` — can a browser be pointed at this at all? It admits `http` as
# well as `https`, because the console archives what a correspondent wrote
# rather than sending anyone there, and an address France refuses to follow is
# exactly the one a dispute will be about.
#
# `secure?` — is this what chapter 4.9 §4 allows? « specify secure HTTP
# ("https://") as transport. The use of "http://" URIs is not allowed. » An
# address the chapter forbids is shown as the text it already is, and never
# offered as a step of the journey.
#
# Neither vets what follows the scheme: nothing here fetches the address, and
# what a correspondent published is recorded as declared.
class WebAddress
  SCHEMES = %w[http https].freeze
  SECURE_SCHEME = 'https'.freeze

  def initialize(declared)
    @declared = declared.to_s
  end

  def openable? = scheme.in?(SCHEMES) && uri&.host.present?

  def secure? = scheme == SECURE_SCHEME

  private

  attr_reader :declared

  # An address that is not one at all answers « no » to both questions rather
  # than raising: what the journal recorded is what the correspondent sent, and
  # the point of asking is to find out whether anything can be done with it.
  def uri
    return @uri if defined?(@uri)

    @uri = URI.parse(declared)
  rescue URI::InvalidURIError
    @uri = nil
  end

  def scheme = uri&.scheme
end
