SHELL = bash

# since direnv requires a bit more bootstrapping
# just do a source here
include .envrc

# some pre-reqs to determine auto-bootstrap
# no real files to track here so it's this way
tool_versions_path := $(realpath .tool-versions)
tool_versions := $(shell awk '{ print $$1 }' $(tool_versions_path))
tool_files := $(foreach tool,$(tool_versions),\
	$(shell asdf current $(tool) 2>/dev/null \
		| awk '{ print $$3 }' \
		| grep $(tool_versions_path) \
	) \
)

%: prereqs bootstrap track.start.app
	@:

darwin_and_codes = $(and $(shell uname | grep Darwin), $(shell xcode-select -p))
.PHONY: prereqs
prereqs:
ifeq (, $(darwin_and_codes))
	@echo -e Required MacOS developer tools not found. \
		Install via "xcode-select --install"
	@exit 1
endif
ifeq (,$(shell which asdf))
	@echo -e Required program "asdf" not found. \
		Install directions can be found at https://asdf-vm.com/guide/getting-started.html#_3-install-asdf
	@exit 1
endif

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

deps:
	@mix deps.get
	@MIX_ENV=prod mix deps.compile

define do-release
@echo Releasing application
@MIX_ENV=prod mix do assets.deploy + release --overwrite papa_visits_$(1)
endef

release = _build/prod/rel/papa_visits_$(1)/bin/papa_visits_$(1)
release_a = $(call release,a)
release_b = $(call release,b)
start_app = $(call release,$(1)).pid
start_app_a = $(call start_app,a)
start_app_b = $(call start_app,b)
release_files_config = $(shell find config -type f -name \*.exs)
release_files_ex = $(shell find lib -type f -name \*.ex)
release_files_assets = $(shell find assets -type f -name \*)

.PHONY: release
release: deps mix.lock $(release_files_ex) $(release_files_assets) $(release_files_config)
	@$(call do-release,a)

$(release_a): deps mix.lock $(release_files_ex) $(release_files_assets) $(release_files_config)
	@$(call do-release,a)

$(release_b): deps mix.lock $(release_files_ex) $(release_files_assets) $(release_files_config)
	@$(call do-release,b)

$(PGDATA):
	@echo Initializing psql server data
	@initdb --username="${PGUSER}" --pwfile=<(echo "${PGPASSWORD}")

.PHONY: start.db
start.db: $(PGDATA)
	@echo Starting psql server
	@pg_ctl status &>/dev/null \
		&& echo - Already started \
		|| pg_ctl start

define track-start-app
	@timeout 5 bash -c " \
		until $(call release,$(1)) pid > $(call start_app,$(1)) 2>/dev/null; do \
			rm -rf $(call start_app,$(1)); \
			sleep 1; \
		done; \
	" || echo "- Cleaned up pid file for stopped application $(1)"
endef

release_and_pid_a = $(and $(wildcard $(release_a)), $(wildcard $(start_app_a)))
release_and_pid_b = $(and $(wildcard $(release_b)), $(wildcard $(start_app_b)))
.PHONY: track.start.app
track.start.app:
ifneq (,$(release_and_pid_a))
	@echo Tracking the application status - may take several seconds
	@$(call track-start-app,a)
endif
ifneq (,$(release_and_pid_b))
	@echo Tracking the secondary application status - may take several seconds
	@$(call track-start-app,b)
endif

define do-start
	$(call release,$(1)) $(2) $(3)
endef

$(start_app_a): $(release_a)
	@echo Starting application
	@$(call do-start,a,restart,&>/dev/null) \
	|| $(call do-start,a,daemon)
	@$(call track-start-app,a)

$(start_app_b): export PORT = $(PORT_SECONDARY)
$(start_app_b): $(release_b)
	@echo Starting secondary application on ${PORT}
	@$(call do-start,b,restart,&>/dev/null) \
		|| $(call do-start,b,daemon)
	@$(call track-start-app,b)

.PHONY: start.app.interactive
start.app.interactive: $(release_a)
	@echo Starting application
	@$(call do-start,a,start_iex)

.PHONY: start
start: start.db migrations.prod $(start_app_a)

.PHONY: start.secondary
start.secondary: start.db migrations.prod $(start_app_b)

.PHONY: start.interactive
start.interactive: start.db migrations.prod start.app.interactive

.PHONY: remote
remote:
	@$(release_a) remote

.PHONY: run.app
run.app:
	@echo Running application
	@MIX_ENV=dev mix phx.server

.PHONY: run.db.dev
run.db.dev: start.db migrations.dev
	psql ${PGDATABASE_DEV}

.PHONY: run.db.test
run.db.test: start.db migrations.test
	psql ${PGDATABASE_TEST}

.PHONY: run.db.prod
run.db.prod: start.db migrations.prod
	psql

.PHONY: run.app.interactive
run.app.interactive:
	@echo Running application
	@MIX_ENV=dev iex -S mix phx.server

.PHONY: run
run: start.db migrations.dev run.app

.PHONY: run.interactive
run.interactive: start.db migrations.dev run.app.interactive

.PHONY: test
test:
	@echo Running tests
	mix test

.PHONY: test.integration
test.integration: start start.secondary
	@echo Running integration tests
	mix test.integration

.PHONY: check
check:
	@echo Running checks
	@mix format --check-formatted
	@mix credo
# TODO dialyzer

.PHONY: migrations.%
migrations.%: export MIX_ENV = $*
migrations.%: deps
	@echo Migrating ${MIX_ENV} database
	mix do ecto.create + ecto.migrate

.PHONY: migrations
migrations: migrations.prod migrations.dev migrations.test

.PHONY: stop.app.a
stop.app.a:
ifneq (,$(wildcard $(start_app_a)))
	@echo Stopping the application
	@$(release_a) stop || echo - Already stopped
	@rm -rf $(start_app_a)
endif

.PHONY: stop.app.b
stop.app.b:
ifneq (,$(wildcard $(start_app_b)))
	@echo Stopping the secondary application
	@$(release_b) stop || echo - Already stopped
	@rm -rf $(start_app_b)
endif

.PHONY: stop.db
stop.db:
	@echo Stopping psql server
	@pg_ctl status &>/dev/null \
		&& pg_ctl --silent stop \
		|| echo - Already stopped

.PHONY: stop
stop: stop.app.a stop.app.b stop.db

.PHONY: clean.db
clean.db: stop.db
	@echo Cleaning postgres data
	@rm -rf ${PGDATA}

.PHONY: clean
clean: stop clean.db
	@echo Cleaning build and deps
	@rm -rf _build deps
