# One card of the documents page, built the same way whether the page renders it
# among the others or the choice of a country answers it alone: what a card
# offers must not depend on which of the two drew it.
module BuildsDemoCards
  extend ActiveSupport::Concern

  # The country a card stands in, the combination it names, the answers each of
  # its lines was resolved on, and whether it may change any of them, come from
  # there.
  include HoldsDemoProviderClassifications

  private

  # A provider whose gateway does not announce the line of the journey offers
  # no button: requirement 27 of chapter 1 §2 has the user told « before any
  # request is made », and the contract would refuse the request anyway
  # (chapter 4.5.1 §2.2). A combination is asked for whole, so one such line
  # leaves the whole card without its zone.
  def requirement_card(wording)
    unspoken = unspoken_lines(wording)

    DemoRequirementCardComponent.new(
      wording:, country_code: wording.country_code, country_name: country_name(wording.country_code),
      countries: country_options(wording), combinations: combination_options(wording),
      zone: (demo_request_zone_of(wording) if wording.nameable? && unspoken.empty?),
      unspoken:, removable: added_card(wording.requirement_uuid).present?,
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
  # On the answers given, by evidence type, where the Data Service Directory
  # asks something: it is asked again with them.
  def resolve_card(requirement_uuid, country_code, evidence_type_list_id, provider_classifications)
    added = added_card(requirement_uuid)
    return resolve_added_card(added, country_code, evidence_type_list_id, provider_classifications) if added

    DirectoryLookup::ResolveCombination.call(
      evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
      procedure_code: journey.procedure_code, requirement_id: requirement_uuid,
      country_code:, evidence_type_list_id:, provider_classifications:,
    )
  end

  # An added card resolved from the requirement its row keeps, by the second
  # query of the Evidence Broker and the Data Service Directory alone: chapter
  # 3.2.4 §4.3 bases that query « on a requirement that is known to the
  # Procedure Portal », and the procedure of the journey need not declare it.
  #
  # On the combination named, and on none where the user has not chosen among
  # several: chapter 3.2.2 §2.3 leaves that choice to them.
  def resolve_added_card(card, country_code, evidence_type_list_id, provider_classifications)
    DirectoryLookup::ResolveCombination.call(
      evidence_broker: EvidenceBrokerClient.new, data_service_directory: DataServiceDirectoryClient.new,
      requirement: card.requirement, country_code:, evidence_type_list_id:, provider_classifications:,
    )
  end

  # The version of the EDM the journey plays, by evidence type UUID, for each
  # line whose provider does not announce it.
  def unspoken_lines(wording)
    wording.lines.reject { |line| spoken?(line) }.to_h { |line| [line.evidence_type_uuid, demo_specification] }
  end

  def spoken?(line) = line.access_point.nil? || line.access_point.speaks?(demo_specification)

  # The zone of one card, in whatever state the register puts each of its
  # requests: a reload is not a new request, so a type already under way opens
  # on its waiting rather than on a button that would start a second.
  def demo_request_zone_of(wording)
    types = wording.lines.map do |line|
      DemoRequestZoneComponent::Type.new(uuid: line.evidence_type_uuid, name: line.evidence_type,
        language: line.evidence_type_language)
    end

    demo_request_zone(wording.requirement_uuid, types, requested: demo_card(wording.requirement_uuid)&.requested?)
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

  # The combinations the country of the card publishes for its requirement,
  # where it publishes several, as `[label, identifier, { lang: }]`: named as
  # `DemoCardWording.label` says, in English first like the page. `nil` on a
  # card with a single one, which leaves nothing to choose, and on one that
  # follows a request, which names the combination it asked for.
  def combination_options(wording)
    return if !wording.choosable? || held_card?(wording.requirement_uuid)

    wording.combinations.map do |list|
      [DemoCardWording.label(list).presence || list.id, list.id, { lang: DemoCardWording.label_language(list) }]
    end
  end

  # The questions the Data Service Directory asks on each line of the card, by
  # evidence type UUID, each in the control its type calls for — chapter 3.1.4
  # §4.4.3.3: « codelist, string or boolean and Evidence Requesters MUST
  # support all three of these » — and on the answer the line was resolved on.
  # Nothing for a line asking nothing, and for none on a card that follows a
  # request, which was sent on its answers.
  #
  # A `codelist` offers the values of the list its `sdg:ValueExpression`
  # addresses, read at this render; one that cannot be read is asked in a text
  # field, which costs the values and nothing else.
  def classification_questions(wording)
    return {} if held_card?(wording.requirement_uuid)

    wording.lines.select(&:asking?).to_h do |line|
      [line.evidence_type_uuid, line.questions.map { |question| classification_question(question, line.provider_classifications) }]
    end
  end

  def classification_question(question, answers)
    options = (question_values(question) if question.code_list?)

    DemoRequirementCardComponent::Question.new(
      id: question.id, control: question_control(question, options), label: question.question,
      language: question.question_language, options:, value: answers[question.id],
    )
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
