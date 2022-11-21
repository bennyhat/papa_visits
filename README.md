# PapaVisits

This is an implementation of the core "Home Visit Service" functionality using Elixir's `Phoenix` Framework.

## Design
### Technology Choices
The tech choices are as follows:

- A `Phoenix` REST API with JSON requests and responses. Why?
  - This is what `Phoenix` does well out of the box.
  - `Plug` would also work, and has less boilerplate, but I didn't want to take the extra time of:
    - Rolling my own view stuff with it.
    - Rolling my own fallback controllers for it.
    - Making `Pow` and `Ecto` work with it.
- A PostgreSQL database. Why?
  - I honestly haven't used MySQL with Ecto before.
  - I know PostgreSQL fairly well from a developer standpoint.
- A password based authentication system (`Pow`) with little to no authorization. Why?
  - I have worked with OAuth2 + Auth0 almost exclusively, and I wanted to try something different.
  - I chose `Pow` b/c I had done a proof of concept of it for a past project and it seemed promising.
  - For tokens, I just implemented simple ones that use `Phoenix.Token`, with tokens expiring after 24 hours.
  - As for authorization, though there is some that could be implemented, it wasn't on the top of my list for interesting things to learn and try with this service.
  - As an aside, `Pow` ended up being a bit of a bad choice, as a lot of its core functionality is very tightly coupled with `Plug`, meaning I couldn't refactor some core logic to the main `PapaVisits` module easily.

### Design choices
Here is a break down of some design decisions for various parts of the system:

- Authentication
  - Endpoints
    - register user -
      - `POST /api/auth/registration` - A user creates and account with a username and password to get a token that is put in the `authorization` header.
      - Request Example: `{"email": "me@example.com", "first_name": "me", "last_name": "i", "password": "8characterpassword"}`
      - Response Example: `{"data": {"access_token": "abigtokenthatgoesintheauthorizationheader"}}`
      - Notes
        - Users are created with a default of `120` minutes in their budget.
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
  - Notes
    - This satisfies the core functionality of being able to create a user.
    - The aim here was to try out a different auth system than I've typically used in the past. This service demo probably didn't need one, but I was curious to try it out.
    - The token in the header takes the place of needing to pass a `user_id` parameter for endpoints that require one, like `POST /api/visit` and `PUT /api/visit/:id/complete`
    - The token can not be logged-out or revoked, as I didn't implement the token peristence and revocation tracking for this. In the past I've used `Guardian` and `Guardian.DB` for this.
- Visits Management
  - Endpoints
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
      - All error responses are in the form `{"error": {"status": 422|401|500, "message": "error details", "errors": {"field": ["error one", "error two"]}}}`. This is largely how `CozyParams` likes to present changeset errors and how `Pow` likes to envelope responses, so I went with hit.
  - Context
    - The main functionality (except user creation, b/c `Pow` is coupled with `Plug`) is grouped under the `PapaVisits` context module.
    - This context then delegates to repo pattern modules that control creation, deletion and updating of database models.
    - I tried hard to separate the input models from the database models through the use of a library called `CozyParams`. This is a pitfall made by previous maintainers of my current employer's codebase and it has locked us into some nastiness like working with unvalidated, string-keyed maps deep inside business logic.
    - Even so, the actual API is fairly tightly coupled with the database models (such that I didn't even need to translate DB changesets to parameter changesets in the responses to have them be meaninful).
    - I also made an effort to consider (and integration test) concurrency problems. The scenarios for this are detailed later in this README, but ultimately, I settled on `SELECT FOR UPDATE` as a pessimistic locking mechanism. Other options would have been:
      - Using postgres advisory locks as those allow the lock to be a bit more semantic. Locking while checking the total minutes used by a user doesn't make a whole lot of sense if you phrase the check as `FOR UPDATE`, so an advisory lock would allow the intention to be more clear.
      - Using "Repeatable Read" or "Serializeable" transaction isolation would likely work too, though I didn't try it. Retries of the failed transactions would be necessary in this case.
  - Dev environment
    - I typically use docker to stand-up postgres in my Elixir dev environments, but I was curious to see what it would look like to just run an `asdf` supplied copy of postgres.
    - Drove the orchestration of that, tools bootstrapping and the app compile => release => start with `make`.
    - The main goal of the tooling was that a user who has `asdf` and `make` (and DevTools on Mac) could just run `make test` or `make start` and just have it work.
    - I'm not very pleased with how complex the `Makefile` ended up being. I think docker-compose + some elixir based tasks, such as `Divo` would have been a better choice overall from a "not everyone knows `make`" standpoint.
  - Notes

## Assumptions
A lot of the assumptions I had were covered in the "Design" section, but here are some as they pertain to how someone would actually use the service.

- It's a demo service
  - It's okay if a user creates as many accounts as they want.
  - It's okay if a user can see everyone else's visit requests.
  - It's okay if a user can just complete a visit without being assigned to it or otherwise validating that they even did it.
- Concurrency is interesting, so I focused on it
  - In my current professional position, most concurrency issues I deal with are of the `get` and `update` race condition variety, and restricted to the same operation on the same model.
  - This service has some interesting scenarios that span different endpoints, which is a fun exercise:
    - Repeated visit requests -
      - Likelihood - unlikely
      - Description - a user requests multiple visits at the same time. This should only accept one visit instead of interleaving the two requests, which makes them not consider the minutes taken by each other.
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
