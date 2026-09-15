require 'capybara/cuprite'

# The browser the scenarios tagged `@javascript` are played by.
#
# `capybara/cucumber` already carries `Before '@javascript'`, and what it
# switches to is `Capybara.javascript_driver`: registering Cuprite under that
# name is the whole of the wiring, and a scenario asks for a browser by carrying
# the tag. Take the tag off, and the scenario falls back on `rack_test`, which
# runs no script at all — which is what makes the tag provable.
#
# The browser is found on `PATH`, under any of the seven Chrome and Chromium
# names Ferrum tries. Neither place leaves it to chance: the `Dockerfile`
# installs `chromium`, and `tests.yml` takes the one its runner image ships
# after a step that fails by name when there is none.
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    # Chrome's own sandbox cannot start under the root this image runs as. This
    # is Ferrum's own switch for it, and all it adds is `--no-sandbox` and
    # `--disable-setuid-sandbox`; `--disable-dev-shm-usage`, the other classic
    # container failure, is already in its defaults.
    dockerize: true,
    # What one command to the browser may take. The listing of the requirements
    # page sweeps the whole catalogue — one directory query per requirement —
    # and the navigation waits on what the server is still building.
    # `Capybara.default_max_wait_time` below is the other one, and bounds the
    # wait for an element rather than a command.
    timeout: 30,
  )
end

Capybara.javascript_driver = :cuprite

# How long an expectation waits for what it looks for. Two seconds is the
# default, and only a browser makes it too short: a page of the console fetches
# its listing, and the client asking the directory backs off twice before
# giving up on one that does not answer.
#
# Raised around the tagged scenarios and put back after, rather than once for
# the whole profile: the reading is global, so every `have_no_css` of the suite
# would otherwise spend five seconds proving an absence instead of two.
ordinary_wait = Capybara.default_max_wait_time

Before('@javascript') { Capybara.default_max_wait_time = 5 }
After('@javascript') { Capybara.default_max_wait_time = ordinary_wait }
