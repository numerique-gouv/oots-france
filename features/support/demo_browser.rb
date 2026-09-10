require 'nokogiri'

# A browser walking the demonstration procedure, from the operator's login to
# the identified form, across the two hosts the journey crosses: this
# application and FranceConnect+.
#
# An HTTP client and not a browser proper: the `Dockerfile` installs no Chrome
# and nothing wires Cuprite into Cucumber. What it does do is what a browser
# does — it keeps the session cookie, follows redirections one at a time,
# including the ones that leave for the portal and come back, and **submits the
# forms it is shown**, hidden fields included. Posting to an address without
# reading the form first would sidestep the CSRF token, which is precisely one
# of the things the journey has to carry.
#
# The cookie is sent to this application and to it alone: a session cookie that
# followed a redirection to another host would be exactly the leak the same-site
# rules exist to prevent, and the scenario must not do what a browser refuses to.
class DemoBrowser
  MAXIMUM_REDIRECTIONS = 10

  attr_reader :page, :current_url

  def initialize(procedure_url)
    @procedure_url = procedure_url
    @cookie = nil
    @connection = Faraday.new do |builder|
      builder.request(:url_encoded)
      builder.adapter(Faraday.default_adapter)
    end
  end

  def sign_in(email, password)
    visit('/admin/session/new')
    submit(email:, password:)
  end

  # The button of the header, whose form carries the `_method` that makes it a
  # DELETE — read off the page like any other.
  def sign_out = submit_to('/admin/session')

  def visit(path) = follow(get("#{procedure_url}#{path}"))

  # The one press that starts everything: what follows crosses to the portal and
  # comes back on its own.
  def start_identification = submit_to('/admin/demo/identification')

  # The three pages of the European path, each submitted where the page itself
  # says to.
  def choose(name, value) = submit(name => value)

  def title = document.at_css('h1')&.text.to_s

  def body = page.body.to_s

  def rows
    document.css('table tr').to_h do |row|
      [row.at_css('th')&.text.to_s.strip, row.at_css('td')&.text.to_s.strip]
    end
  end

  private

  attr_reader :procedure_url, :connection

  def document = Nokogiri::HTML(body)

  def submit(fields) = send_form(only_form, fields)

  def submit_to(path) = send_form(form_posting_to(path), {})

  def only_form
    document.at_css('form') || raise("Aucun formulaire dans la page « #{title} » : #{body}")
  end

  def form_posting_to(path)
    document.css('form').find { |form| URI.parse(form['action'].to_s).path == path } ||
      raise("Aucun formulaire vers #{path} dans la page « #{title} » : #{body}")
  end

  # The hidden fields first, the scenario's own values second: what a form
  # carries — the CSRF token, the `_method` of a non-POST button — travels
  # exactly as the page wrote it.
  def send_form(form, fields)
    parameters = form.css('input[type=hidden]').to_h { |input| [input['name'], input['value']] }

    follow(post(absolute(form['action']), parameters.merge(fields.transform_keys(&:to_s))))
  end

  # One hop at a time, and never through Faraday's own follower: the cookie has
  # to be decided host by host, which a middleware following the whole chain
  # could not do.
  def follow(response)
    MAXIMUM_REDIRECTIONS.times do
      return @page = response unless response.status.between?(300, 399)

      response = get(absolute(response.headers.fetch('Location')))
    end

    raise "Plus de #{MAXIMUM_REDIRECTIONS} redirections depuis #{current_url}."
  end

  def get(url) = record(url) { connection.get(url, nil, headers(url)) }

  def post(url, parameters) = record(url) { connection.post(url, parameters, headers(url)) }

  def record(url)
    @current_url = url
    response = yield
    remember(url, response)

    response
  end

  def headers(url) = ours?(url) && @cookie ? { 'Cookie' => @cookie } : {}

  def remember(url, response)
    return unless ours?(url)

    Array(response.headers['set-cookie']).flat_map { |header| header.split(/,\s*(?=[^;]+=)/) }
      .each { |cookie| @cookie = cookie.split(';').first }
  end

  def ours?(url) = url.start_with?(procedure_url)

  def absolute(location)
    return location if location.start_with?('http://', 'https://')

    base = URI.parse(current_url)

    "#{base.scheme}://#{base.host}:#{base.port}#{location}"
  end
end
