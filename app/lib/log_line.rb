# A line of the application log, always written in the default locale: it is
# read by whoever runs the deployment, whatever language the browser whose
# request wrote it had chosen.
module LogLine
  def self.t(key, **) = I18n.t(key, **, locale: I18n.default_locale)

  # For a call whose failures are written to the log and never shown: the
  # sentences it composes come out in the log's language.
  def self.speaking(&) = I18n.with_locale(I18n.default_locale, &)
end
