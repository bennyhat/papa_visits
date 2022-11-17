SHELL = bash
RELEASE = _build/shared/rel/papa_visits/bin/papa_visits

# since direnv requires a bit more bootstrapping
# just do a source here
include .envrc

# some pre-reqs to determine auto-bootstrap
tool_versions_path := $(realpath .tool-versions)
tool_versions := $(shell awk '{ print $$1 }' $(tool_versions_path))
tool_files := $(foreach tool,$(tool_versions),\
	$(shell asdf current $(tool) 2>/dev/null \
		| awk '{ print $$3 }' \
		| grep $(tool_versions_path) \
	) \
)

.PHONY: all
%: bootstrap
	@:

.PHONY: bootstrap
bootstrap:
ifneq ($(words $(tool_versions)), $(words $(tool_files)))
	@echo Installings tools
	@asdf install

	@echo Installing pre-commit hooks
	@pre-commit install

	@echo Installing hex and rebar
	@mix local.hex --force
	@mix local.rebar --force
endif

.PHONY: deps
deps:
	@mix deps.get
	@mix deps.compile

.PHONY: compile.%
compile.%: MIX_ENV=$*
compile.%:
	@echo Compiling with ${MIX_ENV} deps
	@MIX_ENV=${MIX_ENV} mix compile --warnings-as-errors

.PHONY: compile
compile: compile.dev compile.test compile.prod

$(RELEASE):
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

.PHONY: start.app
start.app: $(RELEASE)
	@echo Starting application
	@${RELEASE} pid &>/dev/null \
		&& echo - Already started \
		|| ${RELEASE} daemon

.PHONY: start
start: start.db migrations.prod start.app

.PHONY: run.app
run.app:
	@echo Running application
	@MIX_ENV=dev mix phx.server

.PHONY: run.app.interactive
run.app.interactive:
	@echo Running application
	@MIX_ENV=dev iex -S mix phx.server

.PHONY: run
run: start.db migrations.dev run.app

.PHONY: run.interactive
run.interactive: start.db migrations.dev run.app.interactive

.PHONY: migrations.%
migrations.%: MIX_ENV=$*
migrations.%:
	@echo Migrating ${MIX_ENV} database
	@MIX_ENV=${MIX_ENV} mix do ecto.create + ecto.migrate

.PHONY: migrations
migrations: migrations.prod migrations.dev migrations.test

.PHONY: stop.app
stop.app:
	@echo Stopping application
	@${RELEASE} pid &>/dev/null \
		&& ${RELEASE} stop \
		|| echo - Already stopped

.PHONY: stop.db
stop.db:
	@echo Stopping psql server
	@pg_ctl status &>/dev/null \
		&& pg_ctl --silent stop \
		|| echo - Already stopped

.PHONY: stop
stop: stop.app stop.db

.PHONY: clean.db
clean.db: stop.db
	@echo Cleaning postgres data
	@rm -rf ${PGDATA}/*

.PHONY: clean
clean: stop clean.db
	@echo Cleaning build and deps
	@rm -rf _build deps

.PHONY: purge
purge: clean
	@echo Uninstalling pre-commit checks:
	@pre-commit uninstall
