# The Data Service Directory answered `DSD:ERR:0005`: it needs the user's
# answer to a question before it can name a provider (chapter 3.1.4 §4.2.4,
# « This error code always indicates that extra user input is required to
# complete the query »). A refusal of the directory, hence the family; one
# nobody upstream of the caller can lift, hence a name of its own.
class ProviderClassificationRequired < CommonServicesError
  CODE = 'DSD:ERR:0005'.freeze

  def initialize(message, classifications: [])
    super(message, code: CODE, classifications:)
  end
end
