require 'rails_helper'

RSpec.describe WordingConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  # The agent classified `ER`, which the parser hands the family once it has
  # counted it: what `R-EDM-REQ-C074` leaves standing.
  def received(message)
    judged(message) do |request|
      { requester_agent: request.at_xpath("./rim:Slot[@name='EvidenceRequester']//sdg:Agent[sdg:Classification='ER']",
        OotsNamespaces::NAMESPACES) }
    end
  end

  describe 'a request reduced to the wordings the family judges' do
    def reduced(title)
      requester = query_request('<sdg:Agent><sdg:Name lang="EN">A</sdg:Name></sdg:Agent>').at_xpath('*')

      described_class.new(query_request("<sdg:Title lang=\"EN\">#{title}</sdg:Title>"),
        specification: EdmSpecification::V2_0, requester_agent: requester)
    end

    it 'accepts a wording of two characters' do
      expect(reduced('OK').validate!).to be_a(described_class)
    end

    it 'refuses one of a single character, under R-EDM-REQ-C092' do
      expect { reduced('X').validate! }.to refusing('R-EDM-REQ-C092')
    end
  end

  # `R-EDM-REQ-S058`, the second walk over the document beside `C092`: no two
  # sibling elements of one local name may share a `lang`.
  describe 'two wordings of one language side by side' do
    it 'refuses two titles of the same language, under R-EDM-REQ-S058' do
      doubled = with_body do |body|
        body.sub('<sdg:Title lang="EN">Test evidence</sdg:Title>') do
          '<sdg:Title lang="EN">Test evidence</sdg:Title><sdg:Title lang="EN">Test document</sdg:Title>'
        end
      end

      expect { doubled.validate! }.to refusing('R-EDM-REQ-S058')
    end

    # The context names no ancestor, so the walk reaches an agent's names as
    # much as an evidence type's titles.
    it 'refuses two names of one language on an agent, under the same rule' do
      doubled = with_body do |body|
        body.sub('<sdg:Name lang="FR">Fournisseur de test</sdg:Name>') do
          '<sdg:Name lang="FR">Fournisseur de test</sdg:Name><sdg:Name lang="FR">Autre nom</sdg:Name>'
        end
      end

      expect { doubled.validate! }.to refusing('R-EDM-REQ-S058')
    end

    # Which is the whole point of the cardinality the schema gives these
    # elements: two languages are what `1..n` is for.
    it 'accepts two titles of two languages, which the reference request carries' do
      expect(request.validate!).to be(request)
    end

    # `@lang` without a namespace is what the assertion names, so the
    # `rim:LocalizedString` of a 1.2 `Procedure` slot — which carries `xml:lang`
    # — is not in its context at all.
    it 'says nothing of two xml:lang attributes, which it does not reach' do
      expect(received(earlier_line_envelope).validate!).to be_a(described_class)
    end
  end

  # `R-EDM-REQ-C092` (FATAL), one rule and one walk: every wording the request
  # carries is at least two characters once normalised — one for the two
  # elements the test excepts by name — and the twenty-one element names its
  # context lists are reached wherever they sit. The readers that visit some of
  # them keep their own sentence and run first; this is the net under everywhere
  # they do not go.
  describe 'the length of the wordings' do
    def titled(value) = with_body { |body| body.sub(/(<sdg:Title lang="FR">)[^<]*/) { "#{Regexp.last_match(1)}#{value}" } }

    it 'refuses a title of the requested evidence type, under R-EDM-REQ-C092' do
      expect { titled('X').validate! }.to refusing('R-EDM-REQ-C092')
    end

    # Le test demande `> 1`, donc deux caractères passent et un seul non. Épinglé
    # à la frontière : sans cet exemple, un lecteur qui demanderait trois
    # caractères refuserait ce qu'un État membre a le droit d'envoyer, et rien ne
    # le dirait.
    it 'accepts a title of exactly two characters' do
      served = titled('XX')

      expect(served.validate!).to be(served)
    end

    # Nothing reads this element in `validate!` at all: `NaturalPerson` measures
    # it where the subject is read, and refuses it naming no rule.
    it 'refuses a place of birth of one character' do
      born = with_body { |body| body.sub('</sdg:DateOfBirth>', '</sdg:DateOfBirth><sdg:PlaceOfBirth>P</sdg:PlaceOfBirth>') }

      expect { born.validate! }.to refusing('R-EDM-REQ-C092')
    end

    # The disjunction of the test names `sdg:LocatorDesignator` and
    # `sdg:StringValue` and asks a single character of those two alone: a street
    # number one character long is conformant.
    def designated(value)
      with_requester_agent do |agent|
        agent.sub('<sdg:AdminUnitLevel1>', "<sdg:LocatorDesignator>#{value}</sdg:LocatorDesignator><sdg:AdminUnitLevel1>")
      end
    end

    it 'accepts a locator designator of one character' do
      numbered = designated('7')

      expect(numbered.validate!).to be(numbered)
    end

    # L'autre des deux, sans quoi rien ne dirait qu'il est bien dans la table :
    # le contexte de la règle ne porte aucun ancêtre, donc l'endroit où
    # l'élément se trouve ne change rien à ce qu'elle en demande.
    it 'accepts a string value of one character' do
      valued = with_body do |body|
        body.sub('</sdg:DateOfBirth>', '</sdg:DateOfBirth><sdg:StringValue>7</sdg:StringValue>')
      end

      expect(valued.validate!).to be(valued)
    end

    # Un caractère au minimum, donc zéro est refusé — et sous une autre phrase
    # que les dix-neuf autres éléments, « fait moins de deux caractères » n'ayant
    # aucun sens pour ceux-là. C'est le seul exemple qui atteint cette phrase.
    it 'refuses a locator designator written empty, saying it is empty' do
      expect { designated('').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError)
          .and(having_attributes(detail: 'R-EDM-REQ-C092', message: /est vide/)))
    end

    # The names of the agent classified `ER` are what this walk must leave
    # alone: `R-EDM-ERR-C027` measures them in the error response exactly as
    # `C092` measures them here, so a refusal that travelled back would be
    # signed into a message breaking a FATAL rule of its own. Every one of them,
    # and not the first alone.
    describe 'the names of the requesting agent' do
      let(:second) { with_second_requester_name('<sdg:Name lang="EN">A</sdg:Name>') }

      it 'says nothing of a second name of one character' do
        expect(second.validate!).to be_truthy
      end
    end
  end

  # `R-EDM-REQ-C092` reaches a requirement's wordings too, its context naming
  # `sdg:Name` and `sdg:Description` among twenty-one others and no ancestor,
  # where `RequirementConformance` judges their language alone.
  it 'refuses a requirement description of one character, under R-EDM-REQ-C092' do
    described = with_body do |body|
      body.sub(%r{(<rim:Slot name="Requirements">.*?)<sdg:Name.*?</sdg:Name>}m) do
        "#{Regexp.last_match(1)}<sdg:Name lang=\"EN\">Proof of diploma</sdg:Name><sdg:Description lang=\"EN\">B</sdg:Description>"
      end
    end

    expect { described.validate! }.to refusing('R-EDM-REQ-C092')
  end

  # The provider classifications, under a rule of another family.
  describe 'the provider classifications, under the wordings' do
    # `R-EDM-REQ-C092` reaches this description as it reaches every other
    # wording: its context names `sdg:Description` and no ancestor at all,
    # where `ClassificationConformance` judges the language alone.
    it 'refuses a classification description of one character, under R-EDM-REQ-C092' do
      described = classification(descriptions: '<sdg:Description lang="EN">C</sdg:Description>')

      expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C092')
    end
  end
end
