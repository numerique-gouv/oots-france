module Admin
  module Demo
    # The request the demonstration makes, and the zone of the documents page
    # that says where it stands.
    #
    # `create` **is** the explicit request, and the request leaves as it is
    # pressed. Chapter 4.5.1 §2.3 ties the two: « If the value of the
    # ExplicitRequestGiven slot is true, the value of the IssueDateTime slot
    # shall not be materially different from the date and time at which the
    # explicit request was made by the user. »
    #
    # The press is also where the explicit request of chapter 1 §3.3 is made —
    # « a step in which the user is asked to express explicitly whether he or
    # she wants to use the Once-Only Technical System ». The zone asks it as one
    # gesture rather than as a question with two answers: nothing leaves unless
    # the button is pressed, and leaving the page asks nobody anything.
    #
    # `show` is what the zone re-asks while it waits, and it reads what the
    # contract says rather than asking anything of anyone. Chapter 4.4 §4.1 —
    # « to return more references to the Online Procedure Portal, even if it is
    # for the same user in the same session, for the same evidency type and data
    # service, a new unique request MUST be issued » — so consulting is never
    # asking, and it may be repeated as often as the zone likes.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class RequestsController < Admin::BaseController
      include HoldsDemoIdentity
      include ReadsDemoRequest

      def show = render_zone

      # Requirement 27 of chapter 1 §2 makes the two names a condition of the
      # request, and the documents page is where they are said. A press
      # carrying neither was made without them — a session that expired between
      # the two requests, a POST that never went through the page — so nothing
      # leaves and the user is sent back to be shown what they would be asking
      # for.
      def create
        return redirect_to admin_demo_documents_path unless evidence_named?

        result = ::Demo::RequestEvidence.call(identity:, conversation_id: reusable_conversation, **named)

        return refuse(result) unless result.success?

        keep(result)

        render_zone
      end

      private

      # The header is what tells `demo_request_controller.js` that the body is
      # ours to splice into the page: a status cannot say that much, nginx
      # writing a `502` out of its own pocket when nothing answers behind it.
      #
      # `layout: false` because this answers a fragment and not a page: the
      # layout would land a second banner, menu and footer inside the card the
      # zone is spliced back into.
      def render_zone(failure: nil)
        response.set_header('Deferred-Fragment', '1')

        render DemoRequestZoneComponent.new(outcome: demo_outcome, failure:), layout: false
      end

      def named
        held = session[:demo_named].presence&.symbolize_keys || {}

        { evidence_type_name: held[:evidence_type], evidence_type_language: held[:evidence_type_language],
          provider_name: held[:provider], provider_language: held[:provider_language],
          procedure_name: held[:procedure], procedure_language: held[:procedure_language] }
      end

      # The two requirement 27 names, and not the procedure's own title, which
      # no directory owes anyone: a procedure nobody has named is still one a
      # user may ask under.
      def evidence_named? = named.values_at(:evidence_type_name, :provider_name).all?(&:present?)

      def keep(result)
        # Chapter 4.4 §4.3.2: the conversation « SHOULD be reused for combined flows »
        # and « MUST NOT be reused if the user authenticates with a different
        # identity ». The pseudonym FranceConnect+ hands this service provider
        # is what tells one identity from another, so it is stored beside the
        # conversation and compared before the conversation is offered again.
        session[:demo_conversation] = { id: result.conversation_id, subject: identity.subject }
        # What the zone follows. The session and nothing else: it is what
        # chapter 1 §4.2 makes the evidence available to.
        session[:demo_exchange] = result.exchange_id
      end

      # A refusal that never opened an exchange: there is nothing to follow, and
      # the zone says why and offers the press again rather than waiting on an
      # answer nobody is going to send.
      def refuse(result) = render_zone(failure: result.error)

      def reusable_conversation
        held = session[:demo_conversation].presence&.symbolize_keys
        return nil if held.nil? || held[:subject] != identity.subject

        held[:id]
      end
    end
  end
end
