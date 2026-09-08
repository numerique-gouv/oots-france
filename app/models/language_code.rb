# The `LanguageCode` code list published with the TDD, which the rules holding a
# `lang` attribute compare to — `R-EDM-REQ-C108` for the requesting agent's name
# among them, and `R-EDM-ERR-C028` for the same name once France writes it back.
#
# Copied here rather than read through `CodeListClient`: that client answers `{}`
# on any failure, deliberately, because it serves names and « a name is an
# ornament ». A list that empties itself would make every value conformant,
# which is the opposite of what a FATAL rule asks. Same reasoning, and same
# shape, as `IdentifierScheme::LEGAL_PERSON` and
# `NaturalPerson::LEVELS_OF_ASSURANCE`.
#
# Upper case, as the list publishes them, and compared exactly: the assertions
# carry no `i` flag, where `R-EDM-REQ-C040` does. A correspondent writing
# `lang="fr"` therefore breaks the rule.
module LanguageCode
  # The published list, its duplicates removed — it names several languages
  # twice, once per ISO 639-2 variant.
  CODES = %w[
    AA AB AE AF AK AM AN AR AS AV AY AZ BA BE BG BH BI BM BN BO BR BS CA CE CH CO CR CS CU CV CY DA
    DE DV DZ EE EL EN EO ES ET EU FA FF FI FJ FO FR FY GA GD GL GN GU GV HA HE HI HO HR HT HU HY HZ
    IA ID IE IG II IK IO IS IT IU JA JV KA KG KI KJ KK KL KM KN KO KR KS KU KV KW KY LA LB LG LI LN
    LO LT LU LV MG MH MI MK ML MN MR MS MT MY NA NB ND NE NG NL NN NO NR NV NY OC OJ OM OR OS PA PI
    PL PS PT QU RM RN RO RU RW SA SC SD SE SG SI SK SL SM SN SO SQ SR SS ST SU SV SW TA TE TG TH TI
    TK TL TN TO TR TS TT TW TY UG UK UR UZ VE VI VO WA WO XH YI YO ZA ZH ZU
  ].freeze

  def self.valid?(code) = CODES.include?(code)
end
