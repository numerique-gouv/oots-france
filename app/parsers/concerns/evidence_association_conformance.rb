# How the objects of an evidence package relate to one another: §2.6
# « Associations Between Evidence Objects » and the rules `R-EDM-RESP-S050` to
# `-S061`, which the 1.2 line does not publish — it has no package, and one
# response carries one document.
#
# Read and never refused, like everything else `EvidenceResponseParser#violations`
# confronts a response to.
#
# It includes `EvidencePackagingConformance`, whose readings of a package it
# uses — `nested_objects`, `classified`, `object_name`, `association?`: what a
# package *is* is said there, and how its objects relate is said here. That cut
# follows the headings of §2.6 and not a line count: these rules are the only
# ones that cross the objects of a list with one another.
#
# Declared here rather than left to the parser, in which both modules happen to
# meet — the reason `RequirementConformance` states for including
# `AgentConformance`: that coincidence would resolve the calls just as well, and
# would break silently the day this module is included anywhere else.
#
# **The crossing is resolved in Ruby and never by an interpolated XPath.**
# `@sourceObject` and `@targetObject` are written by the correspondent, and
# `"./rim:RegistryObject[@id='#{source}']"` would hand a foreign value to an
# expression: an `id` carrying an apostrophe would break the query rather than
# fail the rule, and a chosen one could break the comparison. Same border
# `CLAUDE.md` draws around `escape` on emission, taken the other way round.
#
# `response`, `specification` and `violation` are the includer's.
module EvidenceAssociationConformance
  include OotsNamespaces
  include EvidencePackagingConformance

  ASSOCIATION_TYPE_PREFIX = 'urn:oasis:names:tc:ebxml-regrep:AssociationType:'.freeze

  # The three couples of §2.6, and the whole of their asymmetric numbering in
  # one table: the rules that read an association forwards pair `S052`/`S056`
  # with the annex, `S053`/`S057` with the human-readable version and
  # `S054`/`S058` with the translation — but the rules that read it backwards
  # are numbered `S059` for the annex, **`S060` for the translation** and
  # **`S061` for the human-readable version**. Checked three times over rather
  # than read once, that crossing is how a pair gets mismatched.
  #
  # `source` and `target` require the classification under the EDM scheme;
  # `typing` reads it under any scheme. That asymmetry is the Schematron's too.
  ASSOCIATIONS = {
    'Annex' => {
      type: "#{ASSOCIATION_TYPE_PREFIX}Annex",
      source: 'R-EDM-RESP-S052', target: 'R-EDM-RESP-S056', typing: 'R-EDM-RESP-S059',
    },
    'HumanReadableVersion' => {
      type: "#{ASSOCIATION_TYPE_PREFIX}HumanReadableVersion",
      source: 'R-EDM-RESP-S053', target: 'R-EDM-RESP-S057', typing: 'R-EDM-RESP-S061',
    },
    'Translation' => {
      type: "#{ASSOCIATION_TYPE_PREFIX}Translation",
      source: 'R-EDM-RESP-S054', target: 'R-EDM-RESP-S058', typing: 'R-EDM-RESP-S060',
    },
  }.freeze

  private

  def association_violations
    return [] unless specification.packaged_response?

    [
      *unassociated_supplementaries,
      *associations_without_an_end,
      *misdirected_associations,
      *mistyped_associations,
    ]
  end

  # `-S050`: every annex, translation and human-readable version is the source
  # of an association sitting in its own list. Hung on the classification, with
  # no scheme filter — an object classified twice breaks it twice.
  def unassociated_supplementaries
    classified(*SUPPLEMENTARY_NODES).filter_map do |node|
      next if associated?(node.parent)

      violation('R-EDM-RESP-S050', 'supplementary_without_association',
        id: object_name(node.parent), node: attribute(node, 'classificationNode'))
    end
  end

  # `-S051` and `-S055`, on every association of every nested list — neither
  # context asks what type the object holding that list has.
  def associations_without_an_end
    associations.flat_map do |association|
      [
        missing_end(association, 'sourceObject', 'R-EDM-RESP-S051', 'association_without_source'),
        missing_end(association, 'targetObject', 'R-EDM-RESP-S055', 'association_without_target'),
      ].compact
    end
  end

  def missing_end(association, name, rule, key)
    return unless attribute(association, name).nil?

    violation(rule, key, id: object_name(association))
  end

  # `-S052` to `-S058`: an association that declares its type says, by that
  # alone, what the two objects it joins must be classified as. Neither rule
  # asks that the attribute be there — an association without `@sourceObject`
  # breaks `-S051` and its source rule both, an empty sequence matching no
  # object.
  def misdirected_associations
    packaged_associations.flat_map do |association|
      node, rules = ASSOCIATIONS.find { |_, couple| couple[:type] == attribute(association, 'type') }
      next [] if rules.nil?

      [
        misdirected_source(association, node, rules[:source]),
        misdirected_target(association, rules[:target]),
      ].compact
    end
  end

  def misdirected_source(association, node, rule)
    return if classified_sibling?(association, 'sourceObject', node)

    violation(rule, 'association_source_misclassified', id: object_name(association), node:)
  end

  def misdirected_target(association, rule)
    return if classified_sibling?(association, 'targetObject', MAIN_EVIDENCE_NODE)

    violation(rule, 'association_target_misclassified', id: object_name(association))
  end

  def classified_sibling?(association, name, node)
    sibling_classified?(association, attribute(association, name), node,
      scheme: EDM_SCHEME)
  end

  # `-S059` to `-S061`, the converse: whatever an association claims to be, a
  # supplementary document joined to the main one is that document's annex, its
  # translation or its human-readable version, and its `@type` must say so.
  #
  # Both ends are required by the context here, so an association missing one is
  # silent under all three — a hole kept rather than closed, the convention
  # `RequirementConformance::REQUIREMENT_IDENTIFIER` states. And the
  # classifications are read under any scheme, where `-S052` to `-S058` demand
  # the EDM one.
  def mistyped_associations
    complete_associations.flat_map { |association| mistyped(association) }
  end

  def mistyped(association)
    return [] unless main_evidence_target?(association)

    ASSOCIATIONS.filter_map do |node, rules|
      next unless sibling_classified?(association, attribute(association, 'sourceObject'), node)
      next if attribute(association, 'type') == rules[:type]

      violation(rules[:typing], 'association_mistyped',
        id: object_name(association), node:, type: rules[:type])
    end
  end

  def main_evidence_target?(association)
    sibling_classified?(association, attribute(association, 'targetObject'),
      MAIN_EVIDENCE_NODE)
  end

  # `count(../../rim:RegistryObject[@xsi:type='rim:AssociationType' and @sourceObject = $objectId]) > 0`,
  # resolved over the object's own list.
  #
  # An object carrying no `@id` is never associated, rather than being matched
  # by an association that carries no `@sourceObject` either: XPath compares an
  # absent attribute as an empty node set, which equals nothing at all — where
  # Ruby would find `nil == nil` and clear two breaches with one.
  def associated?(object)
    id = attribute(object, 'id')
    return false if id.nil?

    siblings_of(object).any? { |sibling| association?(sibling) && attribute(sibling, 'sourceObject') == id }
  end

  # `count(../rim:RegistryObject[@id=$src][rim:Classification[…]])>0`, resolved
  # the same way and for the same reason: `id` comes from the correspondent.
  def sibling_classified?(association, id, node, scheme: nil)
    return false if id.nil?

    siblings_of(association).any? do |sibling|
      attribute(sibling, 'id') == id &&
        all(sibling, './rim:Classification').any? { |found| classifies?(found, node, scheme:) }
    end
  end

  # The objects of the list the given one sits in, itself included — which is
  # what `..` opens onto in every one of these contexts.
  def siblings_of(object) = all(object.parent, './rim:RegistryObject')

  def associations = nested_objects.select { |object| association?(object) }

  # Where `-S052` to `-S061` hang, and the one filter that separates them from
  # `-S051` and `-S055`: a list held by an object typed as a package.
  def packaged_associations
    packages.flat_map { |package| all(package, LISTED_OBJECTS).to_a }
      .select { |object| association?(object) }
  end

  def complete_associations
    packaged_associations.select do |association|
      attribute(association, 'sourceObject') && attribute(association, 'targetObject')
    end
  end
end
