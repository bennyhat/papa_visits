SHELL = bash
RELEASE = _build/shared/rel/papa_visits/bin/papa_visits

# since direnv requires a bit more bootstrapping
# just do a source here
include .envrc

.PHONY: bootstrap
bootstrap:
	@echo Installing tools via ASDF:
	@asdf install

	@echo Installing pre-commit checks:
	@pre-commit install

	@echo Installing hex and rebar:
	@mix local.hex --force
	@mix local.rebar --force

.PHONY: deps
deps:
	@mix deps.get
	@mix deps.compile

.PHONY: compile
compile:
	@echo Compiling with dev deps
	@MIX_ENV=dev mix compile --warnings-as-errors

	@echo Compiling with test deps
	@MIX_ENV=test mix compile --warnings-as-errors

	@echo Compiling with prod deps
	@MIX_ENV=prod mix compile --warnings-as-errors

.PHONY: release
release:
	@echo Releasing application
	@MIX_ENV=prod mix release

.PHONY: start.db
start.db:
	@mkdir -p ${PGDATA}

	@echo Initializing psql server data
	@ test -f ${PGDATA}/PG_VERSION \
		&& echo - Already initialized \
		|| initdb --username="${PGUSER}" --pwfile=<(echo "${PGPASSWORD}")

	@echo Starting psql server
	@pg_ctl status &>/dev/null \
		&& echo - Already started \
		|| pg_ctl start

.PHONY: start
start:
	@${MAKE} start.db

	@test -f ${RELEASE} \
		|| ${MAKE} release

	@echo Starting application
	@${RELEASE} pid &>/dev/null \
		&& echo - Already started \
		|| ${RELEASE} daemon

.PHONY: stop.db
stop.db:
	@echo Stopping psql server
	@pg_ctl status &>/dev/null \
		&& pg_ctl --silent stop \
		|| echo - Already stopped

.PHONY: stop
stop:
	@echo Stopping application
	@${RELEASE} pid &>/dev/null \
		&& ${RELEASE} stop \
		|| echo - Already stopped

	@${MAKE} stop.db

.PHONY: clean.db
clean.db:
	@${MAKE} stop.db

	@echo Cleaning postgres data
	@rm -rf ${PGDATA}/*

.PHONY: clean
clean:
	@${MAKE} stop clean.db

	@echo Cleaning build and deps
	@rm -rf _build deps

.PHONY: purge
purge:
	@${MAKE} clean

	@echo Uninstalling pre-commit checks:
	@pre-commit uninstall
