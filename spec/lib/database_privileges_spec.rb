require 'rails_helper'

RSpec.describe DatabasePrivileges do
  def username = 'oots_france_privileges_spec'

  def password = 'privileges_spec'

  def owner_configuration = ActiveRecord::Base.connection_db_config.configuration_hash

  def open_owner_connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(owner_configuration)

  let(:attributes) { attributes_for(:audit_event) }

  # A connection of its own, and never the suite's: a role belongs to a catalogue
  # shared by the whole cluster, so one created inside the transaction wrapping
  # an example would be invisible to the session that then authenticates with it.
  # What this one writes therefore commits, which is what the role needs and
  # what nothing else here does — the pool established below joins the
  # transactional fixtures like any other, and its rows never outlive an example.
  let(:owner) { open_owner_connection }

  # The log, read and written on the restricted connection. A model and not raw
  # SQL, so that the refusal is established against `update_all` itself: that is
  # the path `AuditEvent#readonly?` leaves open, since it emits SQL without
  # instantiating anything, and so the reason this role exists.
  let(:log) do
    stub_const('RestrictedAuditEvent', Class.new(AuditEvent)).tap do |model|
      model.establish_connection(owner_configuration.merge(username:, password:))
    end
  end

  before { described_class.new(owner, username:, password:).apply! }

  after do
    log.remove_connection
    owner.disconnect!
  end

  # The role outlives the examples and goes only once the file is done: the
  # transactional-fixtures teardown reopens the pool established above, after
  # every example, and a role dropped inside one would make that reopening fail
  # on an authentication that has nothing to do with what was being tested.
  after(:context) do
    connection = open_owner_connection
    # Takes back what was granted, in this database and on the database itself:
    # `DROP ROLE` refuses as long as a single privilege still names the role.
    connection.execute("DROP OWNED BY #{connection.quote_column_name(username)}")
    connection.execute("DROP ROLE #{connection.quote_column_name(username)}")
    connection.disconnect!
  end

  it "laisse ajouter au journal, ce qui est la raison d'être du rôle" do
    expect { log.create!(attributes) }.to change(log, :count).by(1)
  end

  it 'refuse la réécriture du journal, y compris par update_all' do
    log.create!(attributes)

    expect { log.where(exchange_id: attributes.fetch(:exchange_id)).update_all(detail: 'réécrit') }
      .to raise_error(ActiveRecord::StatementInvalid, /PG::InsufficientPrivilege/)
  end

  it "laisse effacer le journal, sans quoi la purge de l'article 17(4) ne s'exécuterait plus" do
    log.create!(attributes)

    expect { log.where(exchange_id: attributes.fetch(:exchange_id)).delete_all }.to change(log, :count).by(-1)
  end

  it 'ne restreint que le journal, et non la base entière' do
    # No row matches, and none is needed: PostgreSQL settles the privilege as the
    # executor opens the relation, before it scans a single row.
    statement = "UPDATE exchanges SET status = 'settled' WHERE id IS NULL"

    expect { log.with_connection { |connection| connection.execute(statement) } }.not_to raise_error
  end

  it 'se rejoue sans rien lever sur un rôle déjà posé' do
    expect { described_class.new(owner, username:, password:).apply! }.not_to raise_error
  end

  # The engine-level guarantee is the one the exchange log has left once
  # `readonly?` is bypassed: a table dropped from this list loses it silently,
  # nothing failing and no page changing.
  it 'couvre la table que porte le journal des échanges' do
    expect(described_class::APPEND_ONLY_TABLES).to include(AuditEvent.table_name)
  end

  describe 'les rôles qu\'elle refuse de poser' do
    # Chacun laisserait un rôle que la garantie n'atteint pas — deux qu'aucune
    # révocation ne contraint, un troisième avec lequel rien ne peut se connecter.
    it 'refuse un mot de passe vide, que PostgreSQL accepterait en PASSWORD NULL' do
      expect { described_class.new(owner, username:, password: '').apply! }
        .to raise_error(ArgumentError, /mot de passe/)
    end

    it 'refuse le rôle qui possède les tables, qui se rendrait ce qu\'on lui retire' do
      proprietaire = owner.select_value('SELECT current_user')

      expect { described_class.new(owner, username: proprietaire, password:).apply! }
        .to raise_error(ArgumentError, /possède les tables/)
    end

    it "refuse un superutilisateur, à qui aucune révocation ne s'applique" do
      owner.execute("CREATE ROLE #{owner.quote_column_name("#{username}_super")} SUPERUSER LOGIN PASSWORD 'x'")

      expect { described_class.new(owner, username: "#{username}_super", password:).apply! }
        .to raise_error(ArgumentError, /superutilisateur/)
    ensure
      owner.execute("DROP ROLE #{owner.quote_column_name("#{username}_super")}")
    end
  end
end
