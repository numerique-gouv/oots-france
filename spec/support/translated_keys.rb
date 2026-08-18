# What every guard against a key composed at run time asserts: `i18n-tasks`
# reads neither side of a key it never sees written as a lookup, so each family
# gathers its own and hands them here.
# > [!IMPORTANT]
# > A guard that gathers its keys by reading source expects the call it looks
# > for to be written with its parenthesis against the method name. An argument
# > list broken over two lines, a call without parentheses — which
# > `Style/MethodCallWithArgsParentheses` allows here — or a `send` would slip
# > past it. Where that matters most, the family carries a closed list instead:
# > `ApplicationInteractor::FAILURES`, `StrictValidation::SUBJECTS`.
module TranslatedKeys
  def expect_said(keys)
    expect(keys).not_to be_empty

    # A String and not merely something present: a key that named a node rather
    # than a leaf would answer with the whole subtree, and a non-empty Hash
    # would satisfy `be_present` — the guard would pass on the one mistake it
    # exists to catch.
    keys.each { |key| expect(I18n.t(key, raise: true)).to be_a(String).and be_present }
  end
end

RSpec.configure { |config| config.include(TranslatedKeys) }
