---
title: deploying_to_heroku
date: 2016-08-07 20:16 EDT
tags: rails, heroku
---

<!-- According to GOOS, the first step in developing an application should always be deploying the app scaffolding. Don't wait until you are in the midst of feature development to slow down the process with getting the application deployed. -->

# Deploying a Rails Application to Heroku

<!-- TODO: Refer to previous blog post. -->

<!-- TODO: Describe why you want to deploy at this point in the application development lifecycle. -->

If you haven't already, [create a free account on Heroku](https://signup.heroku.com/dc).

## Prepare the app for deployment

<!-- NOTE: The Heroku website now says this is unnecessary for Rails 5. -->

Adding the 12 factor app gem

Add the gem to your Gemfile in the production group.

```ruby
# Gemfile
group :production do
  gem 'rails_12factor'
end
```

In your Gemfile, specify the version of Ruby you are using.

```ruby
# Gemfile
ruby '2.3.1'
```

## Setting Up a Home Route

```shell
bin/rails g controller home
```

### Controller spec

```ruby
# spec/controllers/home_controller_spec.rb
require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe "#index" do
    it "renders the home page" do
      get :index

      expect(response).to render_template :index
    end
  end
end
```

Add the action to the controller.

```ruby
# app/controllers/home_controller.rb
class HomeController < ApplicationController
  def index
  end
end
```

Add a route to the routes file.

```ruby
# config/routes.rb

root to: "home#index"
```

Run the spec.

```shell
bin/rspec
```

Rails tells you that you need to install a gem to run controller tests. Go ahead and add that to your Gemfile.

```ruby
# Gemfile
group :development, :test do
  # ...
  gem 'rails-controller-testing'
end
```

Now run `bundle install` to install the gem. Now re-run your specs.


## Setting Up Heroku

If you do not alredy have an application setup on heroku, heroku will create one for you with this command:

```bash
heroku create
```

If you have already created an application on heroku, you can add the heroku remote using this command instead.

```bash
heroku git:remote -a {name-of-app-on-heroku}
```

## Next Steps

You now have the application scaffolded and a basic route setup. The app is deployed to a production environment, even if not the final environment. Time to dive into our first feature.
