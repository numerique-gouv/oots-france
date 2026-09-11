# The mark an exchange identifier wears where no message ever carried it: on the
# 1.2 line France mints one for itself at the opening and emits it nowhere, the
# `ExchangeId` property belonging to a 2.0 header alone. Without it an operator
# reads, in the console, an identifier they would then look for in the gateway
# and at the correspondent in vain.
#
# It says nothing of the exchange, which did take place — what tells a seeded
# exchange apart is its run of zeroes, and a seeded 2.0 one wears no mark.
class MintedIdentifierComponent < ViewComponent::Base
  def initialize(exchange:)
    @exchange = exchange
    super()
  end

  # Nothing where there is nothing to warn of: an event naming an exchange
  # France never opened carries none to ask, and an exchange whose version was
  # never settled says nothing about which line it would have run on.
  def render? = @exchange&.minted_identifier?

  def label = t('components.minted_identifier.label')

  def meaning = t('components.minted_identifier.meaning')
end
