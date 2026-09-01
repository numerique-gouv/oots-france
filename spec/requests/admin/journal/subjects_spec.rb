require 'rails_helper'

RSpec.describe 'Admin::Journal::Subjects' do
  before { sign_in }

  let(:person) { { family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01' } }

  it 'finds every exchange concerning a person' do
    matching = create(:audit_event, :about_a_person, exchange_id: 'la-sienne')
    other = create(:audit_event, exchange_id: 'une-other')

    get admin_journal_subjects_path(person)

    expect(response.body).to include(matching.exchange_id)
    expect(response.body).not_to include(other.exchange_id)
  end

  # The key folds the case: two member states spell a name differently and
  # mean one person.
  it 'ignores the case the name was typed in' do
    create(:audit_event, :about_a_person, exchange_id: 'la-sienne')

    get admin_journal_subjects_path(person.merge(family_name: 'KÖNIGREICH'))

    expect(response.body).to include('la-sienne')
  end

  # Two fields build no key: searching anyway would hand back the whole journal
  # under a heading claiming the opposite.
  it 'searches nothing until all three fields are given' do
    create(:audit_event, :about_a_person, exchange_id: 'la-sienne')

    get admin_journal_subjects_path(family_name: 'Königreich', given_name: 'Ada')

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('la-sienne')
  end

  it 'names on screen a criterion it could not read' do
    get admin_journal_subjects_path(family_name: %w[a b], given_name: 'Ada', date_of_birth: '1990-01-01')

    expect(response.body).to include(CGI.escapeHTML(I18n.t('admin.journal.subjects.show.refused')))
    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.subject_search.unreadable'),
    ))
  end

  # A format the key cannot compose finds nobody: say so, rather than answer
  # "no exchange" as though the question had been asked.
  it 'refuses a date of birth that is not ISO 8601' do
    get admin_journal_subjects_path(family_name: 'Königreich', given_name: 'Ada', date_of_birth: '01/01/1990')

    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.subject_search.attributes.date_of_birth.format'),
    ))
    # And above all not the empty-search message: saying « aucun échange ne
    # concerne cette personne » of a search that never ran asserts about the
    # person what is only known about the query.
    expect(response.body).not_to include(I18n.t('admin.journal.subjects.show.empty.person'))
  end

  # The shape says nothing of the calendar, and a text field no longer says it
  # either: `1990-13-32` would compose a key matching nobody.
  it 'refuses a date of birth the calendar has not' do
    get admin_journal_subjects_path(family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-13-32')

    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.subject_search.attributes.date_of_birth.format'),
    ))
    expect(response.body).not_to include(I18n.t('admin.journal.subjects.show.empty.person'))
  end

  # Equality and nothing else: no prefix, no fragment.
  it 'matches nothing on a name that is merely close' do
    create(:audit_event, :about_a_person, exchange_id: 'la-sienne')

    get admin_journal_subjects_path(person.merge(family_name: 'Königreic'))

    expect(response.body).not_to include('la-sienne')
  end

  it 'says so when nobody matches' do
    get admin_journal_subjects_path(family_name: 'Personne', given_name: 'Nulle', date_of_birth: '1900-01-01')

    expect(response.body).to include(I18n.t('admin.journal.subjects.show.empty.person'))
  end

  # The empty state sits where the legend would: an identity named on the one
  # and called « ce sujet » on the other would contradict itself on one screen.
  it 'names the organisation when nothing concerns it either' do
    get admin_journal_subjects_path(legal_person_identifier: 'FR/DE/INCONNU')

    expect(response.body).to include(I18n.t('admin.journal.subjects.show.empty.organisation'))
  end

  # Chapter 4.5.1 allows the organisation as much as the natural person, and
  # article 17 asks the same question of it.
  it 'finds every exchange concerning an organisation' do
    matching = create(:audit_event, :about_an_organisation, exchange_id: 'la-sienne')
    other = create(:audit_event, exchange_id: 'une-autre')

    get admin_journal_subjects_path(legal_person_identifier: 'FR/DE/A2635542Y')

    expect(response.body).to include(matching.exchange_id)
    expect(response.body).not_to include(other.exchange_id)
  end

  # The legend above the results says which identity was asked about, where the
  # title and the callout above say « personne » for both forms.
  it 'names in the results the identity the form searched' do
    create(:audit_event, :about_an_organisation)

    get admin_journal_subjects_path(legal_person_identifier: 'FR/DE/A2635542Y')

    expect(response.body).to include(I18n.t('admin.journal.subjects.show.caption.organisation'))
    expect(response.body).not_to include(I18n.t('admin.journal.subjects.show.caption.person'))
  end

  it 'names the natural person in the results of her own form' do
    create(:audit_event, :about_a_person)

    get admin_journal_subjects_path(person)

    expect(response.body).to include(I18n.t('admin.journal.subjects.show.caption.person'))
  end

  it 'ignores the case the identifier was typed in' do
    create(:audit_event, :about_an_organisation, exchange_id: 'la-sienne')

    get admin_journal_subjects_path(legal_person_identifier: 'fr/de/a2635542y')

    expect(response.body).to include('la-sienne')
  end

  # Two forms on one page are one query string, so a forged address can name
  # both. Answering one of them would answer a question nobody asked.
  it 'refuses an address naming both identities at once' do
    create(:audit_event, :about_an_organisation, exchange_id: 'la-sienne')

    get admin_journal_subjects_path(**person, legal_person_identifier: 'FR/DE/A2635542Y')

    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.subject_search.both_identities'),
    ))
    expect(response.body).not_to include('la-sienne')
    expect(response.body).not_to include(I18n.t('admin.journal.subjects.show.empty.person'))
    expect(response.body).not_to include(I18n.t('admin.journal.subjects.show.empty.organisation'))
  end

  # One stray field is enough to refuse: the rejection is on `any?`, not on a
  # whole person, so that no address can slip a name past the organisation it
  # names alongside.
  it 'refuses an address leaving one field of a person beside an identifier' do
    create(:audit_event, :about_an_organisation, exchange_id: 'la-sienne')

    get admin_journal_subjects_path(family_name: 'Königreich', legal_person_identifier: 'FR/DE/A2635542Y')

    expect(response.body).to include(CGI.escapeHTML(
      I18n.t('activemodel.errors.models.subject_search.both_identities'),
    ))
    expect(response.body).not_to include('la-sienne')
  end

  # Both forms are on the page whatever was searched: the identity is chosen by
  # the button, not by a selector that would have to be set first.
  it 'offers the two forms of the page at once' do
    get admin_journal_subjects_path

    expect(response.body).to include(CGI.escapeHTML(I18n.t('admin.journal.subjects.show.person_legend')))
    expect(response.body).to include(CGI.escapeHTML(I18n.t('admin.journal.subjects.show.organisation_legend')))
  end
end
