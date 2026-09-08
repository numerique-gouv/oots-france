require Rails.root.join('spec/support/code_list_stubs')

# The demonstration scenario gives itself the code list the page reads.
# `spec/rails_helper.rb` does the same for RSpec, which does not load this
# directory.
World(CodeListStubs)
