---
title: Inskool - First Feature
date: 2016-12-05 07:45 EST
tags:
---

The first feature I want to build for Inskool is the ability to mark student attendance. This feature has different facets. The primary facet is that each day the teacher can view a list of students that may or may not be present for the day and mark which students are in attendance.

In order to mark attendance, though, a teacher must first be able to create students. This seems like a reasonable place to start.

First, checkout a new branch in git for the feature.

```bash
git checkout -b mark_student_attendance
```

If I'm following GOOS, the first place to start is with a high-level acceptance test.


Need to be able to create students
Once the students have been created, need to be able to mark them in attendance on a particular day

As a teacher
When I visit the students page
And ask to add a student
And provide the student's name "Frodo"


```ruby
require 'rails_helper'

RSpec.feature "User adds a student", type: :feature do
  scenario "and sees the student among all students" do
    first_name  = "Frodo"
    last_name   = "Baggins"
    grade_level = 6

    visit new_student_path
    fill_in "student_first_name", with: first_name
    fill_in "student_last_name", with: last_name
    fill_in "student_grade_level", with: grade_level
    click_on "Add student"

    expect(page).to have_current_path students_path
    expect(page).to have_content first_name
  end
end
```


Time to create the form. Rails provides all kinds of neat stuff for creating forms. I find `simpleform` a cleaner solution to the default options provided by Rails. I need to install `simpleform` and create my new student form.


With the form created, my test is complaining that the model in the form is nil. I haven't instantiated the model in the controller.

Now I'm instantiating the model in the controller but the model doesn't exist yet. Time to create the basic Student model.

```bash
bin/rails generate model Student first_name:string last_name:string
```

Now that I have a model, I need to switch gears in TDD, move from the high level acceptance test, to a focused unit test for the model.

The model has a few responsibilities:

*   Raw validations, those validations that are true in ALL circumstances
*   Custom finder methods
*   Rails Callback methods

Right now, a student must have a first name and a last name in all circumstances. There may be other circumstances in which the student may required other attributes. But for now, in all circumstances, they must have a first name and last name. I can confirm this using validations on the model.

```ruby
RSpec.describe Student, type: :model do
  context "validations" do
    subject { build :student }

    it { is_expected.to validate_presence_of :first_name }
    it { is_expected.to validate_presence_of :last_name }
  end
end
```

When I run the spec, I'm told that I don't have a factory for the student. I'll build that now.

## Adding a Grade Level

I struggle in understanding how to model the data correctly. When does an attribute get added directly to a model? When does a new model get introduced and an association is created between the two of them?

Does a student have a grade level *attribute*? Or should there be a new model for grade level and a student has one by association?

Does a grade level have sufficient attributes to be its own model? What if I want to allow users to define custom grade levels?

Standard Grade Levels:

K-12

Custom Grade Levels:

Grammar
Logic Rhetoric


education_level
-----------
stage (e.g. 0, 1, 2, etc.)
name (e.g. Preschool, First, Sophomore)
target_age_start # Is target_age a separate model?
target_age_end

I've decided the "correct" approach is to create a new model for the grade level and an association between the student and the grade level.


0 preschool
1 first
2 second
3 third
4 fourth
...
9 freshman
10 sophmore
11 junior
12 senior

1 grammar
2 logic
3 rhetoric


Student, has_one :student_education_level
Student, has_one :education_level, through: :student_education_level

EducationLevel, has_one :student_education_level

StudentEducationLevel
belongs_to :student
belongs_to :education_level

students
+-------+
id
first_name
last_name

education_levels
+--------------+
id
stage
name

students_education_levels
+-----------------------+
id
student_id
education_level_id

Landed on a Many-to-Many association.
The joining models is students_education_levels
Really want a more descriptive name for this
