# PapaVisits
This is an implementation of the core "Home Visit Service" functionality using Elixir's `Phoenix` Framework. Below you can find details on the design as well as how to run the tests and the service itself.

- [Design](#design)
  * [Technology Choices](#technology-choices)
    + [Interface](#interface)
    + [Database](#database)
    + [Authentication](#authentication)
  * [Design Choices](#design-choices)
    + [Authentication](#authentication-1)
      - [Endpoints](#endpoints)
      - [Context and Database](#context-and-database)
      - [Notes](#notes)
    + [Visits Management](#visits-management)
      - [Endpoints](#endpoints-1)
      - [Context (Business Logic)](#context--business-logic-)
      - [Database](#database-1)
    + [Testing](#testing)
    + [Dev Environment](#dev-environment)
  * [Assumptions](#assumptions)
    + [It's a demo service](#it-s-a-demo-service)
    + [Concurrency is interesting, so I focused on it](#concurrency-is-interesting--so-i-focused-on-it)
- [Running the service](#running-the-service)
  * [Getting the most basic tools installed](#getting-the-most-basic-tools-installed)
  * [Getting the next level of tools installed](#getting-the-next-level-of-tools-installed)
  * [Running the tests](#running-the-tests)
  * [Running the integration tests](#running-the-integration-tests)
  * [Running the application release](#running-the-application-release)
  * [Running the dev version of the application](#running-the-dev-version-of-the-application)
  * [Other tooling in the Makefile](#other-tooling-in-the-makefile)
  * [Using the Application](#using-the-application)
    + [Create a user](#create-a-user)
    + [Request a visit](#request-a-visit)
    + [Find and complete a visit](#find-and-complete-a-visit)
  * [Cleanup of environment](#cleanup-of-environment)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

# Design
## Technology Choices
### Interface
I opted to go with a `Phoenix` REST API. Why?
- This is what `Phoenix` does well out of the box.
- `Plug` would also work, and has less boilerplate, but I didn't want to take the extra time of:
  - Rolling my own view stuff with it.
  - Rolling my own fallback controllers for it.
  - Making `Pow` and `Ecto` work with it.

### Database
I opted for a PostgreSQL database. Why?
- I honestly haven't used MySQL with Ecto before.
- I know PostgreSQL fairly well from a developer standpoint.

### Authentication
I decided to try out adding a password based authentication system (`Pow`) with little to no authorization. Why?
- I have worked with OAuth2 + Auth0 almost exclusively, and I wanted to try something different.
- I chose `Pow` b/c I had done a proof of concept of it for a past project and it seemed promising.
- For tokens, I just implemented simple ones that use `Phoenix.Token`, with tokens expiring after 24 hours.
- As for authorization, though there is some that could be implemented, it wasn't on the top of my list for interesting things to learn and try with this service.
- As an aside, `Pow` ended up being a bit of a bad choice, as a lot of its core functionality is very tightly coupled with `Plug`, meaning I couldn't refactor some core logic to the main `PapaVisits` module easily.

## Design Choices
Here is a break down of some design decisions for various parts of the system:

### Authentication
Here is how I chose to lay out the authentication pattern.

#### Endpoints
- register user -
  - `POST /api/auth/registration` - A user creates and account with a username and password to get a token that is put in the `authorization` header.
  - Request Example: `{"email": "me@example.com", "first_name": "me", "last_name": "i", "password": "8characterpassword"}`
  - Response Example: `{"data": {"access_token": "abigtokenthatgoesintheauthorizationheader"}}`
  - Notes
    - Users are created with a default of `120` minutes in their budget.
    - This satisfies the core functionality of being able to create a user.
- create session -
  - `POST /api/auth/session` - When a user's token expires after 24 hours, they can log back in with their username and password to get a new token.
  - Request Example: `{"email": "me@example.com", "password": "8characterpassword"}`
  - Response Example: `{"data": {"access_token": "abigtokenthatgoesintheauthorizationheader"}}`
- unregister user -
  - `DELETE /api/auth/registration` - A user can delete their account and all visits and transactions owned by it.
  - Notes
    - Not gonna lie, this was mostly to help with cleanup in integration tests.
    - Deletion of a pal that is on a transaction for a visit will not delete the transaction or associated visit.
    - Clearly this would just archive a user if it were a real thing.

#### Context and Database
`Pow` covers these parts of the actual design, as it provides all of the functions and migrations for building the `users` table.

#### Notes
- The aim here was to try out a different auth system than I've typically used in the past. This service demo probably didn't need one, but I was curious to try it out.
- The token in the header takes the place of needing to pass a `user_id` parameter for endpoints that require one, like `POST /api/visit` and `PUT /api/visit/:id/complete`
- The token can not be logged-out or revoked, as I didn't implement the token peristence and revocation tracking for this. In the past I've used `Guardian` and `Guardian.DB` for this.

### Visits Management
Here is how I chose to lay out the rest of the functionality related to requesting and completing visits.

#### Endpoints
- request visit -
  - `POST /api/visit` - When a user wants to request a visit they will hit this endpoint with the visit details.
  - Request Example: `{"date": "2024-10-10", "minutes": 30, "tasks": [{"name": "laudry", "description": "help with laundry"}]}`
  - Response Example: `{"data": {"id": "a-visit-uuid", "date": "2024-10-10", "minutes": 30, "status": "requested", "tasks": [{"id": "a-task-uuid", "name": "laudry", "description": "help with laundry"}]}}`
  - Notes
    - This satisfies the core functionality of being able to request a visit.
    - This endpoint requires authentication and their own `user_id` will be pulled from their auth token.
    - A request will be denied if the minutes requested exceed the total of minutes the user has left - any outstanding visit requests they have.
    - Minutes must be postive.
    - Date must be at least today or in the future.
- list visits -
  - `GET /api/visit` -  When a user wants to know what visits they can be a pal for, they would request this endpoint.
  - Request Example: `{"user_id": "filters-by-user-id", "status": "filters-by-status"}`
  - Response Example: `{"data": [{"id": "a-visit-uuid", "date": "2024-10-10", "minutes": 30, "status": "requested", "tasks": [{"id": "a-task-uuid", "name": "laudry", "description": "help with laundry"}]}]}`
  - Notes
    - This endpoint requires authentication.
    - Largely exists so the request and complete functionality can be demonstrated more easily.
- complete visit -
  - `PUT /api/visit/:id/complete` - When a pal wants to mark a recent visit as complete they hit this endpoint with the visit id.
  - Response Example: `{"data": %{"id": "a-transaction-id", "visit": {"id": "a-visit-uuid", "user": {"id": "a-papa-id", "minutes": "minutes minus visit minutes", ...}, "date": "2024-10-10", "minutes": 30, "status": "requested", "tasks": [{"id": "a-task-uuid", "name": "laudry", "description": "help with laundry"}]}, "pal": {"id": "a-pal-id", "minutes": "minutes plus visit minutes (minus overhead)", ...}}}`
  - Notes
    - This satisfies the core functionality of being able to complete a visit.
    - This endpoint requires authentication, and the `pal_id` used in the transaction is taken from the auth headers.
    - A user can't complete their own visits, mostly b/c it's a terrible deal for them.
    - The path and method for this was not a great choice, but I'm keeping it. It likely should have been `POST /api/visit/:id/transaction`, as it technically creates a new transaction for that visit (and it's not idempotent like a `PUT` should be).
- Notes
  - All error responses are in the form `{"error": {"status": 422|401|500, "message": "error details", "errors": {"field": ["error one", "error two"]}}}`. This is largely how `CozyParams` likes to present changeset errors and how `Pow` likes to envelope responses, so I went with it.

#### Context (Business Logic)
- The main functionality (except user creation, b/c `Pow` is coupled with `Plug`) is grouped under the `PapaVisits` context module.
- This context then delegates to repo pattern modules that control creation, deletion and updating of database models.
- I tried hard to separate the input models from the database models through the use of a library called `CozyParams`. This is a pitfall made by previous maintainers of my current employer's codebase and it has locked us into some nastiness like working with unvalidated, string-keyed maps deep inside business logic.
- Even so, the actual API is fairly tightly coupled with the database models (such that I didn't even need to translate DB changesets to parameter changesets in the responses to have them be meaningful).
- I also made an effort to consider (and integration test) concurrency problems. The scenarios for this are detailed later in this README, but ultimately, I settled on `SELECT FOR UPDATE` as a pessimistic locking mechanism. Other options would have been:
  - Using postgres advisory locks as those allow the lock to be a bit more semantic. Locking while checking the total minutes used by a user doesn't make a whole lot of sense if you phrase the check as `FOR UPDATE`, so an advisory lock would allow the intention to be more clear.
  - Using "Repeatable Read" or "Serializeable" transaction isolation would likely work too, though I didn't try it. Retries of the failed transactions would be necessary in this case.

#### Database
- The models for this were kept pretty similar with the models provided in the service specification.
- I did just make it so the `user` for a transaction is recorded through the `transaction`'s visit for the sake of simplicity.
- Otherwise, I put minutes for each user in the same model as their auth details.
  - In an OAuth2 based system this likely wouldn't be an issue, since that table wouldn't really hold any auth details other than their subject id from the auth system.
  - For something like this, where the user holds real password info, etc. ideally the minutes and other business logic related stuff would have been put into another model called `Account` or `Member` for good separation and to also prep for a possible future split-off of the auth system.
  - All in all though, I just kept the model as one `User` for the sake of simplicity.

### Testing
- I mainly focused on unit testing and test driving in most functionality.
- I didn't do any mocking, so there are not really any good database failure scenario tests (lock timeouts, for example).
  - I really wanted to try a `Mox` based approach to the injecting errors via the `Ecto.Adapter` behaviour(s), but ran into some errors, and decided for the sake of time to just note that low-level database errors were not tested.
  - Another option would be the excellent library called `Mimic`, but I figued it was best not to showcase mocking since it's generally frowned-upon.
- Otherwise, I was curious about why a transaction was good enough to pass some concurrency cases in the unit tests so I built some integration tests to confirm that `FOR UPDATE` was necessary for the transactions (as built, at least).

### Dev Environment
- I typically use docker to stand-up postgres in my Elixir dev environments, but I was curious to see what it would look like to just run an `asdf` supplied copy of postgres.
- Drove the orchestration of that, tools bootstrapping and the app compile => release => start with `make`.
- The main goal of the tooling was that a user who has `asdf` and `make` (and DevTools on Mac) could just run `make test` or `make start` and just have it work.
- I'm not very pleased with how complex the `Makefile` ended up being. I think docker-compose + some elixir based tasks, such as `Divo` would have been a better choice overall from a "not everyone knows `make`" standpoint.

## Assumptions
A lot of the assumptions I had were covered in the [Design](#design) section, but here are some as they pertain to how someone would actually use the service.

### It's a demo service
- It's okay if a user creates as many accounts as they want.
- It's okay if a user can see everyone else's visit requests.
- It's okay if a user can just complete a visit without being assigned to it or otherwise validating that they even did it.

### Concurrency is interesting, so I focused on it
- In my current professional position, most concurrency issues I deal with are of the `get` and `update` race condition variety, and restricted to the same operation on the same model.
- This service has some interesting scenarios that span different endpoints, which is a fun exercise:
  - Repeated visit requests -
    - Likelihood - unlikely
    - Description - a user requests multiple visits that would exceed their budget at the same time. This should only accept one visit instead of interleaving the two requests, which makes them not consider the minutes taken by each other.
    - Notes
      - This is what requires a lock `FOR UPDATE` on a user while their minutes and visits are being checked and potentially updated (update = add new visit).
  - Repeated visited completions
    - Likelihood - unlikely
    - Description - a user (or users) complete(s) the same visit twice or more at the same time. This should only accept one completion instead of interleaving them and giving everyone a bunch of extra minutes.
    - Notes
      - This is what requires a lock `FOR UPDATE` on a visit while its status is updated.
  - A visit request + visit completion affecting the requesting user
    - Likelihood - more likely
    - Description - a user tries to request a new visit after a pal leaves, right at the same time the pal tries to mark the visit they're leaving as complete. If the process to mark a visit complete => give minutes to pal => take minutes from papa, were not done in a transaction, the "do you have enough minutes" check done in the visit request could pick up the dirty writes (depending on the write order) and allow a visit to be requested right as the other one is marked complete.
    - Notes
      - A single SELECT on the request side and a transaction on the complete side is sufficient to prevent this due to postgres' default READ COMMIT isolation, BUT the `FOR UPDATE` requirements on the user request make that very difficult to do.

# Running the service
## Getting the most basic tools installed
If you're on Mac:
- Developers tools, which includes `make`, `awk`, and other compiler related tools for installing erlang. If you don't have it, you can from the terminal with `xcode-select --install`

If you're on Linux (have not tested this):
- You'll need at least GNU `make` and `awk` and then the second steps from the

If you're on Windows (have not tested this and good luck...):
- You'll need, at a minimum the Linux Subsystem for Windows or several of the GNU for Windows utils

Then you can install:
- ASDF, which will be used to install erlang, elixir and some other helpful local dev tools. Instructions are at https://asdf-vm.com/guide/getting-started.html#_3-install-asdf
- If you don't want to use the `make` command provided, and instead want to use `mix`, `pg_ctl`, etc. directly at a minimum you will need to have `direnv` installed (you can do so in this project directory as `asdf install direnv`) and hooked into you `~/.zshrc` or `~/.bashrc`. If you use the `make` command, however, it auto loads the environment variable in `.envrc`

## Getting the next level of tools installed
If you're inclined to use the `make` command you can just run the following to bootstrap in all of the tools required to run the service.

``` shell
make bootstrap
```

The bootstrap step will also automatically kick off it finds that you don't have the `asdf` tools installed. So, for example, if you wanted to run the unit tests, you could do the following and it would bootstrap things in.

``` shell
make test
```

If `make` isn't working for you, you can instead do the following:

``` shell
asdf install
```

## Running the tests
Once you're bootstrapped in with all the tools, you can run the unit tests with

``` shell
make test
```

If `make` isn't working for you, you can instead do the following, answering yes to any interactive prompts.

``` shell
direnv allow
mix deps.get
initdb --username="${PGUSER}" --pwfile=<(echo "${PGPASSWORD}")
pg_ctl start
mix test
```

## Running the integration tests
These tests run against the actual started application, and confirm some basic concurrency scenarios that aren't easy to do when using a single node and `Ecto`'s sandbox adapter.

You can run them with the following, which will cut a release , migrate the prod database and re/start the application and a secondary application.

``` shell
make test.integration
```

If `make` isn't working for you, you can instead do the following to start up the app and its secondary (assuming you've run the unit tests and its required DB and `deps.get`).

``` shell
MIX_ENV=prod mix do ecto.create + ecto.migrate
MIX_ENV=prod mix release --overwrite papa_visits_a
MIX_ENV=prod mix release --overwrite papa_visits_b
_build/prod/rel/papa_visits_a/bin/papa_visits_a daemon
PORT=${PORT_SECONDARY} _build/prod/rel/papa_visits_b/bin/papa_visits_b daemon

mix test.integration
```

## Running the application release
This can be done via the following command, which will start the primary and secondary copies of the application and have them listen on ports `14001` and `14002`, respectively.

``` shell
make start start.secondary
```

If you're having trouble with `make`, you can do this instead and just run the primary app. If you did run the integration tests, you'll want to stop the primary and secondary first too.

``` shell
# stop the running releases, for example
pkill -afl beam.\*papa_visits

# run just the primary
MIX_ENV=prod mix do ecto.create + ecto.migrate
MIX_ENV=prod mix release --overwrite papa_visits_a
_build/prod/rel/papa_visits_a/bin/papa_visits_a daemon
```

## Running the dev version of the application
This can be done via the following command to run the dev copy of the app and attach to it with iex. This will run the application on port `14001`, so make sure you've stopped any other copies of the app you may have started in the background, first.

``` shell
# stop backgrounded releases
make stop.app.a stop.app.b

# run interactive dev version
make run.interactive
```

If you're having trouble with `make`, you can do this instead

``` shell
# stop backgrounded releases
pkill -afl beam.\*papa_visits

# run interactive dev version
mix do ecto.create + ecto.migrate
iex -S mix phx.server
```

## Other tooling in the Makefile
There are some nice to haves in the Makefile for things like
- attaching to the database, per env - `make run.db.prod`, etc.
- running the application in dev mode - `make run` and `make run.interactive`
- starting the prod release application in interctive mode - `make start.interactive`
- stopping any background runs of the app and cleaning out the database - `make clean`
- remote into the background run of the primary app - `make remote`
- run format, credo, etc. checks - `make check`
- run migrations for each env - `make migrations.dev`, etc.
- stop the primary and secondary background runs of the app and the database - `make stop`
- stop just the database - `make stop.db`
- stop just either app- `make stop.app.a`, etc.

## Using the Application
Since this is simple API, with no GUI, you'll either need Postman, or a few command line tools to use it.

This section will use the following tools to demonstrate use:
- `jq` - installed as a tool already via `asdf`
- `curl` - installed on Mac by default

### Create a user
This will create a user and get back a token, which we'll use in subsequent requests
``` shell
token=$(
curl \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{"email": "ben@example.com", "password":"longpassword", "first_name": "Ben", "last_name": "Brewer"}' \
  http://localhost:14001/api/auth/registration \
  | jq -r '.data.access_token'
)
```

### Request a visit
The created user will only have 120 minutes to spend, so keep that in mind. Using the `token` variable from the last step, I can now request a visit with the following. Note that the `Bearer` specification is no used on the header, which I noticed long after adding `Pow` token support.

``` shell
visit_id=$(
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: ${token}" \
  --request POST \
  --data '{"date": "2024-10-10", "minutes":10, "tasks": [{"name": "help me"}]}' \
  http://localhost:14001/api/visit \
  | jq -r '.data.id'
)
```

### Find and complete a visit
Now to act as a pal, we'll need to be a different user, find the visit and complete it. The final command will print the json response showing the resulting minutes for the papa and pal.

``` shell
# create a pal user and get the token for them
pal_token=$(
curl \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{"email": "pal@example.com", "password":"longpassword", "first_name": "Pal", "last_name": "Amino"}' \
  http://localhost:14001/api/auth/registration \
  | jq -r '.data.access_token'
)

# look at available visits and pick the first one
pal_visit_id=$(
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: ${pal_token}" \
  --request GET \
  http://localhost:14001/api/visit \
  | jq -r '.data[0].id'
)

# complete the visit
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: ${pal_token}" \
  --request PUT \
  "http://localhost:14001/api/visit/${pal_visit_id}/complete" \
  | jq -r '.'
```

## Cleanup of environment
Once you've ran the tests and used the service to your liking, you can have it remove its running daemons and data from the system.

``` shell
make clean
```

If you're having trouble with `make` you can do this instead.

``` shell
pkill -afl beam.\*papa_visits
pg_ctl stop
rm -rf _build deps ${PGDATA}
```

Note that the `clean` will NOT remove any tools installed by `asdf` on the off chance that the versions would match something already installed on your machine.

However, if you feel very confident that none of the versions in the `.tool-versions` file match, you can run the following to get rid of the tooling too. Once again, if you have tools that you use globally or locally in any other repos with the same version this will remove them too, so be warned!

``` shell
while read tool version; do
  asdf uninstall ${tool} ${version}
done < .tool-versions
```
