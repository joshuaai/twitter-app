# Signup, Login, Microposts and Follow Help

## Start Signup
`rails generate controller Users new`
This creates a Users controller with a new action

Change the `get 'users/new'` route to use the `get '/signup', to: 'users#new'` route instead.

On the home.html.erb file, change the link_to path for 'Sign up now!' button to `signup_path`

Add `<% provide(:title, 'Sign up') %>` to the users/new.html.erb file

## Modeling Users
In contrast to the plural convention for controller names, model names are singular: 
a Users controller, but a User model.
`rails generate model User name:string email:string`

```bash
rails db:migrate
heroku run rails db:migrate
rails c --sandbox
user = User.new(name: "Michael Hartl", email: "mhartl@example.com") 
User.create(name: "Josh A I", email: "j@me.com")
user.save && user.find(1); user.destroy; user.find_by_email("j@me.com"); 
user.update_attribute(name: "Josh", email: "josh@me.com");
user.update_attributes(created_at: 1.year.ago)
```

### Email Validations
Create a test that validates a user. In the models/user_test.rb file Add
```ruby
def setup
    @user = User.new(name: "Example User", email: "user@example.com")
end

test "should be valid" do
    assert @user.valid?
end
```

Create a test that validates the presence of certain elements in `user_test.rb` file.

To the user.rb file, add 
```ruby
validates :name, presence: true
VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }
```

|  Expression                              |  Meaning                                             |
|------------------------------------------|------------------------------------------------------|
|  /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i    |  full regex                                          |
|  /                                       |  start of regex                                      |
|  \A                                      |  match start of a string                             |
|  [\w+\-.]+                               |  at least one word character,                        | 
|                                             plus, hyphen, or dot.                               |
|  @                                       |  literal 'at sign'                                   |
|  [a-z\d\-.]+                             |  at least one letter, digit, hyphen, or dot.         |
|  \.                                      |  literal dot                                         |
|  [a-z]+                                  |  at least one letter                                 |
|  \z                                      |  match end of a string                               |
|  /                                       |  end of regex                                        |
|  i                                       |  case-insensitive                                    |

Add database indicies for email uniqueness validation at the database level.
This is because the Active Record uniqueness validation does not guarantee uniqueness at the database level.
```bash
rails generate migration add_index_to_users_email
```
```ruby
#In the migration file, add to the change method
add_index :users, :email, unique: true
```
```bash
rails db:migrate
rails db:reset #if rails test fails.
```

### Secure Password
The method is to require each user to have a password (with a password confirmation), and then store a hashed 
version of the password in the database.

`rails generate migration add_password_digest_to_users password_digest:string`

Add the `gem 'bcrypt'` and run `bundle install` to hash the passwords in the database.

Add `has_secure_password` to user.rb

Add `password: "foobar", password_confirmation: "foobar"` to setup method in user_test.rb

Enforcing minimum password standards: 
To the user.rb model add
```ruby
validates :password, presence: true, length: { minimum: 6 }
```

## Sign Up
In the application.html.erb under the footer partial, add `<%= debug(params) if Rails.env.development? %>`
To the custom.scss, add
```css
/* miscellaneous */

@mixin box_sizing {
  -moz-box-sizing:    border-box;
  -webkit-box-sizing: border-box;
  box-sizing:         border-box;
}

.debug_dump {
  clear: both;
  float: left;
  width: 100%;
  margin-top: 45px;
  @include box_sizing;
}
```
Add `resources :users` to routes.rb and create the `show.html.erb` file to display the user profile.

### Gravatar
Gravatars are a convenient way to include user profile images without going through the trouble of 
managing image upload, cropping, and storage

Inside show.html.erb
```html
<% provide(:title, @user.name) %>
<h1>
  <%= gravatar_for @user %>
  <%= @user.name %>
</h1>
```

Define the `gravatar_for` helper in the users_helper.rb
```ruby
def gravatar_for(user)
    gravatar_id = Digest::MD5::hexdigest(user.email.downcase)
    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}"
    image_tag(gravatar_url, alt: user.name, class: "gravatar")
end
```

### Creating the user
In the user_controller.rb file, add 
```ruby
def create
    @user = User.new(user_params)
    if @user.save
      flash[:success] = "Welcome to the Twitter App!"
      redirect_to @user
    else
      render 'new'
    end
end

private
  def user_params
    params.require(:user).permit(:name, :email, :password,
                                 :password_confirmation)
  end
```

Inside the container div in `application.html.erb`, add
```html
<% flash.each do |message_type, message| %>
    <div class="alert alert-<%= message_type %>"><%= message %></div>
<% end %>
```

### Handling Errors
We use the common Rails convention of using a dedicated `shared/` directory for partials expected to 
be used in views across multiple controllers.

In new.html.erb, we add `<%= render 'shared/error_messages' %>` 

In `_error_messages.html.erb` add:
```html
<% if @user.errors.any? %>
  <div id="error_explanation">
    <div class="alert alert-danger">
      The form contains <%= pluralize(@user.errors.count, "error") %>.
    </div>
    <ul>
    <% @user.errors.full_messages.each do |msg| %>
      <li><%= msg %></li>
    <% end %>
    </ul>
  </div>
<% end %>
```

To the custom.scss add:
```css
.field_with_errors {
  @extend .has-error;
  .form-control {
    color: $state-danger-text;
  }
}
```

### Testing the signup
Create an integrated test using
`rails generate integration_test users_signup`

The main purpose of the test is to verify that clicking the signup button results in not creating 
a new user when the submitted information is invalid.

To the `users_signup_test.rb` file created, add
```ruby
test "invalid signup information" do
    get signup_path
    assert_no_difference 'User.count' do
      post users_path, params: { user: { name:  "",
                                         email: "user@invalid",
                                         password:              "foo",
                                         password_confirmation: "bar" } }
    end
    assert_template 'users/new'
end
```

### Enforce SSL
In the production.rb file, add
`config.force_ssl = true`

To use SSL on a custom URL, check [Heroku SSL Documentation](https://devcenter.heroku.com/articles/ssl).

Use the Puma web server in production by replacing the contents of puma.rb with 
```ruby
workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/
  # deploying-rails-applications-with-the-puma-web-server#on-worker-boot
  ActiveRecord::Base.establish_connection
end
```

In the appliaton root directory create a Procfile and add to it
`web: bundle exec puma -C config/puma.rb` 

The next session is completing [Login Using Sessions](help_login.md)

