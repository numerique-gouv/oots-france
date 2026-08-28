# Lays down the restricted role the traffic-serving processes connect with, and
# its privileges on the current database.
#
# The role has to be distinct from the owner of the tables for the revocation
# below to mean anything. Two distinct reasons, and the second is the one that
# bites here: an owner always holds the grant options on its own tables, so a
# privilege taken from it is one it gives itself back in a single statement;
# and the owner the PostgreSQL image creates from `POSTGRES_USER` is a cluster
# superuser, which is not subject to a grant at all — no re-grant needed, the
# revocation simply does not apply to it. Both are checked before anything is
# posed, because either leaves a role that exists, connects, and protects
# nothing.
#
# Replayed after every migration, and not once at installation: `GRANT … ON ALL
# TABLES` names the tables that exist when it runs, and says nothing of a table
# created afterwards.
class DatabasePrivileges
  # The tables the role may add to and read, never rewrite. Article 28(6) of the
  # implementing regulation asks for the integrity of the OOTS logs; chapter 4.8
  # §5 carries the requirement without prescribing any measure for it.
  APPEND_ONLY_TABLES = %w[audit_events].freeze

  def initialize(connection, username:, password:)
    @connection = connection
    @username = username
    @password = password
  end

  def apply!
    reject_unless_restrictable

    connection.transaction do
      declare_role
      grant_read_and_write
      revoke_rewriting_of_append_only_tables
    end
  end

  private

  attr_reader :connection, :username, :password

  # Three ways to end up with a role the guarantee never reaches. The blank
  # password is the odd one out: `PASSWORD NULL` is valid SQL and poses a role
  # whose password authentication can never succeed, so `apply!` would report
  # success on a role `web` and `worker` then fail to connect with.
  def reject_unless_restrictable
    refuse('Le rôle applicatif et son mot de passe sont obligatoires.') if username.blank? || password.blank?
    refuse("#{username} possède les tables : il reprendrait à volonté ce qu'on lui retire.") if owns_the_tables?
    refuse("#{username} est superutilisateur : aucune révocation ne s'applique à lui.") if superuser?
  end

  def owns_the_tables? = username == connection.select_value('SELECT current_user')

  def superuser? = connection.select_value("SELECT rolsuper FROM pg_roles WHERE rolname = #{literal(username)}")

  def refuse(message) = raise(ArgumentError, message)

  def declare_role
    execute("#{role_exists? ? 'ALTER' : 'CREATE'} ROLE #{role} WITH LOGIN PASSWORD #{literal(password)}")
  end

  def role_exists?
    connection.select_value("SELECT 1 FROM pg_roles WHERE rolname = #{literal(username)}").present?
  end

  def grant_read_and_write
    execute("GRANT CONNECT ON DATABASE #{identifier(connection.current_database)} TO #{role}")
    # PostgreSQL grants `USAGE` on `public` to PUBLIC out of the box, so this
    # line changes nothing on a default cluster. It is here for a cluster that
    # has taken that grant back, where everything granted below would otherwise
    # be unreachable.
    execute("GRANT USAGE ON SCHEMA public TO #{role}")
    execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{role}")
    execute("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO #{role}")
  end

  # `DELETE` stays granted, on the log as on the rest: `PurgeAuditEventsJob`
  # erases what is out of term with a `delete_all`, and a role that could not
  # delete would stop the purge from running at all. What is closed here is the
  # rewriting of a line already recorded, and that alone.
  def revoke_rewriting_of_append_only_tables
    APPEND_ONLY_TABLES.each { |table| execute("REVOKE UPDATE ON #{identifier(table)} FROM #{role}") }
  end

  def role = identifier(username)

  def identifier(name) = connection.quote_column_name(name)

  def literal(value) = connection.quote(value)

  def execute(statement) = connection.execute(statement)
end
