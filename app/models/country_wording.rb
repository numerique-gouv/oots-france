# How the console words a country, and what a member state declared under a
# procedure code.
#
# The article a country carries is published with its name — « Belgique (la) »,
# « Luxembourg (le) », « Pays-Bas (les) », « Chypre » with none — and it is what
# decides the preposition. Guessing one from the name instead would be wrong on
# every country the list spells differently from its gender.
#
# It reads the code lists and nothing else: no `params`, no request, so a spec
# hands it two hashes rather than a controller.
class CountryWording
  # « en Belgique », « au Luxembourg », « aux Pays-Bas », « à Chypre ». The
  # apostrophe is straight in some entries and curly in others, hence the key
  # without it.
  PREPOSITIONS = { 'la' => 'en', 'l' => 'en', 'le' => 'au', 'les' => 'aux' }.freeze

  def initialize(names:, articles:)
    @names = names
    @articles = articles
  end

  # A country the code list does not name is said by its code: the list is
  # published by the Commission and the catalogue by the member states, so
  # nothing guarantees that one names everything the other declares.
  def named(code) = @names[code].presence || code

  def in(code) = "#{PREPOSITIONS.fetch(article(code).delete("'’"), 'à')} #{named(code)}"

  # « par la Pologne », « par l'Autriche », « par Chypre »: the elided article
  # sticks to the name.
  def by(code)
    elided = article(code).end_with?("'", '’')

    "par #{article(code)}#{' ' unless elided}#{named(code)}".squish
  end

  # « Démarche déclarée sous l'intitulé « X » par la Pologne, avec 5 exigences ».
  # These three facts only read together: the title and what is required belong
  # to the country that filed them, and to no other.
  def declaration(labels:, country:, requirements: nil)
    named_as = labels.uniq
    under = if named_as.any?
              " #{I18n.t('admin.common_services.under_label', count: named_as.size)} " \
                "#{named_as.map { |label| "« #{label} »" }.to_sentence}"
            end

    "Démarche déclarée#{under} #{by(country)}#{requiring(requirements)}"
  end

  private

  def article(code) = @articles[code].to_s

  def requiring(count)
    return if count.nil?
    return ', sans exigence publiée' if count.zero?

    ", avec #{I18n.t('admin.common_services.requirements.count', count:).downcase}"
  end
end
