# Turns a failed validation into a raised error, for the value objects whose
# invalidity must stop the exchange rather than be collected and displayed.
#
# The message must name the carrier, because that is what makes the failure
# actionable. Hence the subject passed in: an EbmsIdentity cannot know on its
# own whether it describes a requester, a provider or an access point. It
# travels as a symbol, `models.strict_validation.subjects` holding what each
# one reads as.
module StrictValidation
  extend ActiveSupport::Concern

  # The carriers this application knows how to name. A closed list and not a
  # scan of the call sites: `data_services_response_parser` passes its subject
  # through a variable, so nothing read from the source would ever see it.
  SUBJECTS = %i[announced_access_point announced_data_service announced_evidence_type
                announced_provider announced_provider_address announced_provider_identity
                announced_requirement final_recipient french_provider message_sender
                original_sender provider recipient_access_point request_beneficiary
                requester token_beneficiary].freeze

  # The error class is the caller's to choose, the same value object being
  # built from two provenances: our own configuration failing means the
  # deployment is wrong, where a foreign message failing must become an
  # `EDM:ERR:0003` answer rather than an unhandled crash.
  def validate!(subject, error: ConfigurationError)
    return self if valid?

    raise error, I18n.t('models.strict_validation.invalid',
      subject: I18n.t("models.strict_validation.subjects.#{subject}"),
      errors: errors.full_messages.join(', '))
  end
end
