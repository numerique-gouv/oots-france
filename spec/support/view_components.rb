# `render_inline` and the Capybara matchers that read what it produced. Neither
# is included by default, and a component spec without them can only inspect
# constants — which is testing the configuration, not the rendering.
RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
