module Demo
  # One of the two ways into the demonstration procedure: the console's, under
  # `/admin/demo`, open to every admitted agent, and the public site's, under
  # `/demonstration`, open to anyone. The screens are the same; what differs is
  # here — where each keeps its journey and its identity, so that one browser
  # walking both keeps two walks apart, the requester each asks under, and the
  # prefix of its named routes. Both offer every FranceConnect+ the deployment
  # declares.
  #
  # Read by more than the walk's own controllers: the return from
  # FranceConnect+ and France's preview space each serve both, and must read an
  # entrance that is not the address they answer on.
  class Entrance < Data.define(:name, :journey_key, :identity_cookie, :id_token_cookie, :route_prefix)
    CONSOLE = new(name: 'console', journey_key: :demo_journey, identity_cookie: :demo_identity,
      id_token_cookie: :demo_id_token, route_prefix: 'admin_demo')
    PUBLIC = new(name: 'public', journey_key: :public_demo_journey, identity_cookie: :public_demo_identity,
      id_token_cookie: :public_demo_id_token, route_prefix: 'demonstration')
    ALL = [CONSOLE, PUBLIC].freeze

    # The console wherever a departure kept no entrance it could be told by.
    def self.named(name) = ALL.find { |entrance| entrance.name == name.to_s } || CONSOLE

    def cookies = [identity_cookie, id_token_cookie]

    def public? = name == PUBLIC.name

    # The SIRET the requests of this entrance go out under, which
    # `DONNEES_REQUETEURS` maps to the name the request carries.
    def requester_id = public? ? Settings.public_demo_requester_id : Settings.demo_requester_id

    # Without a FranceConnect+, a visitor would have no way to identify, and the
    # public entrance does not exist.
    def open? = Settings.france_connect_instances.any?
  end
end
