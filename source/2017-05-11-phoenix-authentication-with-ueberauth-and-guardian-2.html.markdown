---
title: Phoenix Authentication with Ueberauth and Guardian 2
date: 2017-05-11 08:31 EDT
tags: elixir, phoenix, authentication
---

In my previous two posts, I walked through setting up a basic Phoenix application that authenticates using Ueberauth with the Ueberauth Identity strategy. Next, I'm going to describe using Guardian to store the user in the session and load the user on subsequent requests. Basically, we'll be implementing remembering the user after they have signed in, load the user during requests, and the ability to sign out.

A web application "remembers" a user by storing encrypted information about the user in the "session". The session is a storage mechanism that persists on the user's web browser and that is passed back and forth between the user and the web application on each request. Each time the application receives a request, it compares the information stored in the session with what it knows about the user. If the comparison is accurate, the application can trust that request and reply to the request with information exclusive to the user.

The web application may choose to store information about the user (e.g. an encrypted form of the user's password) in a database and retrieve that information on each request. With JWT, the web application may compare the token provided from the user with its encryption mechanism. If the token matches what the application uses to sign its tokens, the web application can trust the request and decrypt the information directly.

Going to use Guardian

Install guardian

```elixir
# mix.exs
defp deps do
  [
    # ...
    {:guardian, "~> 0.14.2"},
    # ...
  ]
end

defp applications do
  [
    # ...
    :guardian,
    # ...
  ]
end
```

Configure guardian.

```elixir
# config/config.exs
config :guardian, Guardian,
  allowed_algos: ["HS512"],
  verify_module: Guardian.JWT,
  issuer: "Yauth",
  ttl: {30, :days},
  allowed_drift: 2000,
  verify_issuer: true,
  secret_key: <mix phoenix.gen.secret>, # TODO: This shouldn't be stored in source control for a production application.
  serializer: Yauth.GuardianSerializer
```


NOTE: I'm following this blog for the first pass through.

http://blog.overstuffedgorilla.com/simple-guardian/


# Sign In

Guardian is responsible for handling the session storage.

Here is the current auth controller.

```elixir
defmodule Yauth.AuthController do
  use Yauth.Web, :controller
  plug Ueberauth

  def request(conn, _params) do
    user = Yauth.User.changeset(%Yauth.User{}, %{})
    render(conn, "request.html", user: user)
  end

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
end
```

You need to add the Guardian sign in code in two places: (1) when the user signs up so they don't have to sign in again; and (2) when the user signs in.

You need to add the following to both the `sign_in/3` and the `sign_up/2` functions in the successful case.

```elixir
conn
|> Guardian.Plug.sign_in(user)
|> redirect(to: user_path(conn, :show, user))
```

> The only “Guardian” part is the Guardian.Plug.sign_in line. This line generates the JWT, stores it in the session (and on the assigns) and proceeds. At this point, you're “logged in”.

When you try to sign in, you'll receive an error. You need to have a Serializer at this point.

Update the config to specify the serializer.

Create the serializer. Must conform to the `Guardian.Serializer` behaviour, which expects a `for_token` and `from_token` functions.

Here is a basic implementation of the serializer:

```elixir
defmodule Yauth.GuardianSerializer do
  @behaviour Guardian.Serializer

  def for_token(%Yauth.User{id: id}) do
    {:ok, "User:#{id}"}
  end
  def for_token(_) do
    {:error, "Unknown resource type."}
  end

  def from_token("User:" <> id) do
    # TODO: I don't know if loading the user is strictly necessary. I think
    # having the id would be sufficient for future queries? Also, if you
    # serialize the full user object you would everything you need to display
    # and have the id to make queries for associations.
    Yauth.Repo.get(Yauth.User, id)
  end

  def from_token(_) do
    {:error, "Unknown resource type."}
  end
end
```

# Subsequent Requests

At this point, you have signed in the user, storing their information in the session. However, you aren't loading the user on subsequent requests using the information in the session.

Guardian provides this functionality.

Following the blog http://blog.overstuffedgorilla.com/simple-guardian/, there are three steps to this process:

*   find the token in the session
*   load the resource associated with the token
*   ensure authentication

Elixir provides the ability to create pipelines--series of function calls that are chained together. Guardian provides several Plugs that can be combined into an appropriate auth pipeline.

TODO: LEFTOFF on "On Request" in http://blog.overstuffedgorilla.com/simple-guardian/

Create a pipeline in the `Router` to authenticate for the browser.

```elixir
pipeline :browser_auth do  
  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.LoadResource
end
```

With the pipeline in place, you can now pipe the connection through that pipeline. `VerifySession` will ensure there are security claims in the session. `LoadResource` will use the serializer your app provides to load the resource from the JWT onto the connection. To pipe through the pipeline, set up routes that should be protected by the brower authentication.

```elixir
defmodule Yauth.Router do
  use Yauth.Web, :router

  # ...
  pipeline :browser_auth do
    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.LoadResource
  end

  # ...
  scope "/", Yauth do
    pipe_through [:browser, :browser_auth]
    get "/users/:id", UserController, :show
  end

  # ...
end
```

Now requests to `/users/:id` will be piped through the function pipelines defined by `brower` and `browser_auth`.

At this point, however, the route will not reject requests from someone other than the authenticated resource. To do that, the controllers within your protected scope need to use another plug provided by Guardian. For now, update the `UserController` to ensure that the request is authenticated.

Here's what the controller looks like at the moment.

```elixir
defmodule Yauth.UserController do
  use Yauth.Web, :controller

  def show(conn, %{"id" => user_id}) do
    user = Yauth.Repo.get(Yauth.User, user_id)
    render(conn, :show, user: user)
  end
end
```

Update the controller to use Guardian:

```elixir
defmodule Yauth.UserController do
  use Yauth.Web, :controller

  plug Guardian.Plug.EnsureAuthenticated, handler: __MODULE__

  def show(conn, %{"id" => user_id}) do
    user = Guardian.Plug.current_resource(conn)
    render(conn, :show, user: user)
  end

  def unauthenticated(conn, params) do
    conn
    |> put_status(404)
    |> put_flash("You're not authorized to view this page.")
    |> redirect(to: "/")
  end
end
```

Every request to this controller will pass the connection through the `EnsureAuthenticated` plug. If the resource is not authenticated, Guardian will call the `unauthenticated/2` function on whatever module is provided as the `:handler` option passed to the plug. In this case, use the controller itself as the `:handler` and implement the `unauthenticated/2` function to handle these cases.


## Implementing Sign Out

To implement sign out, need to first change the UI to differentiate between a signed in user and a not signed in user.


## All the Plugs


Ueberauth

*   Allows the use of various "strategies" to implement the 2-phase auth cycle of request and callback. The request gets the information from the user or provider and callback verifies the information and loads the resource.

Guardian.Plug.sign_in(conn, resource)

*   Encodes the object provided, adds the jwt to the session, sets the current resource, sets the claims of the jwt, sets the token

Guardian.Plug.sign_out

*   Removes all the information from the session for identifying this particular user.

Guardian.Plug.VerifySession

*   Examines the session for claims. If not found, it gets the jwt from the session, decodes it, and adds claims to the connection.

Guardian.Plug.LoadResource

*   Loads the resource specified in the claims added by VerifySession. Uses the serializer to deserialize the resource. The resource is then available by Guardian.Plug.current_resource.
