---
title: Phoenix Authentication with Ueberauth and Guardian 1
date: 2017-04-12 07:10 EDT
tags: elixir, phoenix, authentication
---

<!-- TODO: Need to change the person. I need to be instructing my future self on how to get this done. Switch from I to you. -->

In the first post in this series on authentication in Phoenix, I covered scaffolding a basic Phoenix application and setting up some basic pages. Now it's time to allow users to signup for an account using their email address and password. <!-- First commit in auth_part_1 branch is the starting point. -->

<!-- Break out the login portion into a separate explanation. -->

For the first iteration, you will follow the directions on the README by rote to gain familiarity with Ueberauth. Later, you can refactor that implemntation to use your own preferences.

To begin, here is a description of the feature in Gherkin even though using `white_bread`, an Elixir implementation of Cucumber, is not covered in these posts.

```gherkin
Feature: Sign up for an account

  Scenario: New user signs up with email and password

    Given that I am new user on the sign up page
    When I provide my email address and password
    And I sign up
    Then I am on my account page
```

<!-- Transition needs work -->

Ueberauth helps with this task of signing up a user by providing parts of the authentication task. Ueberauth describes itself this way:

> Ueberauth is two-phase authentication framework that provides a clear API - allowing for many strategies to be created and shared within the community.

The two phases of authentication are:

1. an initial challenge to the user to identify themselves--what Ueberauth calls the "request" phase; and
2. confirming the data the user provides in that challenge is accurate--what Ueberauth calls the "callback" phase.

Ueberauth fulfills these phases of authentication through the use of "strategies". Each strategy library for Ueberauth implements both the request and callback phase. One such strategy is the "identity" strategy. For the "request" phase, the identity strategy presents the user with a web form to provide unique information about themselves, such as a user-created username or an email address and a user-created password. To use this strategy, your application needs to present the user with the form for the "request" phase then, for the callback phase, your application needs to accept the user provided information, comparing it what it knows about the user.

In order to use Ueberauth and Ueberauth Identity--the strategy implemented for user provided information--first add them to your mix file as dependencies and to the list of applications.

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

Next, acquire those dependencies with `mix`.

```elixir
$ mix do deps.get, compile
```

Ueberauth allows working with multiple strategies within the same application. You need to tell Ueberauth which strategies the application will use and provide any compile-time configuration for those strategies. To do so, add the following to your config:

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

Ueberauth Identity accepts a list of configurable attributes. <!-- TODO: Research the options (I still haven't found the full list of what those attributes are, but hey.) --> By default, Ueberauth accepts GET requests for incoming callback requests. For the web form, however, you'll want to receive a POST request instead, so you'll configure the `callback_methods` option. The parameters from the form will be at the root of the request parameters. If you prefer to nest those parameters under a specific key, you can provide that key in the `param_nesting` configuration. Rather than receive the parameters at the root of the map, you'll now receive that map under the "user" key.

At this point the configuration is set up and we'll follow the README instructions for Ueberauth Identity woodenly to get things working and try to understand how the system works.

First, create an `AuthController` that plugs Ueberauth.

```elixir
# web/controllers/auth_controller.ex
defmodule Yauth.AuthController do
  use Yauth.Web, :controller
  plug Ueberauth
end
```

This module is a placeholder for whatever controller you'd like to use in your application (e.g. `SessionController`, `SignupController`, etc.). In other words, an `AuthController` isn't *required* per se; just a controller to which your router will direct requests. That controller passes all requests through the Ueberauth plug, modifying the connection with authentication data. <!-- Need to flesh out what the plug actually does -->

Now that you have your controller, you need to provide authentication routes for the application. Again, following the README directly.

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

This creates routes nested under the `/auth` scope. Each of the routes within the block will be preceded by `/auth`. The first two `get` routes will capture the `:provider` and bind it to a name in the URL (e.g. `/auth/foo` binds "foo" to `provider`). The router sends the request to the `AuthController`'s `request/2` function passing in the connection and the request parameters. The last route will match only on `/auth/identity/callback` and send the request to the `AuthController`'s `identity_callback/2` function passing the connection and the request parameters.

Just as with the `AuthController`, the function names `request/2` and `identity_callback/2` are not required by Ueberauth. You can name them whatever you'd like provided you add them to the `Router`. For now, leave them as they are described the README.

By inspecting the routes Phoenix exposes, you can see how these resolve as well as the names of the helper functions available on `Yauth.Router.Helpers`:

```sh
$ mix phoenix.routes
auth_path GET  /auth/:provider           Yauth.AuthController :request
auth_path GET  /auth/:provider/callback  Yauth.AuthController :callback
auth_path POST /auth/identity/callback   Yauth.AuthController :identity_callback
```

Notice how the routes `/auth/:provider/callback` are `GET` requests whereas the route to `/auth/identity/callback` is a `POST` request. `GET` is the default HTTP verb for Ueberauth callbacks but you configured the identity strategy to use `POST` instead.

Now that you've added Ueberauth dependencies and applications, configured the identity strategy, and added the routes needed by the application, you need to implement the controller to handle the incoming request. First, you need the `request/2` function. What is this function's responsibility? It needs to present the user with a form by which they may establish their identity. Continue using the generic language of the README and provide a "request" html page and send the intial `auth` values as `nil`.

```elixir
defmodule Yauth.AuthController do
  use Yauth.Web, :controller
  plug Ueberauth

  def request(conn, params) do
    render(conn, "request.html", user: %{email: nil, password: nil})
  end
end
```

Create the view that will handle rendering for the `AuthController`.

```elixir
# web/views/auth_view.ex
defmodule Yauth.AuthView do
  use Yauth.Web, :view
end
```

Provide the html template to render. In the initial setup in a previous post you created a form under `web/templates/signup/new.html.eex`. Copy that over to the auth directory and make some adjustments.

```html
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

This creates a form for the connection, routing the form submit action to the identity callback of the `auth_path`, and telling Phoenix to gather the parameters of the form under the `user` key.

With that in place, you need to implement the `identity_callback/2` function for the `AuthController`. This function receives the user's provided values and creates a user by storing their information in the database. <!-- (I'll come back to signing in an existing user in the future.) -->

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
    {:error, reason} ->
      conn
      |> put_flash(:error, reason)
      |> redirect(to: "/")
  end
end
```

From this you can see that the Ueberauth plug has added an `:ueberauth_auth` key to the connection's `assigns`. Following the dot access calls, you can also see that the value contains keys for `uid`, `credentials`, and `info`. In order to see everything in this map, inspect the value in the controller to get a better idea of its structure and just re-render the form.

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

Here's what the full auth structure looks like when you submit `foo@foo.com` and `password` in the form:

```elixir
%Ueberauth.Auth{credentials: %Ueberauth.Auth.Credentials{expires: nil,
  expires_at: nil, other: %{password: "password", password_confirmation: nil},
  refresh_token: nil, scopes: [], secret: nil, token: nil, token_type: nil},
 extra: %Ueberauth.Auth.Extra{raw_info: %{"_csrf_token" => "...",
    "_utf8" => "✓",
    "user" => %{"email" => "foo@foo.com", "password" => "password"}}},
 info: %Ueberauth.Auth.Info{description: nil, email: "foo@foo.com",
  first_name: nil, image: nil, last_name: nil, location: nil, name: nil,
  nickname: nil, phone: nil, urls: %{}}, provider: :identity,
 strategy: Ueberauth.Strategy.Identity, uid: "foo@foo.com"}
```

Now that you can receive the user submitted form, you need to do the work of creating a user. Obtain the user's email address and password from the map Ueberauth provides. To do so, you'll add a function to a User model that handles obtaining those values, casting them to their expected data structure, validating any required values, and presenting a struct that can be persisted. After receiving that value from the model, add it to the repository and redirect to display that user. Should anything go wrong in the process, re-render the form with any errors listed.

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

At this point, you don't have a user model, so you'll need to create that now using the generator provided by Phoenix. You'll need a email attribute and an attribute for storing an encrypted version of the user's password.

```bash
mix phoenix.gen.model User users email:string encrypted_password:string
```

In the form, however, you need to present the user with a password attribute but you don't want to persist the plain text value. To do this, add a virtual attribute to the model.

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

With the schema in place and the migration Phoenix generated for you, you need to migrate the database.

```bash
mix ecto.migrate
```

Earlier, you called a function for creating a user changeset directly from the auth values given to the controller. Now you need to define the changeset that handles the auth structure. This function needs to:

*  Get the values from the map provided by Ueberauth
*  Cast and validate the struct with those values
*  Encrypt the password the user provided and add that to the struct.

Ueberauth doesn't do anything related to password encryption so you need to pull in an encryption library. Add Comeonin to your `mix` file and acquire it with `mix deps.get`. You'll want to use the function `Comeonin.Bcrypt.hashpwsalt/1` to encrypt the password, so import this function into the model.

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

With the model set up, you need to expose the route that the auth controller redirects the user to once they've completed the signup. Add the route, the controller, the view, and the template:

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

Your controller will pass the `auth` data it receives from the form submission to the model's changeset function. There you cast the data to ensure the data types are correct, validate that any required fields are present, and encrypt the password to ensure only the encrypted string is saved in the database.

<!-- TODO: Started "skeleton blogging" here, just noting what I'm doing but not including any of the description. -->

Allow sign in or account creation.

```elixir
def identity_callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
  case Yauth.User.auth_changeset(%Yauth.User{}, auth) do
    %{valid?: true} = user_cset ->
      case Yauth.Repo.get_by(Yauth.User, email: user_cset.changes.email) do
        nil ->
          sign_up(conn, user_cset)
        user ->
          sign_in(conn, user, user_cset)
      end
    user_cset ->
      render(conn, "request.html", user: user_cset)
  end
end

defp sign_in(conn, user, changeset) do
  if Yauth.User.valid_password?(user, changeset.changes.password) do
    redirect(conn, to: user_path(conn, :show, user))
  else
    conn
    |> put_flash(:error, "Email/password do not match.")
    |> render("request.html", user: changeset)
  end
end

defp sign_up(conn, changeset) do
  case Yauth.Repo.insert(changeset) do
    {:ok, user} ->
      redirect(conn, to: user_path(conn, :show, user))
    {:error, error_cset} ->
      render(conn, "request.html", user: error_cset)
  end
end
```



----------

Using the Router.Helper function to link to the identity route. In order to use the helper function to set up the correct route, you need to provide the URL argument to be used. In the `Router`, the route is defined like this:

```elixir
# ...
scope "/auth", Yauth do
  # ...
  get "/:provider", AuthController, :request
end
# ...
```

Using `auth_path(@conn, :request)` is insufficient because it doesn't provide the URL argument that is bound to `provider`. You must supply that argument in the function call.

```
<a href="<%= auth_path(@conn, :request, "identity") %>">Login</a>
```
