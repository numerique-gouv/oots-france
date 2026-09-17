module Demo
  # What the demonstration procedure does the instant the user confirms: seal the
  # beneficiary token, call the contract, and keep what came back.
  #
  # The instant matters. Chapter 4.5.1 §2.3: « If the value of the
  # ExplicitRequestGiven slot is true, the value of the IssueDateTime slot shall
  # not be materially different from the date and time at which the explicit
  # request was made by the user. » `evidence_request.xml.erb` declares that
  # slot true on every request, so the condition always holds and the request is
  # issued here, on the click, rather than prepared ahead.
  #
  # `T1` and `FR` are fixed rather than asked: the demonstration makes France
  # talk to France, and offers the user no member state to pick — the choice is
  # step 16 of chapter 1 §10.1, which this procedure does not play.
  #
  # The conversation is not minted here: the journey already carries one, named
  # when the authentication opened it. Chapter 4.7 §2.5.1 allows exactly that —
  # « The initial ConversationId for a conversation MAY be assigned by the Online
  # Procedure Portal or its Intermediary Platform » — and it is what lets two
  # clicks made in the same instant go out under one conversation instead of
  # racing to name one.
  #
  # The two names the documents page showed travel with the click rather than
  # being resolved again here: the rule above allows the `IssueDateTime` no
  # material distance from that gesture, and three directory queries before
  # sending would put themselves between the two. What is filed is what was
  # shown.
  class RequestEvidence < ApplicationInteractor
    PROCEDURE_CODE = ProcedureCode::STUDY_FINANCING
    PROVIDER_COUNTRY = 'FR'.freeze

    # What the documents page showed, each name with the language the
    # directory published it in: the zone says them again, and it is
    # written in English whatever the directories answered. The requirement
    # joins them because a click names the one requirement its own card is
    # about, and a row naming the document without the obligation it was asked
    # under would not say which click it answers.
    NAMED = %i[evidence_type_name evidence_type_language provider_name provider_language
               procedure_name procedure_language
               requirement_id requirement_name requirement_language].freeze

    # The three refusals that never open an exchange, told apart by status
    # because that is all a service provider's server has to go on. Anything
    # else is reported with its status rather than folded into one of the three:
    # a `500` is this deployment's own configuration, and calling it a refusal
    # would send the reader looking at the request.
    STATUS_FAILURES = {
      422 => :demo_refused,
      501 => :demo_locked,
      502 => :demo_unreachable,
    }.freeze

    def call
      answer = ask_the_contract

      return refuse(answer) unless answer.accepted?

      keep(answer)
    # The two ways this can fail before anything is asked of anyone: the contract
    # or the key set unreachable, and the key set answering something no key can
    # be read from. Logged as much as shown, like the three other interactors of
    # `Demo::` — no `Exchange` exists at this point, so nothing else would keep
    # a trace of an outage, and the alert the user is shown does not read back.
    rescue Faraday::Error, UnusableKeySetError => e
      Rails.logger.warn(I18n.t('interactors.demo.request_evidence.unreachable', error: e.message))

      fail_with_error(:demo_unreachable, errors: [e.message])
    end

    private

    # Over HTTP, with the query string a French service provider's server sends:
    # the beneficiary token is sealed here, at the moment of the click, and not
    # a step earlier.
    def ask_the_contract
      client.fetch(
        requester_id: Settings.demo_requester_id,
        procedure_code: PROCEDURE_CODE,
        country_code: PROVIDER_COUNTRY,
        encrypted_beneficiary: token_writer.call(context.identity),
        conversation_id: context.journey.conversation_id,
        requirement_id: context.requirement_id,
      )
    end

    # Registered as well as returned. Chapter 4.10 §4.1, informative, has a later
    # delivery placed against « any known current user and/or user session », and
    # this row is what makes this exchange one of the known: a document arriving
    # for an exchange absent from the register is refused, so the register is
    # written the instant the identifier exists and nowhere later.
    def keep(answer)
      Request.create!(
        exchange_id: answer.exchange_id, conversation_id: answer.conversation_id,
        **whose_click, **what_was_named,
      )
    end

    # The journey this click belongs to and the requirement its card is about:
    # the two are how the zone of that card finds this row again, the session
    # holding nothing of it. Chapter 1 §4.2 has the evidence « made available to
    # the specific procedure end-user that issued the query », and the journey is
    # who that is.
    def whose_click = { journey_id: context.journey.id, requirement_uuid: context.requirement_uuid }

    def what_was_named = NAMED.index_with { |named| context.public_send(named) }

    # The message the contract returned travels with the refusal: it is the only
    # thing that says which of the refusals of `STATUS_FAILURES` this was, and
    # `EB:ERR:0001` is in it rather than in the status.
    #
    # The status is spelled out for the one key whose wording cannot name what
    # happened; the three others are named by their own sentence, and would only
    # repeat it.
    def refuse(answer)
      key = STATUS_FAILURES.fetch(answer.status, :demo_unexpected)
      status = key == :demo_unexpected ? [answer.status.to_s] : []

      fail_with_error(key, errors: status + [answer.error].compact_blank)
    end

    def client = context.evidence_request_client ||= EvidenceRequestClient.new

    def token_writer = context.token_writer ||= BeneficiaryTokenWriter.new
  end
end
