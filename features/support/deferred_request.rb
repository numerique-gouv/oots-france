# The second request a page of the console makes for its listing, put under the
# scenario's control before it reaches the server.
#
# Three things are needed in front of the browser, and the application must be
# asked for none of them: hold the request, so that a scenario can look at the
# page *between* its arrival and its content — or end the session while it
# waits; fabricate a response the application did not write, which is the very
# case `Deferred-Fragment` exists to refuse; and cut the connection, so that no
# response arrives at all.
#
# All three rest on Chrome's `Fetch` domain, which Ferrum exposes as
# `network.intercept` plus an `:request` subscription.
class DeferredRequest
  # The address the two pages served in two parts fetch. Narrowed to it on
  # purpose: everything else the page loads — its stylesheets, the import map,
  # the controllers themselves — must not be paused along with it.
  PATTERN = '*listing=1*'.freeze

  # How long a scenario waits for the browser to have asked. Capybara's own
  # waiting governs elements, and this one a request that may never come — a
  # page whose script never ran being exactly the failure to report.
  TIMEOUT = 10

  def initialize(page)
    @page = page
    @paused = Queue.new
  end

  # Holds the first request and lets any later one through: the scenario of the
  # expired session makes the browser reload the page, which asks a second
  # time, and a second pause nothing releases would hang there.
  def hold = arm(:hold) { |request| @paused.push(request) }

  # Answers in the browser, with a document this application never wrote — the
  # `502` nginx renders out of its own pocket when nothing runs behind it. No
  # `Deferred-Fragment`, which is the point.
  def answer(status:, body:)
    arm(:answer) do |request|
      request.respond(responseCode: status, responseHeaders: { 'content-type' => 'text/html' }, body:)
    end
  end

  # No response at all, the connection cut before a status arrived. Chrome codes
  # the refusal `BlockedByClient`, and `fetch` rejects on it exactly as on a
  # connection that dropped: nothing in the page can tell the two apart, so
  # there is no `ConnectionAborted` to look for here.
  def cut = arm(:cut, &:abort)

  # Blocks until the browser has asked, which is what makes the hold
  # deterministic rather than timed.
  #
  # Nothing but `hold` ever fills the queue, so waiting on it under any other
  # use would wait for ever — and then blame a script that did run. The caller
  # is told what it actually armed instead.
  def held
    raise "Rien à libérer : la requête différée est armée en #{@armed.inspect}." unless @armed == :hold

    raise_any_failure

    @held ||= @paused.pop(timeout: TIMEOUT) ||
              raise("La page n'a pas demandé son contenu en #{TIMEOUT} s : son JavaScript ne s'est pas exécuté.")
  end

  # What the handler could not raise where it happened. Called by the scenario's
  # own thread, which is the only one Cucumber listens to — and taken as it is
  # read: the step that asks and the `After` hook both call this, and a failure
  # left in place would be reported twice, the second time outside any step.
  def raise_any_failure
    failure = @failure
    @failure = nil

    raise failure if failure
  end

  # `Fetch.continueRequest` goes out asynchronously, so releasing from the
  # scenario's own thread pays no round trip and cannot time out.
  def release = held.continue

  private

  # The block runs on Ferrum's subscription thread and never blocks: it takes the
  # request and hands back control, the scenario's own thread being what releases
  # it. That thread is one — `Client::Subscriber` spawns a regular and a
  # priority one and hands each event to a single one of them — so nothing here
  # runs against itself, and `taken` needs no lock.
  #
  # One use at a time, and the refusal is not decoration: `Ferrum::Client`
  # *appends* a subscriber rather than replacing one, and delivers every
  # `Fetch.requestPaused` to all of them. Two would each send their own terminal
  # command for the same paused request, where the `Fetch` domain admits one —
  # and every command going out asynchronously, the second would fail out of
  # sight of the scenario that caused it.
  def arm(mode)
    raise "La requête différée est déjà armée en #{@armed.inspect}." if @armed

    @armed = mode
    taken = false

    browser.network.intercept(pattern: PATTERN)
    browser.on(:request) do |request|
      if taken
        request.continue
      else
        taken = true
        yield(request)
      end
    rescue StandardError => e
      # An exception here dies on Ferrum's thread, which `loop`s over the events
      # and stops on it: the request would stay paused, every later one with it,
      # and Cucumber would report a Capybara timeout naming nothing. Kept for
      # the scenario's thread, and the request let through so nothing waits.
      @failure ||= e
      release_quietly(request)
    end
  end

  # Best effort, and that is the whole of it: a dead transport is one of the two
  # things that can have raised above, and trying it again would raise where
  # nothing catches — killing the very thread the rescue exists to keep alive. A
  # request nobody can reach any more is not one worth releasing.
  def release_quietly(request)
    request.continue
  rescue StandardError
    nil
  end

  def browser = @page.driver.browser
end

# Built on first use rather than in a hook: only the scenarios that ask for it
# have a browser to intercept, and `Fetch.enable` dies with the page Capybara
# throws away after each scenario.
def deferred_request = @deferred_request ||= DeferredRequest.new(page)

# The one place a failure of the handler can still reach the scenario when no
# step asked it for anything afterwards.
After('@javascript') { @deferred_request&.raise_any_failure }
