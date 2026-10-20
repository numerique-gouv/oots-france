module Demo
  # The evidence types of one card asked for, one request each — `R-EDM-REQ-S015`
  # has a single `EvidenceRequest` per query — in the order of the combination,
  # under the conversation of the journey, which chapter 4.4 §4.3.2 says
  # « SHOULD be reused for combined flows ».
  #
  # `named_evidences` is what the card named for each type asked for, and
  # `procedure` the names of the journey's procedure. `whole` is a click on the
  # combination's one button, which the card keeps: a refusal of the contract
  # opens no exchange to show it by. A refusal stops the requests after it, and
  # is handed back in `failures` by evidence type UUID; those already accepted
  # run. The organizer itself does not fail:
  # what it asked for is said block by block.
  class RequestCombination < ApplicationOrganizer
    def call
      remember_the_click if context.whole
      context.failures = {}

      context.named_evidences.each do |named|
        result = request(named)
        next if result.success?

        context.failures = { named.evidence_type_uuid => result.error }
        break
      end
    end

    private

    def remember_the_click
      Card.request_the_combination(journey_id: context.journey.id, requirement_uuid: context.requirement_uuid)
    end

    def request(named)
      RequestEvidence.call(identity: context.identity, journey: context.journey, requirement_uuid: context.requirement_uuid,
        **named.attributes.symbolize_keys, **context.procedure)
    end
  end
end
