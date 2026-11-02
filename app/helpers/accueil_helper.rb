module AccueilHelper
  # An external link opened in a new window, announced in its title (RGAA 13.2).
  def new_window_link(text, address)
    link_to text, address, target: '_blank', rel: 'noopener', title: t('accueil.index.new_window', link: text)
  end

  # The consolidated text of Regulation (EU) 2018/1724 in the language of the
  # page, the one whose Annex II the page lists.
  def consolidated_regulation_address
    "https://eur-lex.europa.eu/legal-content/#{I18n.locale.upcase}/TXT/HTML/?uri=CELEX:02018R1724-20260520"
  end

  # The four directives article 14(1) of Regulation (EU) 2018/1724 names beside
  # its Annex II, each a link to its text.
  def directive_links
    { professional_qualifications: '2005/36', services: '2006/123', public_procurement: '2014/24',
      utilities: '2014/25' }.to_h do |directive, number|
      [directive, new_window_link(t("accueil.index.procedures.directives.#{directive}"),
        "https://eur-lex.europa.eu/eli/dir/#{number}/oj")]
    end
  end
end
