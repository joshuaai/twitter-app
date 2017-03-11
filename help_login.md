## Sessions
The only way to remember users' identity from page to page is by a session, which is a semi-permanent 
connection between two computers.

The sessions is a cookie-based authentication machinery. We will construct a sessions controller, a login form
and then the relevant controller actions.

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

In application_controller.rb incluse the sessions helper thus `include SessionsHelper`

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
We need to add a call to log_in in the users_controller.rb create action.
`log_in @user`

To test this we define an is_logged_in? method in the ActiveSupport::TestCase of test_helper.rb
```
# Returns true if a test user is logged in.
def is_logged_in?
    !session[:user_id].nil?
end
```

Inside the users_signup_test, we assert the above method add the test
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
    log_out
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
    follow_redirect!
    assert_select "a[href=?]", login_path
    assert_select "a[href=?]", logout_path,      count: 0
    assert_select "a[href=?]", user_path(@user), count: 0
end
```
We test the the login/logut machinery appear and disappear when the given actions are performed.