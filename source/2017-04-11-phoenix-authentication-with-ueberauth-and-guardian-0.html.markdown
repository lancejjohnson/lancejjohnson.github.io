---
title: Phoenix Authentication with Ueberauth and Guardian - 0
date: 2017-04-11 19:56 EDT
tags: elixir, authentication, phoenix
---

I'm learning about different options for authentication and authorization for Elixir and Phoenix applications. A popular option among the community is Ueberauth along with Guardian. <!-- Insert statement about Ueberauth --> To learn about this option, I'd like to build a basic Phoenix application that has at least the following features:

*   A user can create an account and subsequently login to that account using:
    *   email and password
    *   Google
    *   Twitter
    *   Facebook
*   When a user logs in, the user is taken to their user page.
*   When a user logs in, they are remembered for 30 days.
*   When a logged in user requests the login or signup pages, they are redirected to their user page without having to log in.
*   A user may log out.
*   When a user who has logged out visits the site again, they must present their credentials.

In this blog post, I'm going to create the basic Phoenix application, set it up to use Bootstrap, and design some basic pages.

# Setting Up the Application

I've decided the call the application Yauth, a combination of You and Auth. Why? No idea. Just go with it.

I already have Elixir and the Phoenix archive installed, so I can use the mix task to scaffold the Phoenix application.

```sh
mix phoenix.new yauth && cd yauth
mix do deps.get, ecto.create
```

Next, I'd like to set up the application to use the full version of Bootstrap. Sayo Ogunlegan has already done a great job describing how to do that in his blog post [Using Bootstrap and Sass with Phoenix Framework and Brunch][1] so I won't repeat all of the steps here. In short, I need to use npm to install sass-brunch, copycat-brunch, bootstrap-sass, and jquery. Then I need to configure the brunch file to support those changes. Sayo's blog covers all of those details.

Next, I'd like to make the home page of the application a standard Boostrap navbar page with some links to the actions I'd like to support.

# Setting up the Front-end Assets

Phoenix includes Bootstrap CSS but it doesn't include either Sass or the JavaScript in Bootstrap. I'd like to have both of those available. I'm follwing [this helpful blog post][1] to do that so I won't repeat those steps here.

[1]:https://medium.com/@b1ackmartian/using-bootstrap-and-sass-with-phoenix-framework-and-brunch-6568e7a66ca9


<!-- Gave up here. Can't decide if this first post is worth it. -->
