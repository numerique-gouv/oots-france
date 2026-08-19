require 'rails_helper'

RSpec.describe 'Admin::Journal::Subjects' do
  before { sign_in }

  let(:person) { { family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01' } }

  it 'finds every exchange concerning a person' do
    matching = create(:audit_event, :about_a_person, conversation_id: 'la-sienne')
    other = create(:audit_event, conversation_id: 'une-other')

    get admin_journal_subjects_path(person)

    expect(response.body).to include(matching.conversation_id)
    expect(response.body).not_to include(other.conversation_id)
  end

  # The key folds the case: two member states spell a name differently and
  # mean one person.
  it 'ignores the case the name was typed in' do
    create(:audit_event, :about_a_person, conversation_id: 'la-sienne')

    get admin_journal_subjects_path(person.merge(family_name: 'KÖNIGREICH'))

    expect(response.body).to include('la-sienne')
  end

  # Two fields build no key: searching anyway would hand back the whole journal
  # under a heading claiming the opposite.
  it 'searches nothing until all three fields are given' do
    create(:audit_event, :about_a_person, conversation_id: 'la-sienne')

    get admin_journal_subjects_path(family_name: 'Königreich', given_name: 'Ada')

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('la-sienne')
  end

  it 'names on screen a criterion it could not read' do
    get admin_journal_subjects_path(family_name: %w[a b], given_name: 'Ada', date_of_birth: '1990-01-01')

    expect(response.body).to include(CGI.escapeHTML(I18n.t('admin.unreadable')))
  end

  # A format the key cannot compose finds nobody: say so, rather than answer
  # "no exchange" as though the question had been asked.
  it 'refuses a date of birth that is not ISO 8601' do
    get admin_journal_subjects_path(family_name: 'Königreich', given_name: 'Ada', date_of_birth: '01/01/1990')

    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.subject_search.attributes.date_of_birth.format'),
    ))
    # Et surtout pas le message de la recherche vide : dire « aucun échange ne
    # concerne cette personne » d'une recherche qui n'a pas eu lieu affirme sur
    # la personne ce qu'on ne sait que de la requête.
    expect(response.body).not_to include(I18n.t('admin.journal.subjects.show.empty'))
  end

  # Equality and nothing else: no prefix, no fragment.
  it 'matches nothing on a name that is merely close' do
    create(:audit_event, :about_a_person, conversation_id: 'la-sienne')

    get admin_journal_subjects_path(person.merge(family_name: 'Königreic'))

    expect(response.body).not_to include('la-sienne')
  end

  it 'says so when nobody matches' do
    get admin_journal_subjects_path(family_name: 'Personne', given_name: 'Nulle', date_of_birth: '1900-01-01')

    expect(response.body).to include(I18n.t('admin.journal.subjects.show.empty'))
  end
end
