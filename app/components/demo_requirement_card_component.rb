# One requirement of the procedure, as the documents page offers it: the
# combination of evidence types that satisfies it, the provider holding each
# of them, and the button that asks for them.
#
# The two names are what requirement 27 of chapter 1 §2 asks for word for word —
# « The user is provided with information about name of evidence provider and
# evidence type for confirmation, before any request is made » — so a card
# unable to name them for every type of its combination offers nothing to
# click: the requirement is a condition of the request, not a decoration on it.
#
# `zone` is where the buttons live, and it is the one part of the card an
# answer replaces: the card itself says what the requirement is and who
# satisfies it, which no answer changes. Every card that can name its two names
# for every line carries one, and each follows its own requests — chapter 4.4
# §4.2.2 has « different basic flows … executed sequentially and/or in
# parallel », so no card waits on its neighbour. The address the browser
# re-asks is what tells them apart: it names this card's requirement.
#
# `countries` is the member states the user may pick the evidence to come from —
# step 16 of chapter 1 §10.1 — as `[label, code]` pairs; `nil` where the card
# stays in the country of the request it follows, which it then only names.
#
# `combinations` is the combinations the country publishes for the requirement,
# where it publishes several — chapter 3.2.2 §2.3 has the user select one — as
# `[label, identifier, { lang: }]`; `nil` where there is nothing to choose, or
# where the card names the combination of the request it follows.
#
# `unspoken` is the version of the EDM the journey plays, by evidence type UUID,
# where the provider's gateway announces others and not it: the card's line for
# that type says so, and the card offers no button.
#
# `questions` is what the Data Service Directory asks before it can name the
# provider of a line — `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3 — by evidence
# type UUID, each a `Question` in the control its type calls for, on the answer
# the line was resolved on; nothing for a line asking nothing, and for every
# line of a card that follows a request.
#
# `removable` is a card the operator added beyond those the Evidence Broker
# lists for the procedure, which a cross in its corner takes off the page. The
# others are what the broker publishes for the procedure, and the page shows
# them for that.
class DemoRequirementCardComponent < ViewComponent::Base
  # One question of the Data Service Directory as the card asks it: `control` is
  # `:select` for a `codelist` whose values could be read — `options` being
  # `[[name, code], …]` —, `:radio` for a `boolean`, `:text` for a `string` and
  # for a `codelist` whose list could not. `label` is the question as the
  # directory words it, in `language`.
  Question = Data.define(:id, :control, :label, :language, :options, :value)

  def initialize(wording:, country_code:, country_name: nil, zone: nil, countries: nil, combinations: nil,
                 unspoken: {}, removable: false, questions: {})
    @wording = wording
    @questions = questions
    @combinations = combinations
    @country_code = country_code
    @country_name = country_name
    @zone = zone
    @countries = countries
    @unspoken = unspoken
    @removable = removable
    super()
  end

  attr_reader :zone, :countries, :combinations, :country_code

  def questions(line) = @questions[line.evidence_type_uuid]

  def unspoken(line) = @unspoken[line.evidence_type_uuid]

  def removable? = @removable

  # Where the cross posts: the card's own requirement, under the journey's
  # line and procedure.
  def removal_path = helpers.admin_demo_carte_path(exigence: requirement_uuid)

  # The jurisdiction the evidence was sought in, which the card names twice: in
  # what satisfies the requirement, and in what stands there when nothing does.
  # A box of its own each time — a ViewComponent instance is single-use.
  def country_tag = CountryTagComponent.new(code: @country_code, name: @country_name)

  # The name alone, where the line above already shows the country in its box:
  # a second flag and a second code would say the same thing twice.
  def country_name = @country_name.presence || @country_code

  CLASSES = %w[fr-card fr-card--shadow fr-card--no-arrow requirement-card fr-col-12 fr-col-md-8 fr-mb-4w].freeze

  # A requirement nothing satisfies is a dead end of the procedure, and the card
  # says so by its ground as well as by its wording — never by the ground alone,
  # which RGAA 3.1 forbids. A country publishing several combinations is no dead
  # end, whatever the one chosen answers: the others remain. Nor is a line the
  # Data Service Directory asks a question on, which another answer may
  # resolve; one it names no provider for leaves the combination unsatisfiable
  # (chapter 3.2.4 §4.3.2: « satisfied, if and only if, for all included
  # Evidence Types »).
  def css_classes = class_names(*CLASSES, 'requirement-card--unsatisfiable' => unsatisfiable?)

  def unsatisfiable?
    !choosable? && (lines.empty? || lines.any? { |line| !line.nameable? && !line.asking? })
  end

  # What a line says under its questions: the provider the answers designate,
  # or the refusal the answers met — and nothing while the questions wait for
  # their first answers, nothing being refused yet.
  def refused?(line) = !line.nameable? && (!line.asking? || line.answered?)

  # Several combinations, and none chosen yet: the foot names nothing and
  # offers nothing, the list above waiting for the user.
  def unchosen? = choosable? && combination_id.nil?

  # Nothing to name for any type: the resolution stopped before the types, and
  # the card says why in its foot.
  def refused_whole? = lines.empty? && !unchosen?

  # A country publishing nothing for the type, or a directory that declined to
  # answer for it: `wording` is a line, or the card when no line was reached.
  def refusal(wording)
    if wording.published_nothing?
      t('components.demo_requirement_card.no_provider_html', country: country_name)
    else
      t('components.demo_requirement_card.no_answer_html', country: country_name)
    end
  end

  # The requirement names the card whatever the directories answered next:
  # one nobody serves is still one the procedure rests on.
  def titled? = requirement.present?

  def askable? = nameable? && zone.present?

  # The address this card's zone answers on, and the one the browser re-asks
  # while it waits. The UUID and not the whole identifier: it is what the
  # console and `DirectoryLookup` already pass between themselves, and a
  # Semantic Repository URL would have to be escaped into the query string of
  # every one of these.
  def zone_path = helpers.admin_demo_demande_path(exigence: requirement_uuid)

  # Posted outside the zone the request controller watches: the answer replaces
  # what the resolution produced — the country line and the foot of the card,
  # button included — and never the list, nor the region announcing the change.
  def country_path = helpers.admin_demo_pays_path(exigence: requirement_uuid)

  # Posted outside the foot, which is all its answer replaces.
  def combination_path = helpers.admin_demo_combinaison_path(exigence: requirement_uuid)

  # Posted outside what its answer replaces, which is the resolution of its
  # line and the zone: the questions keep the focus and the values typed.
  def answer_path(line)
    helpers.admin_demo_classification_fournisseur_path(exigence: requirement_uuid,
      type: line.evidence_type_uuid)
  end

  def question_field(line, question) = "question-#{requirement_uuid}-#{line.evidence_type_uuid}-#{question.id}"

  def question_name(question) = "classificationFournisseur[#{question.id}]"

  def answer_failure_field(line) = "reponse-#{requirement_uuid}-#{line.evidence_type_uuid}-erreur"

  # The card's own address in the page, which a reload of the page can land on.
  def anchor = "exigence-#{requirement_uuid}"

  def country_field = "pays-#{requirement_uuid}"

  def failure_field = "#{country_field}-erreur"

  def combination_field = "combinaison-#{requirement_uuid}"

  def combination_failure_field = "#{combination_field}-erreur"

  delegate :nameable?, :choosable?, :lines, :combination_id, :published_nothing?, :requirement, :requirement_language,
    :requirement_uuid, to: :wording

  private

  attr_reader :wording
end
