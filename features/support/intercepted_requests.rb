# The requests a page of the console makes of its own accord, put under the
# scenario's control before they reach the server.
#
# Four things are needed in front of the browser, and the application must be
# asked for none of them: let a request through while watching it go; hold one,
# so that a scenario can look at the page *between* its departure and its
# answer — or end the session while it waits; fabricate an answer the
# application did not write, which is the very case `Deferred-Fragment` exists
# to refuse; and cut the connection, so that no answer arrives at all.
#
# All four rest on Chrome's `Fetch` domain, which Ferrum exposes as
# `network.intercept` plus an `:request` subscription.
#
# A scenario declares what is to become of the successive requests it cares
# about — `pass.hold`, `cut.cut.cut` — and everything past that list goes its
# own way. A zone that asks the same address over and over is what makes the
# list necessary: the interesting case is rarely the first request.
class InterceptedRequests
  # How long a scenario waits for the browser to have asked. Capybara's own
  # waiting governs elements, and this one a request that may never come — a
  # page whose script never ran being exactly the failure to report.
  TIMEOUT = 10

  # Readable so that the one helper building these can refuse a second pattern:
  # `Fetch.enable` carries one set at a time.
  attr_reader :pattern

  def initialize(page, pattern:)
    @page = page
    @pattern = pattern
    @paused = Queue.new
    @treatments = []
    @planned = []
    @awaited = 0
    @seen = []
    @lock = Mutex.new
  end

  # Through to the server, and recorded on the way. `pass` is not the absence of
  # a treatment: a scenario that wants the *second* request held has to say what
  # becomes of the first, and one that counts what went out needs the first to
  # be seen going.
  def pass = plan(:pass, &:continue)

  # Held until the scenario releases it. What `held` then waits on, and what
  # makes the hold deterministic rather than timed.
  def hold = plan(:hold) { |request| @paused.push(request) }

  # Answered in the browser, with a document this application never wrote — the
  # `502` nginx renders out of its own pocket when nothing runs behind it. No
  # `Deferred-Fragment`, which is the point.
  def answer(status:, body:)
    plan(:answer) do |request|
      request.respond(responseCode: status, responseHeaders: { 'content-type' => 'text/html' }, body:)
    end
  end

  # No answer at all, the connection cut before a status arrived. Chrome codes
  # the refusal `BlockedByClient`, and `fetch` rejects on it exactly as on a
  # connection that dropped: nothing in the page can tell the two apart, so
  # there is no `ConnectionAborted` to look for here.
  def cut = plan(:cut, &:abort)

  # What went out, in order: the method and the address of every request this
  # double took in hand. The method is the whole of what one scenario asks — a
  # zone that retries a lost click must consult its address and never post the
  # request again — and the count is what another asks, a single tick being
  # allowed to be out at a time.
  #
  # A request is recorded when it arrives, before its treatment runs, so a
  # treatment that raised would otherwise leave a count that looks right over a
  # request the double let through to the server untouched. Two of the answers
  # a scenario asserts on — the screen that must not change, the interrogation
  # that must not go out — are indistinguishable from that silent passage, so
  # the failure is raised here rather than at the end of the scenario.
  def seen
    raise_any_failure

    @lock.synchronize { @seen.dup }
  end

  # Blocks until the browser has asked, and hands back the request now waiting.
  #
  # Nothing but `hold` ever fills the queue, so waiting on it with no hold left
  # to come would wait for ever — and then blame a script that did run. The
  # caller is told what it actually planned instead.
  def held
    # First, and on every path including the memoised one: a request already in
    # hand says nothing about a treatment that has died since, and `release`
    # reaches this method only through that path.
    raise_any_failure

    return @held if @held

    raise "Rien à attendre : aucune requête retenue ne reste à venir dans #{planned.inspect}." unless
      awaiting_a_hold?

    taken = @paused.pop(timeout: TIMEOUT) ||
            raise("La page n'a pas demandé #{pattern} en #{TIMEOUT} s : son JavaScript ne s'est pas exécuté.")
    @lock.synchronize { @awaited += 1 }

    @held = taken
  end

  # `Fetch.continueRequest` goes out asynchronously, so releasing from the
  # scenario's own thread pays no round trip and cannot time out. The next hold
  # of the list waits on its own request, hence the forgetting.
  def release
    released = held
    @held = nil

    released.continue
  end

  # What the handler could not raise where it happened. Called by the scenario's
  # own thread, which is the only one Cucumber listens to — and taken as it is
  # read: the step that asks and the `After` hook both call this, and a failure
  # left in place would be reported twice, the second time outside any step.
  def raise_any_failure
    failure = @lock.synchronize do
      taken = @failure
      @failure = nil
      taken
    end

    raise failure if failure
  end

  private

  # What the scenario ever planned, and not what is left of it: the list is
  # consumed as the requests arrive, so it is the record of what was asked for
  # — which is what a refusal has to print.
  def planned = @lock.synchronize { @planned.dup }

  # Whether a held request is still to come: one planned and not yet waited on.
  # Counted rather than read off `planned`, which never shrinks — a single
  # `hold` already awaited and released must not let a later `held` wait ten
  # seconds on a queue nothing will fill, and then name a script that ran.
  def awaiting_a_hold? = @lock.synchronize { @planned.count(:hold) > @awaited }

  # The block runs on Ferrum's subscription thread and never blocks: it takes the
  # request and hands back control, the scenario's own thread being what releases
  # it.
  #
  # The subscription is registered once however many treatments are planned, and
  # the refusal that guards it is not decoration: `Ferrum::Client` *appends* a
  # subscriber rather than replacing one, and delivers every
  # `Fetch.requestPaused` to all of them. Two would each send their own terminal
  # command for the same paused request, where the `Fetch` domain admits one —
  # and every command going out asynchronously, the second would fail out of
  # sight of the scenario that caused it. That is also why one pattern serves a
  # scenario: `Fetch.enable` carries one set at a time.
  def plan(mode, &treatment)
    @lock.synchronize do
      @treatments.push(treatment)
      @planned.push(mode)
    end
    arm unless @armed
    @armed = true

    self
  end

  def arm
    browser.network.intercept(pattern:)
    browser.on(:request) do |request|
      record(request)
      next_treatment(request).call(request)
    rescue StandardError => e
      # An exception here dies on Ferrum's thread, which `loop`s over the events
      # and stops on it: the request would stay paused, every later one with it,
      # and Cucumber would report a Capybara timeout naming nothing. Kept for
      # the scenario's thread, and the request let through so nothing waits.
      @lock.synchronize { @failure ||= e }
      release_quietly(request)
    end
  end

  def record(request) = @lock.synchronize { @seen.push({ method: request.method, url: request.url }) }

  # The next treatment of the list, or passage: a scenario says what becomes of
  # the requests it is about, and the zone goes on asking long after.
  def next_treatment(request)
    @lock.synchronize { @treatments.shift } || ->(_) { request.continue }
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
#
# The pattern comes from the step file that asks, each suite of scenarios
# watching the one address it is about — and one pattern per scenario, for the
# reason `plan` gives.
def intercepted_requests(pattern:)
  @intercepted_requests ||= InterceptedRequests.new(page, pattern:)
  return @intercepted_requests if @intercepted_requests.pattern == pattern

  raise "Le double est armé sur #{@intercepted_requests.pattern}, et #{pattern} est demandé : " \
        'un seul jeu de motifs à la fois.'
end

# The one place a failure of the handler can still reach the scenario when no
# step asked it for anything afterwards.
After('@javascript') { @intercepted_requests&.raise_any_failure }
