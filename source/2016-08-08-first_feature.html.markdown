---
title: The First Feature
date: 2016-08-08 17:16 EDT
tags: rails
---

# The First Feature

There are a lot of different places we could start building an application. I'm frequently tempted to go straight to building account sign up and login/logout functionality. Rather than get hung up in that process, though, let's start by diving straight in to a way the user will use the application.

Our application allows users to create "index cards" containing information they want to review. Let's start by building the most basic version of that functionality we can.

## Creating a Card

Justin Weiss in *Practicing Rails* gives useful advice in where to begin a feature. He writes:

> “When I sketch out a feature, I follow this process:
>
> 1. Take the small, core feature from earlier.
> 2. Think of one simple thing someone could do with that feature.
> 3. Draw just enough screens for that person to be able to do that thing.
> 4. Describe the path through that action, as if you were telling someone what you were going to do.
> 5. As you describe that path, write out the objects, properties of those objects, and other actions you think you need to develop that path.”

First, our feature is the ability to create an index card by entering a front and (optionally) a back side of the card. I'm not going to include the images here but basically we need a page that has a box to type the front of the card and box to type the back of the card.

Here's how we will use the feature (I'll write in "Gherkin" even though I haven't decided if I'll take the cucumber plunge yet or not):

Navigate to the create card page
Type in information for the front of the card
Type in information for the back of the card
Create the card
See the front and back of the card

### Failing Feature Spec

The first step is to create a failing feature spec. The feature spec will basically do what we just described but in code. We want it to fail so that it can drive the devolopment of our application until it passes. Rails has a generator you can use to create the spec file.

```bash
bin/rails g rspec:feature
```

```ruby
# spec/features/creates_cards_spec.rb
RSpec.feature "User creates cards", type: :feature do
  scenario "successfully" do
    side_one = "What is the first application people build?"
    side_two = "Hello world"
    # Given that I am on the create card page
    visit new_cards_path
    # When I enter "What is the first application people build?" for the front of the card
    fill_in "side_one", with: side_one
    # And I enter "Hello world" for the back of the card
    fill_in "side_two", with: side_two
    # And I create the card
    click "Create Card"
    # Then I should see the contents of the card
    expect(page).to have_content side_one
    expect(page).to have_content side_two
  end
end
```

Run the spec.

Rails tells us we need capybara.

```ruby
# Gemfile
group :development, :test do
  # ...
  gem 'capybara'
end
```

Run the spec. Fails because new_cards_path is not defined.

Define the route.

```ruby
# config/routes.rb
resource :cards
```

Run the spec. Fails:

```ruby
ActionController::RoutingError:
uninitialized constant CardsController
```

Create the CardsController.

Run the spec. Failure

1) User creates cards successfully
   Failure/Error: visit new_cards_path

   AbstractController::ActionNotFound:
     The action 'new' could not be found for CardsController

Add the `new` action to the controller.

Run the spec. Failure:


1) User creates cards successfully
   Failure/Error: visit new_cards_path

   ActionController::UnknownFormat:
     CardsController#new is missing a template for this request format and variant.


Create a view.

Run the spec. Failure:

This failure is a little obscure.

Need to create the model.

Move from feature spec to a unit spec.

## Creating the Model(s)

We've arrived at the creation of our first model. We need to represent a card.

A card is an object that with two sides. Each side may or may not contain content. Many flash card applications require that each side of a card have content. I'd like to remove that restriction to allow for greater flexibility in how users might use the application. I oftern create physical index cards that have one side of content but are not to the point of being a Q&A style card.

There are different ways this could be modeled. First, we could create a Card object that has an attribute for side one and an attribute for side two. This is a simple representation but I suspect another option would be more flexible.

Rather than make side one and two attributes of a Card, I think making a Side model and creating a relationship between Card and Side will offer greater flexibility. It also means one-sided cards will be cards related to only one side rather than an object with a nil attribute.

TODO: Card must have at least one side with content.

### Creating the Card Model

For now, a Card is an object that only has relations to other objects. It doesn't currently have any attributes itself. Use the Rails generator to create the model and it's surrounding files.

```bash
bin/rails g model Card
```

This command will generate the following files:

```bash
app/models/card.rb
db/migrate/<identifier>_create_cards.rb
spec/models/card_spec.rb
spec/factories/cards.rb
```

Open `spec/models/card_spec.rb` and create a spec.

```ruby
require 'rails_helper'

RSpec.describe Card, type: :model do
  it { is_expected.to have_many :sides }
end
```

A few things to note about this spec. First, RSpec has an "implicit subject". If a `subject` is not explicitly defined, RSpec will create a new instance of the class following `RSpec.describe`. In other words, RSpec will automagically create an instance of Card and run the expectations against that Card.

Second, the `have_many` "matcher" is provided by the Shoulda Matchers gem. The details of how the matcher works are beyond the scope of this tutorial but the matcher confirms the model has that association.

Time to run your spec. You'll notice that it fails. You should get this failure message:

1) Card should have many sides
     Failure/Error: it { is_expected.to have_many :sides }
       Expected Card to have a has_many association called sides (no association called sides)

To make the spec pass open the model file and add the `has_many` association.

```ruby
class Card < ApplicationRecord
  has_many :sides
end
```

Run the spec again and you should have a passing spec.

### Creating the Side Model

A side is an object that has content and belongs to a card.

Use the Rails generator to create this model and its surrounding files.

```bash
bin/rails g model Side content:text is_front:boolean card:references:index
```

Make a spec.

```ruby
RSpec.describe Side, type: :model do
  it { is_expected.to respond_to :content }
  it { is_expected.to respond_to :is_front? }
  it { is_expected.to belong_to :card }
end
```

Don't really know if this common in practice but I like to document the attributes of my models in the spec.

Run the spec and everything actually passes already. The generator did all the work for us.

## Form Objects

I've come to a place in development where my feature specs and my models don't match. In my feature spec I'm expecting a form for a Card to have `side_one` and `side_two` fields. But in modeling decisions a Card doesn't have these attributes.

There are two approaches I could take at this point:

1. Make Card accept nested attributes for its sides and update the feature spec to reflect that change.
2. Make a "form object" that exists solely to back this user interaction.

I have a strong trust of thoughtbot and the material they put out. They advise this rule of thumb:

> Any time you reach for `accepts_nested_attributes_for`, use a form object instead.

<!-- TODO: Write up about form objects -->


### Side Step

Really struggling with creating the form object for this interaction.

So much magic going on in Rails!

#### Trying to Explain this to myself

The "Rails way" of doing the form is to add `accepts_nested_attributes_for` to the model. (See the documentation for `fields_for`. One of the few places I've been pleased with Rails documentation.) Adding this to the model allows you to use `fields_for` in the form. Assuming `Foo` `has_one` `Bar` and `Bar` has a name attribute:

```ruby
<%= form_for @foo do |form| -%>
  <%= fields_for :bar do |fields| -%>
    <%= fields.text :name -%>
<% end %>
```

If the model has a `has_many` association, you can use `fields_for` for those associations. Assume `Foo` `has_many` `Baz`:

```ruby
<%= form_form @foo do |form| -%>
  <%= fields_for :bazs do |fields| -%>
    <%= fields.text :name -%>
<% end %>
```

Here's one tricky bit. The form will render the `name` field for as many `Baz`s are present on the `@foo` instance.

#### Using a Form Object for a `has_many` representation

To use a form object in this way and still use the `fields_for` stuff in the form, the *form object* needs to present *both* the collection of `bazs` and have a method `bazs_attributes=`

Without the attributes setter, the form will present the nested model as though it is a `has_one` relationship. I need to really sit and read the documentation to figure out why this is.



### Initial Attempt at Form Object

I'm trying to create a card along with 1..N sides. The "Rails way" to accomplish this is to use `accepts_nested_attributes_for` in the Card model. Following the advice of thoughtbot and Makandra, I wanted to use a Form Object instead.

In order to use a Form Object, I need an object that includes `ActiveModel::Model`. It needs to have accessors for anything that will be used within the form. It also needs a method `<assocation_name>_attributes=` that Rails will use both to determine whether or not the form is for one or many nested objects and to set the attribute values when the object is created with the has from the form.

Here is the Form Object:

```ruby
class CardCreator
  include ActiveModel::Model

  attr_accessor :card, :sides

  def sides
    self.sides ||= []
  end

  # {"sides_attributes"=>{"0"=>{"content"=>"foo"}, "1"=>{"content"=>"bar"}}}
  def sides_attributes=(attributes)
    binding.pry
    attributes.each do |_, side_attributes|
      sides.push(Side.create(side_attributes))
    end
  end
end
```

The controller actions:

```ruby
class CardsController
  def new
    @card_creator = CardCreator.new(sides: [Side.new, Side.new])
  end
end
```
