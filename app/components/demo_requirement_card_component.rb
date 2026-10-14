# One requirement of the procedure, as the documents page offers it: the
# evidence type that satisfies it, the provider holding that evidence, and the
# button that asks for it.
#
# The two names are what requirement 27 of chapter 1 §2 asks for word for word —
# « The user is provided with information about name of evidence provider and
# evidence type for confirmation, before any request is made » — so a card
# unable to name them offers nothing to click: the requirement is a condition of
# the request, not a decoration on it.
#
# `zone` is where the button lives, and it is the one part of the card an answer
# replaces: the card itself says what the requirement is and who satisfies it,
# which no answer changes. Every card that can name its two names carries one,
# and each follows its own request — chapter 4.4 §4.2.2 has « different basic
# flows … executed sequentially and/or in parallel », so no card waits on its
# neighbour. The address the browser re-asks is what tells them apart: it names
# this card's requirement.
#
# `countries` is the member states the user may pick the evidence to come from —
# step 16 of chapter 1 §10.1 — as `[label, code]` pairs; `nil` where the card
# stays in the country of the request it follows, which it then only names.
#
# `evidence_types` is the evidence types the country publishes for the
# requirement, where it publishes several — requirement 26 of chapter 1 §2 has
# the user select one — as `[label, uuid, { lang: }]`; `nil` where there is
# nothing to choose, or where the card names the type of the request it follows.
#
# `unspoken` is the line of the journey where the provider's gateway announces
# others and not it: the card says so in place of the button.
#
# `questions` is what the Data Service Directory asks before it can name the
# provider — `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3 — each a `Question` in the
# control its type calls for, on the answer the card was resolved on; `nil`
# where it asks nothing, or where the card follows a request.
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

  def initialize(wording:, country_code:, country_name: nil, zone: nil, countries: nil, evidence_types: nil,
                 unspoken: nil, removable: false, questions: nil)
    @wording = wording
    @questions = questions
    @evidence_types = evidence_types
    @country_code = country_code
    @country_name = country_name
    @zone = zone
    @countries = countries
    @unspoken = unspoken
    @removable = removable
    super()
  end

  attr_reader :zone, :countries, :evidence_types, :country_code, :unspoken, :questions

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
  # which RGAA 3.1 forbids. A country publishing several types is no dead end,
  # whatever the one chosen answers: the others remain. Nor is a card the Data
  # Service Directory asks a question on, which another answer may resolve.
  def css_classes = class_names(*CLASSES, 'requirement-card--unsatisfiable' => unsatisfiable?)

  def unsatisfiable? = !nameable? && !choosable? && !asking?

  # What the foot says under the questions: the provider the answers designate,
  # or the refusal the answers met — and nothing while the questions wait for
  # their first answers, nothing being refused yet.
  def refused? = !nameable? && !unchosen? && (!asking? || answered?)

  # Several types, and none chosen yet: the foot names nothing and offers
  # nothing, the list above waiting for the user.
  def unchosen? = choosable? && evidence_type.nil?

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
  def evidence_type_path = helpers.admin_demo_type_justificatif_path(exigence: requirement_uuid)

  # Posted outside what its answer replaces, which is the resolution alone: the
  # questions keep the focus and the values typed.
  def answer_path = helpers.admin_demo_classification_fournisseur_path(exigence: requirement_uuid)

  def question_field(question) = "question-#{requirement_uuid}-#{question.id}"

  def question_name(question) = "classificationFournisseur[#{question.id}]"

  def answer_failure_field = "reponse-#{requirement_uuid}-erreur"

  # The card's own address in the page, which a reload of the page can land on.
  def anchor = "exigence-#{requirement_uuid}"

  def country_field = "pays-#{requirement_uuid}"

  def failure_field = "#{country_field}-erreur"

  def evidence_type_field = "type-#{requirement_uuid}"

  def evidence_type_failure_field = "#{evidence_type_field}-erreur"

  delegate :nameable?, :choosable?, :asking?, :answered?, :published_nothing?, :evidence_type, :evidence_type_language,
    :evidence_type_uuid, :provider,
    :provider_language, :requirement, :requirement_language, :requirement_uuid, to: :wording

  private

  attr_reader :wording
end
