# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# The account a developer opens the administration space with. Not created in
# production: this password is in the repository, so seeding it there would open
# the space to whoever has read the file. A real deployment makes its own
# account in `rails console` — docs/espace_administration.md says how.
#
# Assigned rather than only created, so that replaying the seed restores the
# advertised password on an account whose own was changed.
if Rails.env.production?
  # Said rather than passed over in silence: without it, nothing distinguishes
  # a seed that deliberately skipped from one that died before reaching here.
  puts "Aucun compte d'administration n'est créé en production : voir docs/espace_administration.md"
else
  administrator = Administrator.find_or_initialize_by(email: 'admin@example.com')
  administrator.password = 'Administration-2026'
  administrator.save!

  puts "Compte d'administration : #{administrator.email} / Administration-2026"
end

# One exchange per state of `Conversation::STATUSES`, so that the administration
# space has its badges, its filters and its detail page to show. Nothing here
# ever happened: no message was built, no gateway was called, and their
# identifiers say so — a real one is a UUID that `UuidGenerator` drew, never a
# run of zeroes. An operator who meets one of these while looking into an
# incident must be able to see at a glance that there is nothing to look into.
#
# `development?` and not merely "outside production", unlike the account above:
# a test database is never looked at, and rows in it that no example asked for
# make the suite red on a developer's machine while the CI, whose database is
# never seeded, stays green. Five examples fail that way — the filter's paging
# and its no-criterion case, and the uniqueness matcher on `Conversation`.
#
# Keyed on their identifier rather than created outright, so replaying the seed
# does not pile up a second set.
if Rails.env.development?
  demonstrations = []

  [
    { status: 'delivered', country_code: 'FI', procedure_code: ProcedureCode::SYSTEM_CHECK },
    { status: 'failed', country_code: 'DE', procedure_code: ProcedureCode::SYSTEM_CHECK,
      edm_error_code: 'EDM:ERR:0004',
      error_description: "Le fournisseur n'a pas trouvé de justificatif correspondant." },
    { status: 'preview_required', country_code: 'SI', procedure_code: '01',
      preview_location: 'https://previsualisation.example.si/consentement' },
    { status: 'sent', country_code: 'NL', procedure_code: '01' },
    { status: 'pending', country_code: 'PT', procedure_code: '02' },
  ].each_with_index do |attributes, rank|
    conversation = Conversation.find_or_initialize_by(
      conversation_id: format('00000000-0000-0000-0000-%012d', rank + 1),
    )

    conversation.update!(
      attributes.merge(
        evidence_requester_id: '00000000000002',
        created_at: rank.days.ago,
        settled_at: (rank.days.ago unless attributes[:status].in?(Conversation::IN_PROGRESS)),
      ),
    )

    demonstrations << conversation
  end

  puts "#{demonstrations.count} conversations de démonstration, une par état."
end
