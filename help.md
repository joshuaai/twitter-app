# Help commands for this app

## Setup project
`rails new twitter-app`

Add the test gems
```
group :test do
  gem 'rails-controller-testing'
  gem 'minitest-reporters'
  gem 'guard'
  gem 'guard-minitest'
end
```

Add to the development group
```
gem 'listen'
gem 'spring'
gem 'spring-watcher-listen'
```

Update the Gemfile and push to heroku
```bash
bundle install --without production
bundle update
git commit -am "add hello"
git push
heroku create
git push heroku master
heroku apps:rename twitter-joshuaai
```

## Static Pages
A single  controller to handle static pages - Home, Help and About
`rails generate controller StaticPages home help`

To destroy to reverse a controller generation
`rails destroy  controller StaticPages home help`

### Setting up Testing
TDD protects against *code regression* (feature suddenly stops working) and allows *code refactoring* without breaking.
The test also acts as a client for the application code, helping determine its design and interface with other parts.

To get the default Rails tests to show red and green at the appropriate times 
```ruby
require "minitest/reporters"
Minitest::Reporters.use!
```

To color on windows `gem install win32console`

Controller tests `rails test`

A failing test added to `static_pages_controller_test.rb`
```ruby
test "should get about" do
    get static_pages_about_url
    assert_response :success
end
```

Add a route for the about page which automatically creates its helper (static_pages_about_url) too `get 'static_pages/about'`

Add the action to the `static_pages_controller.rb`
```ruby
def about
end
```

Create the `about.html.erb` file

### Slightly Dynamic Pages
Change the tab titles for each page. Test for the presence of html <title> tag
```ruby
test "should get home" do
    get static_pages_home_url
    assert_response :success
    assert_select "title", "Home | Rails Twitter App"
end
```

### Refactoring (DRYing out) the code
First clean up the erb files, making the layout view the template for all views. 

At the top of the page add `<% provide(:title, "Home") %>`

In app/views/layout/application.html.erb `<%= yield(:title) %>`

#### Custom Helpers
* The full_title helper allows us remove the 'provide' in each view
```ruby
def full_title(page_title = '')
    base_title = "Rails Twitter App"
    if page_title.empty?
        base_title
    else
        page_title + " | " + base_title
    end
end 
```
* Replace 
```ruby
<title><%= yield(:title) %> | Rails Twitter App</title>

with

<title><%= full_title(yield(:title)) %></title>
``` 
* Remove the title names in the tests.

#### Rails-flovoured Ruby
Arrays
```ruby
def yeller(s)
s = s.map(&:upcase).join
end
s = ['o', 'l', 'd']
```

```ruby
def random_domain
('a'..'z').to_a.shuffle[0..7].join
end
```

Hashes
```ruby
flash = { success: "It worked!", danger: "It failed." }
#the each method for a hash iterates through the hash one key-value pair at a time
flash.each do |key, value|
    puts "Key #{key.inspect} has value #{value.inspect}"
end
```

OOP
```ruby
class User
  attr_accessor :name, :email

  def initialize(attributes = {})
    #The empty hash allows us define a user with empty attributes
    @name  = attributes[:name]
    @email = attributes[:email]
  end

  def formatted_email
    "#{@name} <#{@email}>"
  end
end
```

### Layout Design
In the home file, the `image-tag` helper allows us add images.

Add the `gem bootstrap-saas` for bootstrap styling and run `bundle install`.

In the custom scss file, add 
```css
@import "bootstrap-sprockets"; 
@import "bootstrap";
```

Add partials for shim, header and footer. And render them as follows in application.html.erb:
```ruby
<%= render 'layouts/shim' %>
<%= render 'layouts/header' %>
<%= render 'layouts/footer' %>
```

To combine the css and js assets, in application.css add 
```js
/*
 .
 .
 .
 *= require_tree .
 *= require_self
*/
```

## Integration Tests
An integration test allows us to write an end-to-end test of our application's behavior.
We will use this to test the layout links to ensure they are working correctly.

`rails generate integration_test site_layout`

In the `site_layout_test.rb` file generated add
```ruby
test "layout_links" do
    get root_path
    assert_template 'static_pages/home'
    assert_select "a[href=?]", root_path, count: 2
    assert_select "a[href=?]", help_path
    assert_select "a[href=?]", about_path
    assert_select "a[href=?]", contact_path
end
```

`rails test:integration`

The next sessions cover a custom [Sign Up](help_signup.md), [Login Using Sessions](help_login.md), [Updating and Administering Users](help_complete_auth.md) and [Tweets](help_tweets.md) and [Followers](help_followers.md).