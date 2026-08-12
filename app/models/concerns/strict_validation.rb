# Turns a failed validation into a raised error, for the value objects whose
# invalidity must stop the exchange rather than be collected and displayed.
#
# The message must name the carrier — "Le requêteur n'a pas d'identité ebMS
# exploitable" — because that is what makes the failure actionable. Hence the
# subject passed in: an EbmsIdentity cannot know on its own whether it
# describes a requester, a provider or an access point.
module StrictValidation
  extend ActiveSupport::Concern

  # The error class is the caller's to choose, the same value object being
  # built from two provenances: our own configuration failing means the
  # deployment is wrong, where a foreign message failing must become an
  # `EDM:ERR:0003` answer rather than an unhandled crash.
  def validate!(subject, error: ConfigurationError)
    return self if valid?

    raise error, "#{subject} : #{errors.full_messages.join(', ')}."
  end
end
