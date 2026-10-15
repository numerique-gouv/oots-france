module Admin
  module Demo
    # The request the demonstration makes, and the zone of the documents page
    # that says where it stands.
    #
    # `create` **is** the explicit request, and the request leaves as the
    # button is clicked. Chapter 4.5.1 §2.3 ties the two: « If the value of the
    # ExplicitRequestGiven slot is true, the value of the IssueDateTime slot
    # shall not be materially different from the date and time at which the
    # explicit request was made by the user. »
    #
    # The click is also where the explicit request of chapter 1 §3.3 is made —
    # « a step in which the user is asked to express explicitly whether he or
    # she wants to use the Once-Only Technical System ». The zone asks it as one
    # gesture rather than as a question with two answers: nothing leaves unless
    # the button is clicked, and leaving the page asks nobody anything.
    #
    # Both actions take the requirement they are about in `exigence`, the UUID
    # the documents page addresses its cards by: chapter 4.4 §4.2.2 has several
    # flows run « sequentially and/or in parallel », so a page carries one zone
    # per requirement and each answers for its own, a block per evidence type of
    # its combination. The parameter names which zone; what that zone may
    # report on is the session's business alone.
    #
    # Nothing here writes to the session: a click reads the journey and writes a
    # row of `demo_requests`. Two clicks made in the same instant therefore each
    # file their own row, and each zone reads its own request back from the
    # register, whichever answer returns first.
    #
    # `show` is what the zone re-asks while it waits, and it reads what the
    # contract says rather than asking for anything new. Chapter 4.4 §4.1 —
    # « to return more references to the Online Procedure Portal, even if it is
    # for the same user in the same session, for the same evidency type and data
    # service, a new unique request MUST be issued » — so consulting is never
    # asking, and it may be repeated as often as the zone likes. The one write a
    # reading leads to is the confirmation of a preview the correspondent asked
    # for, never repeated once it has succeeded — `ReadsDemoRequest#confirm_preview`
    # says why it is no new request.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin::Demo`, which would
    # otherwise answer for the name.
    class RequestsController < Admin::BaseController
      include ReadsDemoRequest
      include HoldsDemoNames

      def show = render_zone

      # Requirement 27 of chapter 1 §2 makes the two names a condition of the
      # request, and the documents page is where they are said. A click
      # carrying none was made without them — a session that expired between
      # the two requests, a POST that never went through the page — so nothing
      # leaves and the user is sent back to be shown what they would be asking
      # for. A combination is asked for whole, so every line must name both.
      #
      # `type` names the one evidence type asked for; without it, every type of
      # the combination is, as `Demo::RequestCombination` says. A refusal of the
      # contract opens no exchange: the block of its type says why and offers
      # its button again rather than waiting on an answer nobody will send.
      def create
        return redirect_to admin_demo_documents_path unless askable?

        render_zone(failures: request_combination.failures)
      end

      private

      def askable? = asked.any? && named_evidences(requirement_uuid).all?(&:valid?)

      def request_combination
        ::Demo::RequestCombination.call(identity:, journey:, requirement_uuid:, named_evidences: asked,
          procedure: named_procedure.attributes.symbolize_keys, whole: evidence_type_uuid.blank?)
      end

      def asked
        @asked ||= named_evidences(requirement_uuid)
          .select { |named| evidence_type_uuid.blank? || named.evidence_type_uuid == evidence_type_uuid }
      end

      # The header is what tells `demo_request_controller.js` that the body is
      # ours to splice into the page: a status cannot say that much, nginx
      # writing a `502` out of its own pocket when nothing answers behind it.
      #
      # `layout: false` because this answers a fragment and not a page: the
      # layout would land a second banner, menu and footer inside the card the
      # zone is spliced back into.
      def render_zone(failures: {})
        response.set_header('Deferred-Fragment', '1')

        render demo_request_zone(requirement_uuid, zone_types, requested: demo_card(requirement_uuid)&.requested?, failures:),
          layout: false
      end

      def zone_types
        named_evidences(requirement_uuid).map do |named|
          DemoRequestZoneComponent::Type.new(uuid: named.evidence_type_uuid, name: named.evidence_type_name,
            language: named.evidence_type_language)
        end
      end

      def requirement_uuid = params[:exigence].to_s

      def evidence_type_uuid = params[:type].to_s
    end
  end
end
