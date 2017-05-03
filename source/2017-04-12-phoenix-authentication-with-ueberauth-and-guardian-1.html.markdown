---
title: Phoenix Authentication with Ueberauth and Guardian 1
date: 2017-04-12 07:10 EDT
tags: elixir, phoenix, authentication
---

Now that I have my basic application scaffold in place, it's time to allow users to signup for an account using their email address and password. <!-- First commit in auth_part_1 branch is the starting point. -->

<!-- Break out the login portion into a separate explanation. -->

For my first iteration, I'm going to follow the directions on the README by rote because I'm unfamiliar with Ueberauth. Later, I'll come back through and refactor that implementation.

I'll express this feature in Gherkin even though I'm not going to use `white_bread`, an Elixir implementation of Cucumber.

```gherkin
Feature: Sign up for an account with email and password

  Scenario: New user signs up
    Given that I am new user on the sign up page
    When I provide my email address and password
    And I sign up
    Then I am on my account page
    And I see my email address
```

<!-- Lacks transition -->

Ueberauth describes itself this way:

> Ueberauth is two-phase authentication framework that provides a clear API - allowing for many strategies to be created and shared within the community.

The two phases of authentication are (1) an initial challenge to the user to identify themselves--what Ueberauth calls the "request" phase; and (2) confirming the data the user provides in that challenge is accurate--what Ueberauth calls the "callback" phase. Ueberauth fulfilles these phases of authentication through the use of "strategies". Each strategy library for Ueberauth implements both the request and callback phase. One such strategy is the "identity" strategy. For the "request" phase, the identity strategy presents the user with a web form to provide unique information about themselves, such as a user-created username or an email address and a user-created password. To use this strategy, my application needs to present the user with a form to provide their username and password to satisfy the "request" phase. For the callback phase, my application needs to accept the user provided information and compare that information with what it knows about the user.

In order to use Ueberauth and Ueberauth Identity--the strategy implemented for user provided information--I add those dependencies to my mix file and to the list of applications.

```elixir
# mix.exs
defmodule Yauth.Mixfile do
  # ...
  defp deps do
    [
      # ...
      {:ueberauth, "~> 0.4.0"},
      {:ueberauth_identity, "~> 0.2.3"}
    ]
  end

  # ...
  defp applications do
    [
      # ...
      :ueberauth,
      :ueberauth_identity,
    ]
  end
  # ...
end
```

Next, I acquire those dependencies with `mix`.

```elixir
$ mix do deps.get, compile
```

Ueberauth allows me to work with multiple strategies within the same application. I need to tell Ueberauth which strategies my application will be using and provide any compile-time configuration for those strategies. To do so, I add the following to my config:

```elixir
# config/config.exs
# ...
config :ueberauth, Ueberauth,
  providers: [
    identity: {
      Ueberauth.Strategy.Identity,
      [
        callback_methods: ["POST"],
        param_nesting: "user",
      ]
    }
  ]
```

Ueberauth Identity accepts a list of configurable attributes. (I still haven't found the full list of what those attributes are, but hey.) Here I configure it to use POST calls to the callback function rather than the default GET request. I also tell Ueberauth to expect the parameters under the "user" key rather than raw values. Rather than receive the parameters in a map, I'll now receive that map under the "user" key.

At this point the configuration is set up and I'm going to follow the README instructions for Ueberauth Identity woodenly to get things working and try to understand how the system works.

First, I need to create an `AuthController`. I realize this module is a placeholder for whatever controller I'd like to use in my application, but I'll go ahead and use that for now. In that controller I'll pass requests through the `Ueberauth` plug. <!-- Need to flesh out what the plug actually does -->

```elixir
# web/controllers/auth_controller.ex
defmodule Yauth.AuthController do
  use Yauth.Web, :controller
  plug Ueberauth
end
```

Next, I need to provide routes for the application. Again, I'm following the README directly.

```elixir
# web/router.ex
defmodule Yauth.Router do
  # ...
  scope "/auth", Yauth do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/identity/callback", AuthController, :identity_callback
  end
  # ...
end
```

Here I've created routes nested under the `/auth` scope. Each of the routes within the block will be preceded by `/auth`. The first two `get` routes will capture the `:provider` and bind it to a name of in the URL (e.g. `/auth/foo` binds "foo" to `provider`). The router sends the request to the `AuthController`'s `request/2` function passing in the connection and the request parameters. The last route will match only on `/auth/identity/callback` and send the request to the `AuthController`'s `identity_callback/2` function passing the connection and the request parameters. Note that the function names `request/2` and `identity_callback/2` are not required by Ueberauth. I can name them whatever I'd like by changing them in the controller and providing my name to the `Router`. For now, I'll leave them as they are described the README.

Inspecting the routes Phoenix exposes, I can see how these resolve as well as the names of the helper functions available on `Yauth.Router.Helpers`:

```sh
$ mix phoenix.routes
auth_path GET  /auth/:provider           Yauth.AuthController :request
auth_path GET  /auth/:provider/callback  Yauth.AuthController :callback
auth_path POST /auth/identity/callback   Yauth.AuthController :identity_callback
```

Notice how the routes `/auth/:provider/callback` are `GET` requests whereas the route to `/auth/identity/callback` is a `POST` request. `GET` is the default HTTP verb for Ueberauth callbacks. Recall that I configured the identity strategy to use `POST` instead.

Now that I've added Ueberauth to my dependencies and applications, configured the identity strategy, and added the routes needed by the application, I need to implment the controller to handle the incoming requests. First, I'll add the `request/2` function first. What is this function's responsibility? It needs to present the user with a form by which they may establish their identity. I'll continue using the generic language of the README and provide a "request" html page and send the intial `auth` values as nil.

```elixir
defmodule Yauth.AuthController do
  use Yauth.Web, :controller
  plug Ueberauth

  def request(conn, params) do
    render(conn, "request.html", auth: %{email: nil, password: nil})
  end
end
```

I need to create the view that will handle rendering for the `AuthController`.

```elixir
# web/views/auth_view.ex
defmodule Yauth.AuthView do
  use Yauth.Web, :view
end
```

I also need to provide the html template to render. In my initial setup I created a form under `web/templates/signup/new.html.eex`. I'm going to copy that over to the auth directory and make some adjustments.

```eex
<div class="row">
  <div class="container">
    <h1>Sign Up or Login</h1>

    <%= form_for @conn, auth_path(@conn, :identity_callback), [as: :user], fn f -> %>

      <div class="form-group">
        <label for="email">Email</label>
        <%= text_input f, :email, placeholder: "Email", class: "form-control" %>
      </div>

      <div class="form-group">
        <label for="password">Password</label>
        <%= password_input f, :password, placeholder: "Password", class: "form-control" %>
      </div>

      <%= submit "Submit", class: "btn btn-primary" %>

    <% end %>
  </div>
</div>
```

I'm creating a form for the connection, routing the form submit action to the identity callback of the `auth_path`, and telling Phoenix to gather the parameters of the form under the `user` key.

With that in place, I need to implement the `identity_callback/2` function for the `AuthController`. For what is this function responsbile? It receives the user's provided values and creates a user by storing their information in the persistent data storage. (I'll come back to signing in an existing user in the future.)

The README for Ueberauth Identity provides the following implementation:

```elixir
def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
  case validate_password(auth.credentials) do
    :ok ->
      user = %{id: auth.uid, name: name_from_auth(auth), avatar: auth.info.image}
      conn
      |> put_flash(:info, "Successfully authenticated.")
      |> put_session(:current_user, user)
      |> redirect(to: "/")
    { :error, reason } ->
      conn
      |> put_flash(:error, reason)
      |> redirect(to: "/")
  end
end
```

From this I can see that the Ueberauth plug has added an `:ueberauth_auth` key to the connection's `assigns`. Following the dot access calls I can also see that the value contains keys for `uid`, `credentials`, and `info`. This is a little unclear, so I'm going to inspect the value to get a better idea of the structure of the value and just re-render the form.

```elixir
defmodule Yauth.AuthController do
  use Yauth.Web, :controller
  plug Ueberauth

  def request(conn, _params) do
    render(conn, "request.html", user: %{email: nil, password: nil})
  end

  def identity_callback(%{assigns: %{ueberauth_auth: auth}}, params) do
    IO.inspect auth

    render(conn, "request.html", user: %{email: nil, password: nil})
  end
end
```

Here's what the full auth structure looks like when I submit `foo@foo.com` and `password` in the form:

```elixir
%Ueberauth.Auth{credentials: %Ueberauth.Auth.Credentials{expires: nil,
  expires_at: nil, other: %{password: "password", password_confirmation: nil},
  refresh_token: nil, scopes: [], secret: nil, token: nil, token_type: nil},
 extra: %Ueberauth.Auth.Extra{raw_info: %{"_csrf_token" => "OxhcKmsHFB4WOwYuXUAhYV4nJAokJgAAsOmrSAsoSIOGmwq5oMNlcQ==",
    "_utf8" => "✓",
    "user" => %{"email" => "foo@foo.com", "password" => "password"}}},
 info: %Ueberauth.Auth.Info{description: nil, email: "foo@foo.com",
  first_name: nil, image: nil, last_name: nil, location: nil, name: nil,
  nickname: nil, phone: nil, urls: %{}}, provider: :identity,
 strategy: Ueberauth.Strategy.Identity, uid: "foo@foo.com"}
```

Now that I can receive the user submitted form, I need to do the work of creating a user. I need to obtain the user's email address and password from the map Ueberauth provides. To do so, I'll add a function to a User model that handles obtaining those values, casting them to their expected data structure, validating any required values, and presenting a struct that can be persisted. Having received that value from the model, I'll add it to the repository and redirect to display that user. Should anything go wrong in the process, I'll re-render the form with any errors listed.

```elixir
def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
  cset = Yauth.User.auth_changeset(auth)
  case Yauth.Repo.insert(cset) do
    {:ok, user} ->
      redirect(conn, to: user_path(conn, :show, user))
    {:error, cset} ->
      render(conn, "request.html", user: cset)
  end
end
```

I don't have a user model yet, so I'll add that first using the generator provided by Phoenix.

```bash
mix phoenix.gen.model User users email:string encrypted_password:string
```

I need a password attribute to present to the user but I don't want to persist that plain text value. To do this, I'll add a virtual attribute to the model.

```elixir
defmodule Yauth.User do
  use Yauth.Web, :model

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :encrypted_password, :string

    timestamps()
  end
  # ...
end
```

The virtual attribute allows the form to display the field and accept a value but does't persist that value.

Next, I migrate the database.

```bash
mix ecto.migrate
```

Now I need to define the changeset that handles the auth structure. This function needs to:

*  Get the values from the map provided by Ueberauth
*  Cast and validate the struct with those values
*  Encrypt the password the user provided and add that to the struct.

Ueberauth doesn't do anything related to password encryption so I need to pull in an encryption library. I've added Comeonin to my `mix` file and acquired it with `mix deps.get`. I'll import its function into my model.

```elixir
defmodule Yauth.User do
  use Yauth.Web, :model
  import Comeonin.Bcrypt, only: [hashpwsalt: 1]

  # ...
  def auth_changeset(struct, %{provider: :identity} = auth) do
    %{info: %{email: email}, credentials: %{other: %{password: pw}}} = auth

    struct
    |> cast(%{email: email, password: pw}, [:email, :password])
    |> validate_required([:email, :password])
    |> encrypt_password()
  end

  def auth_changeset(struct, auth), do: struct

  defp encrypt_password(%{valid?: true, changes: %{password: pw}} = cset) do
    put_change(cset, :encrypted_password, hashpwsalt(pw))
  end

  defp encrypt_password(cset), do: cset
end
```

With the model set up, I need to expose the route that my auth controller redirects the user to once they've completed the signup. I'll add the route, the controller, the view, and the template:

First, the route.

```elixir
scope "/", Yauth do
  pipe_through :browser
  # ...
  get "/users/:id", UserController, :show
end
```

Then, the controller and view.

```elixir
defmodule Yauth.UserController do
  def show(conn, params) do
    user = Yauth.Repo.get(Yauth.User, user_id)
    render(conn, :show, user)
  end
end
```

```elixir
defmodule Yauth.UserView do
  use Yauth.Web, :view
end
```

Need to implement the view for the user.

```eex
<p> <%= @user.email %> </p>
```


My controller will pass the `auth` data it receives from the form submission to the model's changeset function. There I cast the data to ensure the data types are correct, validate that any required fields are present, and encrypt the password to ensure only the encrypted string is saved in the database.
