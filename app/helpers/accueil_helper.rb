module AccueilHelper
  # The four directives article 14(1) of Regulation (EU) 2018/1724 names beside
  # its Annex II, by their number on EUR-Lex.
  DIRECTIVES = { professional_qualifications: '2005/36', services: '2006/123', public_procurement: '2014/24',
                 utilities: '2014/25' }.freeze

  # Regulation (EU) 2018/1724 in the language of the page.
  def regulation_address = eur_lex_address('32018R1724')

  # Its consolidated text, the one whose Annex II the page lists.
  def consolidated_regulation_address = eur_lex_address('02018R1724-20260520')

  def directive_link(directive, text = t("accueil.index.directives.#{directive}"))
    new_window_link(text, "https://eur-lex.europa.eu/eli/dir/#{DIRECTIVES.fetch(directive)}/oj")
  end

  def directive_links = DIRECTIVES.keys.index_with { directive_link(it) }

  # How long the deployment keeps its exchange log, which the page states
  # rather than a figure of its own.
  def audit_trail_retention_months = Settings.audit_trail_retention.in_months.round

  private

  def eur_lex_address(celex) = "https://eur-lex.europa.eu/legal-content/#{I18n.locale.upcase}/TXT/HTML/?uri=CELEX:#{celex}"
end
