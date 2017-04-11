---
title: Adding Students
date: 2016-12-13 07:45 EST
tags:
---

I've come to the point in Inskool where I need to create students. I'd like to use a Form Object to back this user interaction. As always, naming things is hard. The best naming of form objects I've seen is from the thoughtbot examples. When a user is registering, the form object backing that interaction is a `Registration` object. My user is adding a student. Calling this an `Enrollment` would be more than is called for in this situation. For now, I'm going to use `StudentAddition` though I may need to go back later to refactor this to make the form suitable for other purposes.

What is a form object? A form object is a Plain Old Ruby Object that encapsulates the validation and persistence of data needed for a specific user interaction. The advantages of form objects are:

*   Prevent bloat in models by separating out concerns for a specific interaction rather than loading the model with concerns for *every* interaction it may be involed in.
*   Making the interaction easier to reason about by isolating all the code for a specific interaction in a single object.

## What is the Form Object Responsible For?

The main responsibility of a form object is the back a specific user interaction. What does that mean? In this case the user is creating a new student. The `StudentAddition` object is responsible to back that interaction. To do so, it will need to be available for use in these places

1.  the form presented to the user
2.  the controller who instantiates it and sends it messages

### Presenting the Form to the User

In order to present the form to the user, the form helper expects the model to respond to the fields it presents. If the form presents a `:name` field, the form object needs to respond to `name`.

The student model is currently very simple. When a user creates a student, Inskool will ask for the student's first and last name. Let's create the form for this interaction:

```html
<h1>Add a student</h1>

<%= simple_form_for @addition do |f| %>
  <%= f.input :first_name %>
  <%= f.input :last_name %>
  <%= f.button :submit, "Add student" %>
<% end %>
```

The model for the form is an `@addition` instance. The form expects that instance to have a `first_name` and `last_name` method. This takes me into the form object itself. I'll start by building the spec for the object, expecting it to respond to the fields needed by the form.

```ruby
require "rails_helper"

RSpec.describe StudentAddition, type: :model do
  subject { described_class.new }

  it { is_expected.to respond_to :first_name }
  it { is_expected.to respond_to :first_name= }
  it { is_expected.to respond_to :last_name }
  it { is_expected.to respond_to :last_name= }
end
```

Now I'll build the form object itself and provide the accessors to make this test pass.

```ruby
class StudentAddition
  attr_accessor :first_name, :last_name
end
```

I try to load this in the browser and get an error. The form infers the action url from the model given to the form. The app doesn't have a route for student_additions so it raises an exception.

There are (at least) two ways to solve this:

1. Provide the url to the form explicitly
2. Provide Rails what it needs to infer the action url from the form object by adding a `self.class_name` method and telling it the `student` class.

I prefer the first of these options for now so I'll tell the form explicitly where it will send the data.

```html
<%= simple_form_for @addition, url: students_path do |f| %>
  <%# ... %>
<% end %>
```

### Being Available to the Controller

The second thing the form object must do to fulfill its role of backing a user interaction is be available to the controller in ways it expects. To flesh this out, I'll write the controller actions for `new` and `create`.

```ruby
class StudentsController < ApplicationController
  def new
    @addition = StudentAddition.new
  end

  def create
    @addition = StudentAddition.new(params)

    if @addition.save
      redirect_to @addition.student
    else
      render "new"
    end
  end
end
```
