module DirectoryLookup
  # The organisations holding that evidence in that country, and the access
  # points reaching them.
  #
  # The version parameter is the one a real request sends, so a gateway
  # speaking another version of the EDM is absent here exactly as it would be
  # there.
  #
  # A `DSD:ERR:0005` asks the user a question per provider classification
  # (chapter 3.1.4 §4.4.3.3), and the questions are put on the context whatever
  # follows: they are what a card asks. Where `provider_classification_answers`
  # answers every one of them, the same query is asked again with an answer per
  # question — « MUST use the same evidence-type-classification parameter that
  # was already used for the initial query », « MUST add a new query parameter
  # for every EvidenceProviderClassification element » — and its answer, or its
  # refusal, is the step's. The questions come from this first query at every
  # run, being the only source of them and of a code list address still valid:
  # « the lifespan of the URI is therefore limited to the DSD request ».
  class FetchProviders < ApplicationInteractor
    include Refusing

    def call
      context.data_services = published

      fail_with_error(:no_provider, errors: [context.country_code]) if context.data_services.empty?
    rescue CommonServicesError => e
      refuse(e)
    end

    private

    # A question that does not describe itself as the chapter requires — its
    # identifier, which names a parameter of the query, a UUID among them —
    # is not asked: the refusal stands.
    def published
      directory_answer
    rescue CommonServicesError => e
      raise if e.classifications.empty?
      raise if malformed?(e.classifications)

      context.provider_classification_questions = e.classifications
      answers = answers_to(e.classifications)
      raise unless answers

      directory_answer(answers)
    end

    def malformed?(questions)
      invalid = questions.reject(&:valid?)
      invalid.each do |question|
        Rails.logger.warn(I18n.t('interactors.directory_lookup.fetch_providers.malformed_question',
          id: question.id, errors: question.errors.full_messages.join(', ')))
      end

      invalid.any?
    end

    def directory_answer(classifications = {})
      context.data_service_directory.data_services(
        evidence_type_classification: context.evidence_type.id, country_code: context.country_code, classifications:,
      )
    end

    # The answers to these questions and to no others, or nothing where one of
    # them is unanswered: « a separate answer must be provided by the user ».
    def answers_to(questions)
      given = context.provider_classification_answers

      EvidenceProviderClassification.answers_for(questions, given) if EvidenceProviderClassification.all_answered?(questions, given)
    end
  end
end
