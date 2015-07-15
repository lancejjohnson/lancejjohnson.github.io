---
title: Getting in Touch with Anima
date: 2015-07-14 17:08 EDT
tags: json
---

# Getting in Touch with Anima


I spent some time playing with the [anima gem](https://github.com/mbj/anima)
today. At work we are experimenting with different ways of taking JSON data and
turning it into POROs or something approaching that. A colleague had used anima
in some work and the idea intrigued me.

## Anima Basics

What does anima do? To quote the readme, anima is a "Simple library to declare
read only attributes on value-objects that are initialized via attributes
hash." Let's play around with that. To follow my recent, inexplicable James
Bond kick, let's create an agent.

```ruby
require "anima"

class Agent
  include Anima.new(:name, :number)
end
```

I can now create an agent with `name` and `number` attributes.

```ruby
RSpec.describe Agent do
  describe "#initialize" do
    it "creates an agent" do
      expect {
        Agent.new(name: "Bond", number: "007")
      }.not_to raise_error
    end
  end
end
```

anima creates value objects that are read only. I should expect, then, to be
able to read attributes of my agent but not change them.

```ruby
describe "an attribute" do
  let(:agent) { Agent.new(name: "Bond", number: "007") }

  it "can be read" do
    expect(agent.number).to eql "007"
  end

  it "cannot be written" do
    expect {
      agent.number = "---"
    }.to raise_error NoMethodError
  end
end
```

Anima includes an `Anima::Update` module that allows you to update the
attributes of an object, but I'm not going to get into that here. It also
includes some object comparison methods that are worth looking into.

## Using Anima with JSON

One possible use case for anima is translating JSON data into Plain Ol' Ruby
Objects. Let's create our agent from JSON now. Assuming we have this
`agent.json` file:

```json
{
  "name": "Bond",
  "number": "007"
}
```

We can create our agent from that data

```ruby
describe "from JSON data" do
  let(:attributes) { json_fixture("agent.json") }
  specify do
    expect{ Agent.new(attributes) }.not_to raise_error
  end
end
```

While playing with JSON data I ran into a "gotcha". The hash keys you pass to
`new` must match the type used when defining in your anima object. In other words,
I declared my agent's attributes using symbols, so I need to pass a hash with
symbol keys, not string keys. For example, if we run this spec:

```ruby
describe "not symbolizing keys" do
  let(:attributes) do
    JSON.parse('{"name":"Bond","number":"007"}')
  end

  specify do
    expect { Agent.new(attributes) }.not_to raise_error
  end
end
```

we get

```plain
expected no Exception, got #<Anima::Error::Unknown: Unknown attribute(s)
["name", "number"] for Agent>
```

Had we declared our agent in this way:

```ruby
class Agent
  include Anima.new("name", "number")
end
```

the spec would pass just fine but we would always need to use
string-based hash keys for creating our agent. In my Ruby work so far, I've
encountered hashes with mixed keys with some regularity, so it's something to
be aware of when using anima.

### Some Concerns About JSON and Anima

I had two concerns about using anima with JSON data. In a Ruby application,
you are most likely getting JSON data from an external service accessed by an
HTTP request. In my experience, however, two things are likely when getting
data in this way: (1) you may not get back all key-value pairs for every
request; (2) you may get back new key-value pairs

In both cases, anima will throw an exception. To illustrate, consider these
specs:

```ruby
describe "with missing values" do
  specify do
    expect {
      Agent.new(name: "Bond")
    }.to raise_error Anima::Error::Missing
  end
end

describe "with additional values" do
  specify do
    expect {
      Agent.new(name: "Bond", number: "007", drink: "Martini")
    }.to raise_error Anima::Error::Unknown
  end
end
```

Depending on your situation, this may be exactly the behavior you are hoping
for. If I wanted to, say, allow new key-value pairs from the service to be
ignored and only use the values I have declared---say I don't care what
Bond is drinking these days---I need a way to address this. Following the work
of one of my colleagues, I'm going to monkey-patch some of anima's behavior to
drop any attributes I receive while initializing the object. To do this, I'm
going to create a module that overrides the `initialize` method.

```ruby
class Anima
  module DropsUnknowns
    def initialize(attributes = {})
      drops = attributes.keys - self.class.anima.attribute_names
      drops.each { |key| attributes.delete(key) }
      super attributes
    end
  end
end
```

Now I can include this module in my Agent:

```ruby
class FilteredAgent < Agent
  include Anima::DropsUnknowns
end
```

And I can create my agent without worrying about errors being raised when passed
key-value pairs I don't care about.

```ruby
describe "with additional values" do
  specify do
    expect {
      FilteredAgent.new(name: "Bond", number: "007", drink: "Martini")
    }.not_to raise_error Anima::Error::Unknown
  end
end
```

My colleague has created a similar module that allows receiving a hash that is
missing key-values declared in the anima object so those attributes are
created with nil values.

I'm still undecided on using anima for modeling JSON data in Ruby but it's fun
to play around with.


