## Sessions
The only way to remember users' identity from page to page is by a session, which is a semi-permanent 
connection between two computers (such as a client computer running a web browser and a server running Rails).

The most common techniques for implementing sessions in Rails involve using cookies, which are small pieces of text placed on the user’s browser. Because cookies persist from one page to the next, they can store information (such as a user id) that can be used by the application to retrieve the logged-in user from the database.

Unlike the `Users` resource, which uses a database back-end (via the User model) to persist data, the `Sessions` resource is a cookie-based authentication machinery. We will construct a sessions controller, a login form and then the relevant controller actions.

### Sessions Controller
```
git checkout -b basic-login

rails generate controller Sessions new

get    '/login',  to: 'sessions#new'
post   '/login',  to: 'sessions#create'
delete '/logout', to: 'sessions#destroy'
```

In sessions_controller_test.rb replace the sessions login path with the new one
```
test "should get new" do
    get login_path
    assert_response :success
end
```

### Login Form
As session isn’t an Active Record object, we’ll render the error as a flash message instead.

In sessions/new.html.erb
```
<% provide(:title, "Log in") %>
<h1>Log in</h1>

<div class="row">
  <div class="col-md-6 col-md-offset-3">
    <%= form_for(:session, url: login_path) do |f| %>

      <%= f.label :email %>
      <%= f.email_field :email, class: 'form-control' %>

      <%= f.label :password %>
      <%= f.password_field :password, class: 'form-control' %>

      <%= f.submit "Log in", class: "btn btn-primary" %>
    <% end %>

    <p>New user? <%= link_to "Sign up now!", signup_path %></p>
  </div>
</div>
```

Update the sessions_controller.rb file with the create and destroy methods.
```
def create
    user = User.find_by(email: params[:session][:email].downcase)
    if user && user.authenticate(params[:session][:password])
      # Log the user in and redirect to the user's show page.
      log_in user
      redirect_to user
    else
      # Create an error message.
      flash.now[:danger] = 'Invalid email/password combination'
      render 'new'
    end
end

def destroy
end
```

Write a short integration test to check for login errors especially with the flash message
`rails generate integration_test users_login`

* Visit the login path.
* Verify that the new sessions form renders properly.
* Post to the sessions path with an invalid params hash.
* Verify that the new sessions form gets re-rendered and that a flash message appears.
* Visit another page (such as the Home page).
* Verify that the flash message doesn’t appear on the new page.

Write the test in users_login_test.rb
```
test "login with invalid information" do
    get login_path
    assert_template 'sessions/new'
    post login_path, params: { session: { email: "", password: "" } }
    assert_template 'sessions/new'
    assert_not flash.empty?
    get root_path
    assert flash.empty?
end
```

`rails test test/integration/users_login_test.rb`

In application_controller.rb include the sessions helper thus: `include SessionsHelper`

In sessions_helper.rb add:
```
#Logs in the given user
def log_in(user)
    sessions[:user_id] = user.id
end

# Returns the current logged-in user (if any).
def current_user
    @current_user ||= User.find_by(id: session[:user_id])
end

# Returns true if the user is logged in, false otherwise.
def logged_in?
    !current_user.nil?
end
```

## Changing the Layout Links
We create the the logged_in? boolean as a helper as seen above.

In _header.html.erb add after the help link:
```
<% if logged_in? %>
    <li><%= link_to "Users", '#' %></li>
    <li class="dropdown">
        <a href="#" class="dropdown-toggle" data-toggle="dropdown">
            Account <b class="caret"></b>
        </a>
        <ul class="dropdown-menu">
            <li><%= link_to "Profile", current_user %></li>
            <li><%= link_to "Settings", '#' %></li>
            <li class="divider"></li>
            <li><%= link_to "Log out", logout_path, method: "delete" %></li>
        </ul>
    </li>
<% else %>
    <li><%= link_to "Log in", login_path %></li>
<% end %>
```

Include Bootstrap's custom JavaScript library in application.js

### Testing Layout Changes
* Visit the login path.
* Post valid information to the sessions path.
* Verify that the login link disappears.
* Verify that a logout link appears.
* Verify that a profile link appears.

Our test needs to log in as a previously registered user, 
which means that such a user must already exist in the database. 
The default Rails way to do this is to use fixtures, which are a 
way of organizing data to be loaded into the test database.

Add to the models/user.rb file
```
# Returns the hash digest of the given string.
def User.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                    BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
end
```

Add the fixture to the fixtures/users.yml
```
Joshua:
    name: Joshua Example
    email: joshua@example.com
    password_digest: <%= User.digest('password') %>
```

In the users_login_test.rb file add 
```
def setup
    @user = users(:michael)
end
.
.
.
test "login with valid information" do
    get login_path
    post login_path, params: { session: { email:    @user.email,
                                          password: 'password' } }
    assert_redirected_to @user  # to check the right redirect target 
    follow_redirect!            # to actually visit the target page
    assert_template 'users/show'
    assert_select "a[href=?]", login_path, count: 0
    assert_select "a[href=?]", logout_path
    assert_select "a[href=?]", user_path(@user)
end
```

## Login upon Signup
We need to add a call to `log_in` in the users_controller.rb create action: `log_in @user`.

To test this we define an is_logged_in? method in the ActiveSupport::TestCase of test_helper.rb
```
# Returns true if a test user is logged in.
def is_logged_in?
    !session[:user_id].nil?
end
```

Inside the `users_signup_test.rb` file, we assert the above method and add the test
```
test "valid signup information" do
    get signup_path
    assert_difference 'User.count', 1 do
      post users_path, params: { user: { name:  "Example User",
                                         email: "user@example.com",
                                         password:              "password",
                                         password_confirmation: "password" } }
    end
    follow_redirect!
    assert_template 'users/show'
    assert is_logged_in?
end
```

## Logging Out
Inside the sessions_helper.rb file, define:
```
# Logs out the current user.
def log_out
    session.delete(:user_id)
    @current_user = nil
end
```

Then we put the log_out method to use in the sessions_controller.rb destroy action.
```
def destroy
    log_out if logged_in?
    redirect_to root_url
end
```

Test this in the users_login_test.rb file by adding:
```
test "login with valid information followed by logout" do
    get login_path
    post login_path, params: { session: { email:    @user.email,
                                          password: 'password' } }
    assert is_logged_in?
    assert_redirected_to @user
    follow_redirect!
    assert_template 'users/show'
    assert_select "a[href=?]", login_path, count: 0
    assert_select "a[href=?]", logout_path
    assert_select "a[href=?]", user_path(@user)
    delete logout_path
    assert_not is_logged_in?
    assert_redirected_to root_url
    # Simulate a user clicking logout in a second window
    delete logout_path
    follow_redirect!
    assert_select "a[href=?]", login_path
    assert_select "a[href=?]", logout_path,      count: 0
    assert_select "a[href=?]", user_path(@user), count: 0
end
```
We test the the login/logut machinery appear and disappear when the given actions are performed.

## Persistent Sessions | Remebering Passwords | Advanced Login
* Create a random string of digits for use as a remember token.
* Place the token in the browser cookies with an expiration date far in the future.
* Save the hash digest of the token to the database.
* Place an encrypted version of the user’s id in the browser cookies.
* When presented with a cookie containing a persistent user id, find the user in the database using the given id, and verify that the remember token cookie matches the associated hash digest from the database.

We’ll start by adding the required remember_digest attribute to the User model:
```
rails generate migration add_remember_digest_to_users remember_digest:string
rails db:migrate
```

To the User.rb model, use the Ruby SecureRandom class to generate the remember token.
```
attr_accessor :remember_token
.
.
.
# Returns a random token.
def User.new_token
    SecureRandom.urlsafe_base64
end

def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remeber_token))
end
```

### Login with Remebering
Rails has a special `.permanent` method which creates permanent cookies with an expiration time of `20.years.from_now`.

For remebering the user_id, we'll use a signed cookie, which securely encrypts the cookie before placing it on the browser.

To the User.rb, add 
```
# Returns true if the given token matches the digest.
def authenticated?(remember_token)
    BCrypt::Password.new(remember_digest).is_password?(remember_token)
end
``` 

To the sessions_controller, add to the conditional user.authenticate method (between `log_in user` and `redirect_user`):
```
remember user
```

In the sessions_helper.rb file, after the `def log_in(user)` method, add:
```
# Remembers a user in a persistent session.
def remember(user)
    user.remember
    cookies.permanent.signed[:user_id] = user.id
    cookies.permanent[:remember_token] = user.remember_token
end

def current_user
    if (user_id = session[:user_id])
        @current_user ||= User.find_by(id: user_id)
    elsif (user_id = cookies.signed[:user_id])
        user = User.find_by(id: user_id)
        if user && user.authenticated?(cookies[:remember_token])
            log_in user
            @current_user = user
        end
    end
end

.
.
.

# Forgets a persistent session.
def forget(user)
    user.forget
    cookies.delete(:user_id)
    cookies.delete(:remember_token)
end

# Logs out the current user.
def log_out
    forget(current_user)
    session.delete(:user_id)
    @current_user = nil
end
```

Becuase a remember digest in deleted upon logout from one browser, if the user is still logged in on another browser, an error
will be thrown on a logout or re-logging in  attempt.

In the sessions_controller.rb file, add to the `def destroy` method `logout if logged_in?`

In the user_test.rb file, add:
```
test "authenticated? should return false for a user with nil digest" do
    assert_not @user.authenticated?('')
end
```

In the user.rb file, add `return false if remember_digest.nil?` to the `def authenticated?`

## "Remeber me" Checkbox
As with labels, text fields, password fields, and submit buttons, checkboxes can be created with a Rails helper method.

In sessions/new.html.erb, add after password field:
```
<%= f.label :remember_me, class: "checkbox inline" do %>
    <%= f.check_box :remember_me %>
    <span>Remember me on this computer</span>
<% end %>
```

In the custom.scss file, add to the /* Forms */ area:
```
.checkbox {
  margin-top: -10px;
  margin-bottom: 10px;
  span {
    margin-left: 20px;
    font-weight: normal;
  }
}

#session_remember_me {
  width: auto;
  margin-left: 0;
}
```

In sessions_controller.rb, after the `login_user` in the `def create` method, replace `remeber user` with `params[:session][:remember_me] == '1' ? remember(user) : forget(user)`. It alternates a value of "1" to apply the remember_me helper.

### Remeber tests
We create a helper method in `test_helper.rb` that handles login in the tests so that we don't repeat ourselves. In the ActiveSupport::TestCase add:

```
# Log in as a particular user.
def log_in_as(user)
    session[:user_id] = user.id
end
```

Add the ActionDsipatch::IntegrationTest class:
```
class ActionDispatch::IntegrationTest

  # Log in as a particular user.
  def log_in_as(user, password: 'password', remember_me: '1')
    post login_path, params: { session: { email: user.email,
                                          password: password,
                                          remember_me: remember_me } }
  end
end
```

To verify the behavior of the “remember me” checkbox, we’ll write two tests, one each for submitting with and without the checkbox checked.

In `users_login_test.rb` add:
```
test "login with remembering" do
    log_in_as(@user, remember_me: '1')
    assert_not_empty cookies['remember_token']
end

test "login without remembering" do
    # Log in to set the cookie.
    log_in_as(@user, remember_me: '1')
    # Log in again and verify that the cookie is deleted.
    log_in_as(@user, remember_me: '0')
    assert_empty cookies['remember_token']
end
```

Add a `test/helpers/sessions_helper_test.rb` file with the contents:
```
require 'test_helper'

class SessionsHelperTest < ActionView::TestCase

  def setup
    @user = users(:Joshua)
    remember(@user)
  end

  test "current_user returns right user when session is nil" do
    assert_equal @user, current_user
    assert is_logged_in?
  end

  test "current_user returns nil when remember digest is wrong" do
    @user.update_attribute(:remember_digest, User.digest(User.new_token))
    assert_nil current_user
  end
end
```

After git commit, push to heroku 
```
heroku maintenance:on
git push heroku
heroku run rails db:migrate
heroku maintenance:off
```
