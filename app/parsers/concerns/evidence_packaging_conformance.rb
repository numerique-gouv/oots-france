# What an evidence package is, and what each object inside one carries: the
# rules chapter 4.6 publishes on the packaging version 2.0 introduced —
# `R-EDM-RESP-S046` to `-S066`, `-S064` being published on neither line — and
# the two families both lines publish in two shapes, `-S033` to `-S037` on what
# each object identifies and points at, `-S041` and `-S042` on the subject each
# confirms.
#
# Read and never refused, like every other rule this parser confronts a response
# to: `EvidenceResponseParser#violations` says why, and the journal is the whole
# of what these change.
#
# Which shape applies is settled by the line the response *announces*, which is
# what `specification` carries — the same split `EvidenceMetadataReading`
# already makes to find the metadata. The line of the exchange judges one thing
# and one only, `R-EDM-RESP-C002`, whose whole point is to make the gap between
# the two visible.
#
# Apart from the parser, as `EvidenceMetadataReading` is and for the reason it
# states: the class holds the rules of a whole response and tripped
# `Metrics/ClassLength` long before these twenty-five arrived. Split from
# `EvidenceAssociationConformance` along the headings of §2.6 itself — what an
# object *is* here, how objects *relate* there.
#
# `response`, `specification`, `violation` and `named` are the includer's.
module EvidencePackagingConformance
  include OotsNamespaces

  # The objects of the `rim:RegistryObjectList` a node holds — written once
  # because it is read from two scopes. From the response it gives the top-level
  # objects: in 2.0 each is a package holding a list of its own, in 1.2 they are
  # the documents themselves, `R-EDM-RESP-S015` and `-S033` anchoring there.
  # From a package it gives the objects of that package's own list, which is
  # where `EvidenceAssociationConformance` reads it.
  LISTED_OBJECTS = './rim:RegistryObjectList/rim:RegistryObject'.freeze

  # The lists a package holds, and the objects in them — 2.0 only.
  NESTED_LISTS = "#{LISTED_OBJECTS}/rim:RegistryObjectList".freeze
  NESTED_OBJECTS = "#{NESTED_LISTS}/rim:RegistryObject".freeze

  PACKAGE_TYPE = 'rim:RegistryPackageType'.freeze
  ASSOCIATION_TYPE = 'rim:AssociationType'.freeze

  # The classification scheme of the EDM, which `-S048` counts and `-S052` to
  # `-S058` require — where `-S050`, `-S059` to `-S063` and `-S065` read a
  # classification whatever scheme it names. That asymmetry is the Schematron's
  # and is kept as it stands.
  EDM_SCHEME = 'urn:fdc:oots:classification:edm'.freeze

  MAIN_EVIDENCE_NODE = 'MainEvidence'.freeze
  SUPPLEMENTARY_NODES = %w[Annex HumanReadableVersion Translation].freeze

  # The four values `-S049` closes its list on.
  CLASSIFICATION_NODES = [MAIN_EVIDENCE_NODE, *SUPPLEMENTARY_NODES].freeze

  # `-S062`, taken from its assertion and not from its message, which names five
  # of the six and leaves `Distribution` out. The parser already makes that
  # split for `-S038` on the request side: the assertion is the rule.
  MAIN_EVIDENCE_ELEMENTS = %w[Identifier IssuingDate IsAbout IssuingAuthority IsConformantTo Distribution].freeze

  # What `-S063` forbids a supplementary document: the five information entities
  # its message names and the one property of the distribution, written as the
  # assertion writes them — a union, so any one of them breaks the rule.
  FORBIDDEN_OF_SUPPLEMENTARY = './sdg:IsAbout | ./sdg:IssuingAuthority | ./sdg:IsConformantTo | ' \
                               './sdg:ValidityPeriod | ./sdg:IssuingDate | ./sdg:Distribution/sdg:ConformsTo'.freeze

  # `-S037` and `-S065`, copied from the Schematron and not tightened — the
  # convention `EvidenceResponseParser::REQUEST_IDENTIFIER` states, and written
  # out here for the reason stated there: what the rules have in common is the
  # wording of the TDD, not a decision this repository takes once.
  PREFIXED_UUID = /\Aurn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # The closed lists `-S041` and `-S042` put on the subject a provider confirms
  # having matched — chapter 4.5.2 §3.3, `sdg:IsAbout`. Each assertion compares
  # the count of the elements it names against `count(child::*)`, so what it
  # refuses can only be named by taking the complement, as `-S016` and `-S043`
  # are read on either side.
  SUBJECT_ELEMENTS = {
    'NaturalPerson' => {
      rule: 'R-EDM-RESP-S041',
      admitted: %w[Identifier FamilyName GivenName DateOfBirth PlaceOfBirth].freeze,
    }.freeze,
    'LegalPerson' => {
      rule: 'R-EDM-RESP-S042',
      admitted: %w[LegalPersonIdentifier LegalName].freeze,
    }.freeze,
  }.freeze

  # Where the two rules find their subjects, relative to an object of the list
  # that holds the documents. Neither context filters on a classification, so an
  # annex naming a subject is judged exactly as the main document is — where
  # `EvidenceMetadataReading` reads the main one alone.
  SUBJECTS = SUBJECT_ELEMENTS.keys
    .map { |person| "#{EvidenceMetadataReading::EVIDENCE_METADATA}/sdg:IsAbout/sdg:#{person}" }
    .join(' | ').freeze

  private

  def packaging_violations
    [*packaged_violations, *identifier_violations, *subject_violations]
  end

  # The twenty-one rules that exist only where the packaging does: everything
  # under them names a `rim:RegistryPackageType`, which no 1.2 response carries.
  def packaged_violations
    return [] unless specification.packaged_response?

    [
      *unpackaged_objects,
      *packages_without_one_list,
      *lists_without_main_evidence,
      *objects_without_classification,
      *unknown_classification_nodes,
      *classifications_without_uuid,
      *main_evidence_without_its_elements,
      *supplementary_carrying_main_elements,
    ]
  end

  # `-S041` and `-S042`, the second family both lines publish: the rules are the
  # same, and what moves is the list the objects carrying a subject sit in.
  #
  # An element of another namespace breaks them too — the assertions count
  # `sdg:` children against every child, and the URI decides that, never the
  # prefix.
  def subject_violations
    document_objects.flat_map { |object| all(object, SUBJECTS).to_a }
      .filter_map { |subject| subject_with_unexpected_children(subject) }
  end

  def subject_with_unexpected_children(subject)
    closed = SUBJECT_ELEMENTS.fetch(subject.name)
    unexpected = unexpected_sdg_children(subject, closed.fetch(:admitted))
    return if unexpected.empty?

    violation(closed.fetch(:rule), 'subject_unexpected_children',
      person: "sdg:#{subject.name}", elements: unexpected.join(', '))
  end

  # What an assertion of the form `count(sdg:A) + count(sdg:B) = count(child::*)`
  # refuses: a child the closed list does not name. The count of each admitted
  # element is left free — two given names satisfy such a rule — and nothing of
  # another namespace is admitted, which the URI decides and never the prefix.
  #
  # `elements` counts what `child::*` counts, comments and text nodes excluded.
  def unexpected_sdg_children(node, admitted)
    node.elements
      .reject { |child| child.namespace&.href == NAMESPACES.fetch('sdg') && admitted.include?(child.name) }
      .map(&:name).uniq
  end

  # `-S033` to `-S037`, the one family both lines publish. The rules are the
  # same; what moves is the list they hang on, and the exception `-S033` grants.
  def identifier_violations
    [
      *objects_without_reference,
      *references_without_link,
      *objects_without_id,
      *ids_without_uuid,
    ]
  end

  # `-S066`: the response's own list carries packages and nothing else. No
  # status filter on the context — a deferral announcing an object here breaks
  # it too, and §2.6 asks a deferral for an empty list anyway.
  def unpackaged_objects
    top_level_objects.reject { |object| package?(object) }
      .map { |object| violation('R-EDM-RESP-S066', 'object_not_a_package', id: object_name(object)) }
  end

  # `-S046`: `count(rim:RegistryObjectList)=1`, so two lists break it as surely
  # as none.
  def packages_without_one_list
    packages.reject { |package| all(package, './rim:RegistryObjectList').one? }
      .map { |package| violation('R-EDM-RESP-S046', 'package_without_one_list', id: object_name(package)) }
  end

  # `-S047`, whose context is the nested list and not the package: a list held
  # by an object of any type is judged. It executes the floor alone,
  # `count(…)>0`, where §2.6 says « Exactly one » four lines below « At least
  # one » — so a second `MainEvidence` is reported under nothing, and an empty
  # nested list is reported here despite §2.1 allowing one. The assertion
  # decides, as `docs/carte_des_tdd.md` has it.
  def lists_without_main_evidence
    nested_lists.reject { |list| classifications_in(list).any? { |node| classifies?(node, MAIN_EVIDENCE_NODE) } }
      .map { |list| violation('R-EDM-RESP-S047', 'list_without_main_evidence', id: object_name(list.parent)) }
  end

  # `-S048`: exactly one classification under the EDM scheme, unless the object
  # is an association. The count is what the rule asserts, so two break it.
  def objects_without_classification
    nested_objects.reject { |object| association?(object) }
      .reject { |object| edm_classifications_of(object).one? }
      .map { |object| violation('R-EDM-RESP-S048', 'object_without_classification', id: object_name(object)) }
  end

  # `-S049`, hanging on a classification under the EDM scheme — one written
  # under another scheme names whatever it likes. An absent `@classificationNode`
  # breaks it too: the context filters on the scheme alone, and XPath compares a
  # missing attribute against the list as an empty node set.
  def unknown_classification_nodes
    nested_objects.flat_map { |object| edm_classifications_of(object).to_a }
      .reject { |node| CLASSIFICATION_NODES.include?(attribute(node, 'classificationNode')) }
      .map do |node|
        violation('R-EDM-RESP-S049', 'unknown_classification_node',
          node: named(attribute(node, 'classificationNode'), 'absent_value'), id: object_name(node.parent))
      end
  end

  # `-S065`, on the `id` of every classification whatever its scheme, an
  # association's included. Asserted against the attribute itself, so a
  # classification carrying none opens no context and is reported by nothing —
  # a hole kept rather than closed, as `REQUEST_IDENTIFIER` keeps its own.
  def classifications_without_uuid
    nested_classifications.filter_map do |node|
      declared = attribute(node, 'id')
      next if declared.nil? || declared.strip.match?(PREFIXED_UUID)

      violation('R-EDM-RESP-S065', 'classification_id_not_a_uuid', id: declared)
    end
  end

  # `-S033`. A success alone is asked, both lines filtering their context on the
  # status: a deferral carries no document to point at.
  def objects_without_reference
    return [] unless success?

    document_objects.reject { |object| references_an_item?(object) }
      .map { |object| violation('R-EDM-RESP-S033', 'object_without_reference', id: object_name(object)) }
  end

  # `-S034` and `-S035`, one and the same context, reported apart as the
  # Schematron reports them.
  def references_without_link
    return [] unless success?

    document_objects.flat_map { |object| item_references(object) }.flat_map do |reference|
      [
        missing_link(reference, 'href', 'R-EDM-RESP-S034', 'reference_without_href'),
        missing_link(reference, 'title', 'R-EDM-RESP-S035', 'reference_without_title'),
      ].compact
    end
  end

  def missing_link(reference, name, rule, key)
    return unless attribute(reference, name, 'xlink').nil?

    violation(rule, key, id: object_name(reference.parent))
  end

  # `-S036`, of a success alone. In 2.0.1 its context walks `//`, so the package
  # is judged beside the documents it holds; in 1.2.5 there is one level to
  # walk. Named by its `@xsi:type`, an object with no `id` having nothing else
  # to be called by.
  def objects_without_id
    return [] unless success?

    identified_objects.select { |object| attribute(object, 'id').nil? }
      .map do |object|
        violation('R-EDM-RESP-S036', 'object_without_id', type: named(object_type(object), 'untyped_object'))
      end
  end

  # `-S037`, whatever the status: the context is the `@id` attribute, which no
  # status filter precedes. Hence the couple an auditor reads in the journal —
  # a malformed `id` in a deferral names this rule and not `-S036`.
  def ids_without_uuid
    identified_objects.filter_map do |object|
      declared = attribute(object, 'id')
      next if declared.nil? || declared.strip.match?(PREFIXED_UUID)

      violation('R-EDM-RESP-S037', 'object_id_not_a_uuid', id: declared)
    end
  end

  # `-S062`. The context is the classification and not the object it sits on, so
  # an object classified `MainEvidence` twice breaks the rule twice — which is
  # what the Schematron reports, and what tells two such lines apart.
  def main_evidence_without_its_elements
    classified(MAIN_EVIDENCE_NODE).reject { |node| complete_evidence?(node.parent) }
      .map { |node| violation('R-EDM-RESP-S062', 'main_evidence_incomplete', id: object_name(node.parent)) }
  end

  # `-S063`, the converse: what the main document must carry, a supplementary
  # one must not. Neither context filters on a scheme.
  def supplementary_carrying_main_elements
    classified(*SUPPLEMENTARY_NODES).filter_map do |node|
      evidence = at(node.parent, EvidenceMetadataReading::EVIDENCE_METADATA)
      next if evidence.nil?

      forbidden = all(evidence, FORBIDDEN_OF_SUPPLEMENTARY)
      next if forbidden.empty?

      violation('R-EDM-RESP-S063', 'supplementary_with_main_elements',
        id: object_name(node.parent), elements: forbidden.map(&:name).join(', '))
    end
  end

  def complete_evidence?(object)
    evidence = at(object, EvidenceMetadataReading::EVIDENCE_METADATA)
    return false if evidence.nil?

    MAIN_EVIDENCE_ELEMENTS.all? { |name| at(evidence, "./sdg:#{name}") }
  end

  def top_level_objects = all(response, LISTED_OBJECTS)

  def nested_lists = all(response, NESTED_LISTS)

  def nested_objects = all(response, NESTED_OBJECTS)

  def packages = top_level_objects.select { |object| package?(object) }

  # The objects of the list that holds the documents: one level down with 2.0,
  # on the response's own list before that. Where `-S033` to `-S035` hang, and
  # where `-S041` and `-S042` find the subjects — the same split
  # `EvidenceMetadataReading` makes to find the metadata.
  def document_objects = specification.packaged_response? ? nested_objects : top_level_objects

  # Where `-S036` and `-S037` hang, which is every object of every list: the
  # `//` of the 2.0.1 contexts takes in the package too.
  def identified_objects
    return top_level_objects unless specification.packaged_response?

    top_level_objects + nested_objects
  end

  def item_references(object) = all(object, './rim:RepositoryItemRef')

  # 2.0.1 excepts the package and the association, neither of which points at a
  # document of its own; 1.2.5 excepts nothing, its flat list holding documents
  # and nothing else.
  def references_an_item?(object)
    return true if item_references(object).any?
    return false unless specification.packaged_response?

    package?(object) || association?(object)
  end

  def object_type(object) = attribute(object, 'type', 'xsi')

  def package?(object) = object_type(object) == PACKAGE_TYPE

  def association?(object) = object_type(object) == ASSOCIATION_TYPE

  def success? = attribute(response, 'status') == EvidenceResponseParser::SUCCESS

  def edm_classifications_of(object)
    all(object, './rim:Classification').select { |node| attribute(node, 'classificationScheme') == EDM_SCHEME }
  end

  def classifications_in(list) = all(list, './rim:RegistryObject/rim:Classification')

  # The classifications of the objects of every nested list — the context
  # `-S050`, `-S062` and `-S063` hang on. None of the three filters on a scheme.
  def classified(*nodes)
    nested_classifications.select { |node| nodes.include?(attribute(node, 'classificationNode')) }
  end

  # Every classification of every object of every nested list, whatever its
  # scheme — `-S065` judges them all, and `classified` filters this by node.
  def nested_classifications = nested_objects.flat_map { |object| all(object, './rim:Classification').to_a }

  def classifies?(node, value, scheme: nil)
    attribute(node, 'classificationNode') == value &&
      (scheme.nil? || attribute(node, 'classificationScheme') == scheme)
  end

  # How a sentence designates the object it accuses. The `@id` is what tells two
  # objects of one package apart — and is itself what some of these rules are
  # about, so its absence has to read as words rather than as a blank.
  def object_name(object) = named(attribute(object, 'id'), 'unidentified_object')
end
