# The documents a requester may ask to receive alongside the evidence itself
# (chapter 4.5.1), written as `sdg:AssociatedDocumentRequest` in the requested
# distribution. New in EDM 2.0.
#
# R-EDM-REQ-C119 (FATAL) closes the list to these three values, and the schema
# declares no type for the element — so nothing but the check below stands
# between a caller's typo and a request a correspondent must refuse.
module AssociatedDocument
  ANNEX = 'Annex'.freeze
  HUMAN_READABLE_VERSION = 'HumanReadableVersion'.freeze
  TRANSLATION = 'Translation'.freeze

  REQUESTABLE = [ANNEX, HUMAN_READABLE_VERSION, TRANSLATION].freeze

  # Raised and not collected into an `rs:Exception`: what is asked for comes
  # from this deployment's own code, never from a correspondent, so an unknown
  # value is a mistake in our configuration and not a message to turn away.
  def self.vetted(requested)
    unknown = requested - REQUESTABLE
    return requested if unknown.empty?

    raise ConfigurationError,
      I18n.t('models.associated_document.unrequestable',
        values: unknown.join(', '), requestable: REQUESTABLE.join(', '))
  end
end
