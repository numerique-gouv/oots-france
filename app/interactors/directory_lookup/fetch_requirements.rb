module DirectoryLookup
  # The requirements the procedure rests on, read in our own jurisdiction.
  #
  # A procedure is ours, where the evidence types satisfying it belong to the
  # country being asked: getting those two the wrong way round is a mistake no
  # answer reveals, and showing which country each query names is half of what
  # this page is for.
  class FetchRequirements < ApplicationInteractor
    include Refusing

    def call
      context.requirements = published
      context.requirement = chosen
    rescue CommonServicesError => e
      refuse(e)
    end

    private

    def published
      context.evidence_broker.requirements(
        procedure_code: context.procedure_code, country_code: Settings.common_services_country_code,
      )
    end

    # The first the directory lists, unless the operator picked another. A
    # request takes the first that published types instead, which this step
    # cannot know: it has not asked for any yet. So the two part company on a
    # procedure whose leading requirement publishes nothing — pick that
    # requirement by hand to see what a request would have seen.
    def chosen
      context.requirements.find { |found| found.uuid == context.requirement_id } || context.requirements.first
    end
  end
end
