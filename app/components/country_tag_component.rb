# A jurisdiction, in a box of its own: its flag, its name, its code.
#
# `href` is the caller's to give — a component that knew how to write this
# application's URLs would be a controller — and its absence is meaningful: the
# country of a postal address leads nowhere, and must not look as if it did.
class CountryTagComponent < ViewComponent::Base
  # `A` is the twenty-sixth character before the regional indicator symbol that
  # stands for it, and a pair of those is what a flag emoji is made of.
  REGIONAL_INDICATOR = 0x1F1A5

  # The directories name Greece `EL` and the United Kingdom `UK`, the
  # [convention of the EU institutions](https://ec.europa.eu/eurostat/statistics-explained/index.php?title=Glossary:Country_codes),
  # where ISO 3166-1 — which the Unicode flag sequences follow — says `GR` and
  # `GB`. Unmapped, the pair forms no flag at all and renders as a placeholder.
  ISO_3166 = { 'EL' => 'GR', 'UK' => 'GB' }.freeze

  # How a country reads wherever one appears — a box, a heading, a breadcrumb,
  # an option of the filter —, so that none of them says it differently.
  def self.label(code, name = nil)
    [flag(code), named(code, name)].compact.join(' ')
  end

  # Only for something shaped like a country code: anything else would render as
  # two unrelated letters boxed in a flag.
  def self.flag(code)
    return unless code.to_s.match?(/\A[A-Za-z]{2}\z/)

    alpha_2 = ISO_3166.fetch(code.upcase, code.upcase)
    alpha_2.chars.map { |letter| (letter.ord + REGIONAL_INDICATOR).chr(Encoding::UTF_8) }.join
  end

  def self.named(code, name)
    return code.presence || '—' if name.blank?
    return name if code.blank?

    "#{name} (#{code})"
  end

  private_class_method :named

  def initialize(code:, name: nil, href: nil)
    @code = code
    @name = name
    @href = href
    super()
  end

  def label = self.class.label(@code, @name)

  def tag_name = @href.present? ? :a : :span

  def attributes = { class: 'country-tag', href: @href.presence }
end
