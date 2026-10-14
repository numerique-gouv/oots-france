# The values a `codelist` question of the Data Service Directory admits, read
# at the address its `sdg:ValueExpression` gives — chapter 3.1.4 §4.4.3.3:
# « Better, to access the classification scheme, or codelist, through the
# ValueExpression which returns the subset of applied values ».
#
# Never cached: the same chapter says « the lifespan of the URI is therefore
# limited to the DSD request », so an address is read at the render that
# received it. And like `CodeListClient`, no failure of this reading reaches a
# controller: a list that cannot be read costs the values alone, the question
# being asked in a text field instead.
class ClassificationValuesClient
  # The columns the template of chapter 3.1.4 §4.4.3.3 gives such a list: the
  # code, its name « in a Latin script, preferably English », whether it « is no
  # longer active », and one name per further language.
  CODE = 'code'.freeze
  NAME = 'name-Value'.freeze
  DEPRECATED = 'deprecated'.freeze

  def initialize(connection: nil)
    @connection = connection
  end

  # `[[name, code], …]` in the order the list publishes them, deprecated codes
  # left out, each named in `language` where the list carries a column for it,
  # failing which in `name-Value`, failing which by its code. `nil` where the
  # list cannot be read, or reads empty. Only an `https://` address is followed,
  # as `R-DSD-ERR-C038` (FATAL) holds it.
  def values(address, language: nil)
    return unreadable(address, I18n.t('clients.classification_values.insecure')) unless secure?(address)

    named(rows(address, language), language).presence ||
      unreadable(address, I18n.t('clients.classification_values.empty'))
  # Large on purpose: whatever stops the reading — a timeout, a redirect, a body
  # that is not genericode — costs the values and nothing else.
  rescue StandardError => e
    unreadable(address, "#{e.class}: #{e.message}")
  end

  private

  def secure?(address) = address.to_s.match?(EvidenceProviderClassification::SECURE_EXPRESSION)

  def rows(address, language)
    GenericodeParser.new(connection.get(address).body).rows(CODE, NAME, DEPRECATED, language_column(language))
  end

  def named(rows, language)
    rows.reject { |row| row[DEPRECATED].to_s.strip.casecmp?('true') }.filter_map do |row|
      next if row[CODE].blank?

      [row[language_column(language)].presence || row[NAME].presence || row[CODE], row[CODE]]
    end
  end

  def language_column(language) = "name-#{language.to_s.upcase}"

  def unreadable(address, reason)
    Rails.logger.warn(I18n.t('clients.classification_values.unreadable', address:, reason:))

    nil
  end

  def connection
    @connection ||= Faraday.new do |builder|
      builder.response :raise_error
      builder.options.timeout = Settings.common_services_timeout
      builder.options.open_timeout = Settings.common_services_timeout
      builder.adapter :net_http
    end
  end
end
