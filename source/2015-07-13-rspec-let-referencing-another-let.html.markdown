---
title: RSpec let Referencing Another let
date: 2015-07-13 16:10 EDT
tags: rspec, testing
---

# RSpec `let` Referencing Another `let`

2015-07-13

Today I came across something about RSpec I didn't know while reading through
Noel Rappin's [*Rails 4 Test
Prescriptions*](https://pragprog.com/book/nrtest2/rails-4-test-prescriptions).
You can define a `let` statement at the top of your spec file that references
another `let` that has yet to be defined. Specs further down the file can then
define that `let` statement to provide state for that particular example.

```ruby
RSpec.describe Agent do
  describe "drive" do
    let(:agent) do
      # NOTE: current_vehicle hasn't been defined
      Agent.new(name: "Bond, James", vehicle: current_vehicle )
    end

    it "serves her majesty" do
      # Defining current vehicle here for this specific example
      let(:current_vehicle) { "Aston Martin Vanquish"}
      expect(agent.drive).to eq "James Bond is driving a British auto"
    end

    it "goes rogue" do
      # Defining a different vehicle for this example
      let(:current_vehicle) { "BMW Z8"}
      expect(agent.drive).to eq "James Bond is not driving a British auto"
    end
  end
end
```

Using this pattern allows you to create a `let` statement for creating the
object to be tested in each subsequent example and to provide the unique
state needed for specific examples. It also highlights what is changing between
each spec. For a larger, less contrived example, see *Rails 4 Test
Prescriptions* 131-132.
