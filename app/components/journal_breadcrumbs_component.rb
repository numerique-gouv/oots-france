# The trail the pages of the exchange log hang from — its events, the search by
# person, and the exchanges they add up to.
class JournalBreadcrumbsComponent < AdminBreadcrumbsComponent
  private

  def section
    [t('admin.journal.events.index.title'), helpers.admin_journal_root_path]
  end
end
