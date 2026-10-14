# One card of the documents page, built the same way whether the page renders it
# among the others or the choice of a country answers it alone: what a card
# offers must not depend on which of the two drew it.
module BuildsDemoCards
  extend ActiveSupport::Concern

  # The country a card stands in, the evidence type it names, the answers it was
  # resolved on, and whether it may change any of them, come from there.
  include HoldsDemoProviderClassifications

  private

  # A provider whose gateway does not announce the line of the journey offers
  # no button: requirement 27 of chapter 1 §2 has the user told « before any
  # request is made », and the contract would refuse the request anyway
  # (chapter 4.5.1 §2.2).
  def requirement_card(wording)
    spoken = spoken?(wording)

    DemoRequirementCardComponent.new(
      wording:, country_code: wording.country_code, country_name: country_name(wording.country_code),
      countries: country_options(wording), evidence_types: evidence_type_options(wording),
      zone: (demo_request_zone(wording) if wording.nameable? && spoken),
      unspoken: (demo_specification unless spoken), removable: added_card(wording.requirement_uuid).present?,
      questions: classification_questions(wording),
    )
  end

  # The card alone, which the browser splices into the page around the list the
  # user is still on, and a header it can tell this application's answer by.
  def answer_with_card(wording)
    response.set_header('Deferred-Fragment', '1')
    render requirement_card(wording), layout: false
  end

  # The cards the operator added beyond those the Evidence Broker lists for the
  # procedure, by requirement, in the order they were added.
  def added_cards = @added_cards ||= ::Demo::Card.added(journey.id).index_by(&:requirement_uuid)

  def added_card(requirement_uuid) = added_cards[requirement_uuid]

  # One card resolved alone, as a choice made on it asks: an added card from its
  # own requirement, any other under the procedure of the journey.
  #
  # On the answers given, where the Data Service Directory asks something: it is
  # asked again with them.
  def resolve_card(requirement_uuid, country_code, evidence_type_id, provider_classifications)
    added = added_card(requirement_uuid)
    return resolve_added_card(added, country_code, evidence_type_id, provider_classifications) if added

    DirectoryLookup::Resolve.call(
      evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
      procedure_code: journey.procedure_code, country_code:, requirement_id: requirement_uuid,
      evidence_type_id:, alternatives_offered: true, provider_classification_answers: provider_classifications,
    )
  end

  # An added card resolved from the requirement its row keeps, by the second
  # query of the Evidence Broker and the Data Service Directory alone: chapter
  # 3.2.4 §4.3 bases that query « on a requirement that is known to the
  # Procedure Portal », and the procedure of the journey need not declare it.
  #
  # On the type named, and on none where the user has not chosen among several:
  # requirement 26 of chapter 1 §2 leaves that choice to them.
  def resolve_added_card(card, country_code, evidence_type_id, provider_classifications)
    DirectoryLookup::ResolveRequirement.call(
      evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
      requirement: card.requirement, country_code:, evidence_type_id:, alternatives_offered: true,
      provider_classification_answers: provider_classifications,
    )
  end

  def spoken?(wording) = wording.access_point.nil? || wording.access_point.speaks?(demo_specification)

  # The button of one card, in whatever state the register puts it: a reload is
  # not a new request, so a requirement already under way opens on its waiting
  # rather than on a button that would start a second.
  def demo_request_zone(wording)
    DemoRequestZoneComponent.new(outcome: demo_outcome_for(wording.requirement_uuid),
      requirement_uuid: wording.requirement_uuid)
  end

  # In English, like the page. A code list that says nothing leaves the name
  # blank, and the box then shows the code alone. The code and the name travel
  # apart, and not the box around them: a ViewComponent instance is single-use,
  # and a card names the country more than once.
  def country_name(code) = country_names[code]

  # What a card offers to pick from, read as a country reads everywhere in the
  # console and sorted by the name it shows. `nil` on a card that stays in the
  # country of the request it follows, which offers no choice.
  def country_options(wording)
    return if held_country(wording.requirement_uuid)

    @country_options ||= HoldsDemoCountries::OFFERED
      .map { |code| [CountryTagComponent.label(code, country_name(code)), code] }
      .sort_by { |(_, code)| country_name(code).presence || code }
  end

  # The evidence types the country of the card publishes for its requirement,
  # where it publishes more than one, as `[label, uuid, { lang: }]`: named as the
  # directory names them, in English first like the page. `nil` on a card with
  # a single type, which leaves nothing to choose, and on one that follows a
  # request, which names the type it asked for.
  def evidence_type_options(wording)
    return if !wording.choosable? || held_card?(wording.requirement_uuid)

    languages = DemoResolutionWording::LANGUAGES

    wording.evidence_types.map do |type|
      [type.label(languages:).presence || type.uuid, type.uuid, { lang: type.label_language(languages:) }]
    end
  end

  # The questions the Data Service Directory asks on the card, each in the
  # control its type calls for — chapter 3.1.4 §4.4.3.3: « codelist, string or
  # boolean and Evidence Requesters MUST support all three of these » — and on
  # the answer the card was resolved on. `nil` on a card asking nothing, and on
  # one that follows a request, which was sent on its answers.
  #
  # A `codelist` offers the values of the list its `sdg:ValueExpression`
  # addresses, read at this render; one that cannot be read is asked in a text
  # field, which costs the values and nothing else.
  def classification_questions(wording)
    return if !wording.asking? || held_card?(wording.requirement_uuid)

    answers = wording.provider_classifications

    wording.questions.map do |question|
      options = (question_values(question) if question.code_list?)

      DemoRequirementCardComponent::Question.new(
        id: question.id, control: question_control(question, options), label: question.question,
        language: question.question_language, options:, value: answers[question.id],
      )
    end
  end

  def question_values(question)
    classification_values.values(question.value_expression, language: question.question_language)
  end

  def question_control(question, options)
    if question.boolean? then :radio
    elsif options then :select
    else :text
    end
  end

  def classification_values = @classification_values ||= ClassificationValuesClient.new

  def country_names = @country_names ||= code_lists.country_names(lang: :en)

  # One client per request, as `Admin::CommonServices::BaseController` keeps one
  # for its section: the lists it answers are the same on every call, and a
  # second instance would fetch them again.
  def code_lists = @code_lists ||= CodeListClient.new
end
