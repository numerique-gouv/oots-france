# The place a page holds for content it does not serve with itself.
#
# Two pages of the console sweep the Evidence Broker's catalogue — one query per
# requirement — and would otherwise leave the reader in front of the page they
# came from. They render this instead, and `deferred_controller.js` replaces it
# with what `url` answers.
class DeferredContentComponent < ViewComponent::Base
  def initialize(url:, message:)
    @url = url
    @message = message
    super()
  end

  attr_reader :url, :message
end
