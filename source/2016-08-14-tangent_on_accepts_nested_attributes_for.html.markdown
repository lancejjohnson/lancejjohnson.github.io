---
title: Tangent on `accepts_nested_attributes_for`
date: 2016-08-14 15:17 EDT
tags: rails, form objects
---

# Minor Variations on Form Submission

I've been working on creating an index card application in Rails I'm calling Cardrr. My first story to work on after getting the application scaffold, deployment, and testing framework set up is to allow the user to create cards. These cards may have one or two sides of content.

My initial approach to modeling the data is to use two different models. A `Side` has a content attribute and can be the front of a card. A `Card`, for now, is just a model that has many `Side`s. Here are the two basic models:

```ruby
class Card < ApplicationRecord
  has_many :sides
end

class Side < ApplicationRecord
  belongs_to :card
end
```

## Creating Cards with the Out-of-the-Box Rails Approach

In order to create cards, I need to present the user with a form they can complete for the content of the sides. This form is handling two different models. Rails provides a way to handle this easily with `accepts_nested_attributes_for`. I can add this class "macro" to the `Card` class allow the `Card` to receive its own attributes and attributes for associated `Side` objects.

```ruby
class Card < ApplicationRecord
  has_many :sides

  accepts_nested_attributes_for :sides
end
```

Now I can create the form to handle the creation of a card and sides.

```erb
<h1>Create a Card</h1>

<%= form_for @card do |form| %>
  <%= form.fields_for :sides do |fields| -%>
    <%= fields.text_area :content %>
  <% end %>
  <%= form.submit "Create Card" %>
<% end %>
```

The form will be using an instance of `Card` so I pass a `@card` instance variable to the call to `form_for`. The `accepts_nested_attributes_for` on `Card` allows me to use the `fields_for` method on the `FormBuilder` object. This method expects, at least, a symbol that corresponds to the association on the `@card` instance for which the form builder will create fields. The `fields_for` method yields a form builder just like the `form_for` method does. I call `text_area` on that builder passing it a symbol that corresponds to an attribute on the association object.

That was a mouthful. Said differently, `form_for` expects an object instance (`@card`), `fields_for` expects a symbol that is an accessor on the object instance (so `@card` should respond to `sides` and `sides=`), and the form builder expects a symbol that is an accessor on the association (so whatever `sides` is should respond to `content` and `content=`).

I need a controller to handle the form presentation and submission. By convention Rails expects a `new` and `create` method on the controller for these two actions. The `new` method will provide the object instance for the form and the `create` method will handle creating an instance with the user's provided content via the `params` object.

```ruby
class CardsController < ApplicationController
  def new
    @card = Card.new(sides: [Side.new, Side.new])
  end

  def create
    @card = Card.create(card_params)

    if @card.save
      redirect_to @card
    else
      render 'new'
    end
  end

  private

  def card_params
    params.require(:card).permit(sides_attributes: [:content, :is_front])
  end
end
```

Note that the `new` "action" passes two instances of `Side` to the instance of `Card`. This sets up the form to render two sets of fields for the card's association. If I provided 0 sides, there would be no fields in the form. If 10, there would be 10 sets of fields in the form.

When a user completes the form and submits it, the `params` available to the controller will look like this:

```ruby
{
  "utf8"=>"✓",
  "authenticity_token" => "jfdEecuCga67GUVaFpQOOWqSTZ/ejX1fx30uYCnUHpg8R67gPf4QoZcfiX0E/COxOZ0/cydu9TjydG6tJl+kVA==",
  "card" => {
    "sides_attributes" => {
      "0" => {"content" => "foo"},
      "1" => {"content" => "bar"}
    }
  },
  "commit" => "Create Card",
  "controller" => "cards",
  "action" => "create"
}
```

Notice the `card` key in the params hash. It has a key `sides_attributes` whose value is a hash of hashes, each of which correspond to the `content` the user submitted for in the form.

Rails will automagically handle creating the card and the associated sides from this data submitted in the form.


### An Aside on Data given to the model

What surprises me is that you can create a `Card` with a `sides_attributes` key where the value of that key is *either* an Array *or* a Hash whose keys are indices of the `Side`s. For example, consider these two specs:

```ruby
it 'creates sides with an Array of Hashes' do
  card = Card.new(sides_attributes: [
    {content: 'foo'},
    {content: 'bar'}
  ])
  card.save

  expect(card.sides[0].content).to eql 'foo'
  expect(card.sides[1].content).to eql 'bar'
end

it 'creates sides with an Hash of Hashes' do
  card = Card.new(sides_attributes: {
    "0" => {content: 'baz'},
    "1" => {content: 'qux'}
  })
  card.save

  expect(card.sides[0].content).to eql 'baz'
  expect(card.sides[1].content).to eql 'qux'
end
```

## Using a Form Object Parallel to `accepts_nested_attributes_for`

## Using a Form Object Independent of the `accepts_nested_attributes_for` Paradigm

The form object must have accessors corresponding to fields in the form to use the `form_for` helper. An advantage to doing this is form object is designed to be an object backing a single user interaction. We may want to model that interaction in a way different than the specific data model itself. In other words, the model is a `Card` that `has_many` `Side`s. But perhaps in the creation of a card we want to think about just a `front` and a `back`. A Form Object allows us to model this interaction in this way.

```ruby
class CardCreator
  include ActiveModel::Model

  attr_accessor :front, :back
end
```

We include the `ActiveModel::Model` allowing us to use `form_for` etc. We define accessors for a "front" and "back" of the card. This allows the form to both read and write the "front" and "back" on the card creator.

Now we can build the form using these fields.

```erb
<%= form_for @card_creator, url: cards_path do |form| %>
  <%= form.text_area :front %>
  <%= form.text_area :back %>

  <%= form.submit "Create Card" %>
<% end %>
```

We pass the `CardCreator` instance to the `form_for` as the object for the form. We need to explicitly specify the url the form will be submitted to. Finally, we add the text areas for the front and back of the card.

When we submit this form, the `params` sent to the controller will look like this:

```ruby
{
  "utf8"=>"✓", "authenticity_token"=>"RtcQ8woy5DgOD/vQhha8fyFcfoZRk/5xMG7uULDs1O73Z/pq/E51NyIJN/eUfpH3clMMaqhwdhYFZ66dv2duIg==",
  "card_creator"=> {
    "front"=>"foo",
    "back"=>"bar"
  },
  "commit"=>"Create Card",
  "controller"=>"cards",
  "action"=>"create"
}
```

Notice the `params` now have a `card_creator` key that is a hash with `front` and `back` key-value pairs.

For the case of creating cards, I think I prefer the `accepts_nested_attributes_for` paradigm within the form object even though the hash-of-hashes params surprises me. I wanted to document how I could change the form object to use a paradigm other than the `accepts_nested_attributes_for` paradigm.


<!-- NOTE: Below are basically failed notes that need to be cleaned up or removed. -->


## Customizing the Form and the Form Object to NOT Conform to the Rails Pattern

```ruby
<%= form_for @card_creator, url: cards_path do |form| %>
  <%= form.text_area :sides, :front %>
  <%= form.text_area :sides, :back %>
<% end %>
```

Rails expects `@card_creator` to respond to `sides=` and expects `@card_creator.sides` to respond to `front` and `back`.

### Advantages of the Form Object


Still think I want to use a custom form and Form Object rather than forcing things into the Rails convention. Why? The CardCreator can enforce the twoness of sides.

What is necessary?

The object in `form_for` needs to have an accessor for the fields used in the form. The fields used in the form need to have accessors for attributes in the fields.


### Another Option in the Form for Adding Labels

<!-- ```ruby
<%= form_for @card do |form| %>
  <% @card.sides.each_with_index do |side, index| %>
    <%= form.fields_for :sides, side do |side_fields| %>
      <%= side_fields.label :content, "Side #{index == 0 ? 'One' : 'Two'}" %>
      <%= side_fields.text_area :content %>
    <% end %>
  <% end %>

  <%= form.submit "Create Card" %>
<% end %>
``` -->


## Change in Rails 5

In Rails 4, this works:

```ruby
class Member < ApplicationRecord
  has_many :posts
  accepts_nested_attributes_for :posts
end

class Post < ApplicationRecord
  belongs_to :member
end

params = {
  member: {
    name: 'Foo',
    posts_attributes: [
      {title: 'First title'},
      {title: 'Second title'}
    ]
  }
}

member = Member.create(params[:member])
member.persisted? # => true
member.posts.first.persisted? # => true
member.posts.first.title # => "First title"
```

In Rails 5, the following setting was added

```ruby
# config/initializers/new_framework_defaults.rb
# Require `belongs_to` associations by default. Previous versions had false.
Rails.application.config.active_record.belongs_to_required_by_default = true
```

The intent of this setting is that you would rarely want to have an object that `belongs_to` an association where that association doesn't exist.

https://github.com/rails/rails/issues/18233

That said causes the code above to rollback the db transaction because the `Member` must exist prior to the creation of the `Post`s.

To create both the `Member` and the `Post`s in one go there are a few options. First, you can override the global setting on the specific model.

```ruby
class Member < ApplicationRecord
  has_many :posts
  accepts_nested_attributes_for :posts
end

class Post < ApplicationRecord
  belongs_to :member, optional: true
end
```

This exposes you to the potential problem the change to the default setting is designed to avoid, so it seems like an option to use carefully.

Another option is to declare `inverse_of` relationships on the models.

```ruby
class Member < ApplicationRecord
  has_many :posts, inverse_of: :member
  accepts_nested_attributes_for :posts
end

class Post < ApplicationRecord
  belongs_to :member, inverse_of: :posts
end
```

You can now create `Member` and `Post` objects in one pass.
