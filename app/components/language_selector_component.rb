# The DSFR's language selector, in the header's tools: a button naming the
# current language, and a menu offering both, each named in its own language.
# https://github.com/GouvernementFR/dsfr/tree/main/src/dsfr/component/translate
class LanguageSelectorComponent < ViewComponent::Base
  # Each name is in its own language whatever the page's, and is therefore a
  # value rather than a translation.
  NAMES = { fr: 'Français', en: 'English' }.freeze

  private

  def current = I18n.locale

  def languages = ChosenLanguage::LANGUAGES

  def code(language) = language.to_s.upcase

  def label(language) = "#{code(language)} - #{NAMES.fetch(language)}"
end
