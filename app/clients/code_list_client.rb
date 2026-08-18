# The code lists published with the TDD (chapter 3.5.1).
#
# The Semantic Repository names each list and points at its distribution; the
# distribution is a genericode file living with the specification, in the
# Commission's own Git repository, tagged with the TDD version this deployment
# targets. Read on the fly rather than carried here, so that nothing has to be
# kept in step with a release by hand.
#
# A name is an ornament: every page it appears on says what it says without it.
# So a list that cannot be read costs nothing but the names — never an error,
# never a page — and an empty answer is not written to the cache, a passing
# outage having no business being served for the whole freshness window.
class CodeListClient
  BASE = 'https://code.europa.eu/oots/tdd/tdd_chapters/-/raw/2.0.1/OOTS-EDM/codelists/OOTS'.freeze

  PROCEDURES = "#{BASE}/Procedures-CodeList.gc".freeze
  COUNTRIES = "#{BASE}/OOTS_Country-CodeList.gc".freeze

  # The column holding French names, which the two lists do not name alike:
  # the procedures carry one column per language of the Union, the countries
  # carry the two names ISO 3166 gives them.
  FRENCH_NAMES = { PROCEDURES => 'name-FR', COUNTRIES => 'french' }.freeze

  def initialize(connection: nil)
    @connection = connection
  end

  def procedure_names = names(PROCEDURES)

  # ISO 3166 names a country with its article in brackets — « Autriche (l') »,
  # « Belgique (la) » — which reads as a footnote in a table cell.
  ARTICLE = /\s*\((?<article>[^)]*)\)\z/

  def country_names = names(COUNTRIES).transform_values { |name| name.sub(ARTICLE, '') }

  # Cet article-là, que rien d'autre ne publie : sans lui, une phrase française
  # ne sait pas situer un pays — « en Belgique », mais « aux Pays-Bas » et
  # « à Chypre », qui n'en porte aucun.
  def country_articles = names(COUNTRIES).transform_values { |name| name[ARTICLE, :article] }

  private

  def names(list)
    key = "code_lists/#{File.basename(list, '.gc')}"
    cached = Rails.cache.read(key)
    return cached if cached

    read(list).tap { |names| remember(key, names) if names.any? }
  end

  def read(list)
    body = connection.get(list).body
    names = GenericodeParser.new(body).names(code_column: 'code', name_column: FRENCH_NAMES.fetch(list))

    # Une réponse qui arrive et ne donne rien n'est pas une panne, et ne lève
    # donc rien : sans cette ligne, une liste que la Commission aurait déplacée
    # ou restructurée effacerait tous les noms de la console sans laisser la
    # moindre trace, là où une panne réseau en laisse une.
    Rails.logger.warn(I18n.t('clients.code_list.nothing_read', list:)) if names.empty?

    names
  # Large on purpose, and the only place in this application where that is
  # right: every page reading a name says what it says without one, so no
  # failure of this reading — not a timeout, not a redirect, not a file that
  # stopped being genericode — has any business reaching a controller.
  rescue StandardError => e
    Rails.logger.warn("Liste de codes illisible (#{list}) : #{e.message}")
    {}
  end

  def remember(key, names)
    Rails.cache.write(key, names, expires_in: Settings.common_services_cache_duration)
  rescue StandardError => e
    Rails.logger.warn("Liste de codes non mise en cache (#{key}) : #{e.message}")
  end

  # The timeout and the freshness of the central directories, for want of a
  # setting of its own: this reads an artefact those directories are published
  # with, and a second pair of variables would have to be explained rather than
  # used.
  def connection
    @connection ||= Faraday.new do |builder|
      builder.response :raise_error
      builder.options.timeout = Settings.common_services_timeout
      builder.options.open_timeout = Settings.common_services_timeout
      builder.adapter :net_http
    end
  end
end
