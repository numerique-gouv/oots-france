# La version est épinglée sur un correctif précis, comme l'était celle de Node
# avant elle, et doit rester en phase avec `.ruby-version` et la matrice de
# `.github/workflows/tests.yml`. Un `ruby:4.0` flottant laisserait une image en
# cache dériver loin derrière l'intégration continue, et le symptôme serait un
# `make e2e` local qui échoue sur un Ruby que le workflow n'exerce
# jamais. Après toute montée de version ici : `docker compose build --pull web`.
FROM ruby:4.0.6-slim

# `libpq-dev` pour l'extension native de `pg`, `libyaml-dev` pour Psych,
# `build-essential` pour compiler les gems natives, `git` parce que Bundler en a
# besoin dès qu'une gem vient d'un dépôt.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential curl git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Les gems s'installent hors de `/usr/src/app`, à l'emplacement par défaut de
# l'image : la composition monte le dépôt sur ce répertoire, et des gems
# installées dessous seraient masquées par ce montage. C'est le problème que le
# volume nommé `node_modules` réglait du temps de Node ; ici il ne se pose pas.
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . /usr/src/app

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
