# Updating Users

In the `users_controller.rb` file, add the edit action
```ruby
def edit
    @user = User.find(params[:id])
end
```

Add the `_form.html.erb` partial file to the views/users folder
```html
<%= form_for(@user) do |f| %>
  <%= render 'shared/error_messages', object: @user %>

  <%= f.label :name %>
  <%= f.text_field :name, class: 'form-control' %>

  <%= f.label :email %>
  <%= f.email_field :email, class: 'form-control' %>

  <%= f.label :password %>
  <%= f.password_field :password, class: 'form-control' %>

  <%= f.label :password_confirmation %>
  <%= f.password_field :password_confirmation, class: 'form-control' %>

  <%= f.submit yield(:button_text), class: "btn btn-primary" %>
<% end %>
```

In the `users/edit.html.erb` file add:
```html
<% provide(:title, 'Edit user') %>
<% provide(:button_text, 'Save changes') %>
<h1>Update your profile</h1>
<div class="row">
  <div class="col-md-6 col-md-offset-3">
    <%= render 'form' %>
    <div class="gravatar_edit">
      <%= gravatar_for @user %>
      <a href="http://gravatar.com/emails" target="_blank" rel="noopener">Change</a>
    </div>
  </div>
</div>
```

Change the `users/new.html.erb` file to:
```html
<% provide(:title, 'Sign up') %>
<% provide(:button_text, 'Create my account') %>
<h1>Sign up</h1>
<div class="row">
  <div class="col-md-6 col-md-offset-3">
    <%= render 'form' %>
  </div>
</div>
```

To the `_header.html.erb` partial file, add `edit_user_path(current_user)` as the path for `link_to "Settings"`. 

Create the update action:
```ruby
def update
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
      flash[:success] = "Profile updated"
      redirect_to @user
    else
      render 'edit'
    end
end
```

Top test for unsuccessful edits, generate the an integration test: `rails generate integration_test users_edit`.

Write a simple test for unsuccessful and successful edits in `users_edit_test.rb`:
```ruby
def setup
    @user = users(:michael)
end

test "unsuccessful edit" do
    get edit_user_path(@user)
    assert_template 'users/edit'
    patch user_path(@user), params: { user: { name:  "",
                                                email: "foo@invalid",
                                                password:              "foo",
                                                password_confirmation: "bar" } }

    assert_template 'users/edit'
end

test "successful edit" do
    get edit_user_path(@user)
    assert_template 'users/edit'
    name  = "Foo Bar"
    email = "foo@bar.com"
    patch user_path(@user), params: { user: { name:  name,
                                              email: email,
                                              password:              "",
                                              password_confirmation: "" } }
    assert_not flash.empty?
    assert_redirected_to @user
    @user.reload
    assert_equal name,  @user.name
    assert_equal email, @user.email
  end
```

To get the tests to pass, we need to make an exception to the password validation in `User.rb` file if the password is empty.
`validates :password, presence: true, length: { minimum: 6 }, allow_nil: true`

# Authorization
Before filters use the `before_action` command to arrange for a particular method to be called before the given actions. To require users to be logged in, we define a `logged_in_user` method and invoke it using `before_action :logged_in_user`
```ruby
class UsersController < ApplicationController
    before_action :logged_in_user, only: [:edit, :update]
    .
    .
    .
    private

    def user_params
        params.require(:user).permit(:name, :email, :password,
                                   :password_confirmation)
    end

    # Before filters

    # Confirms a logged-in user.
    def logged_in_user
        unless logged_in?
            flash[:danger] = "Please log in."
            redirect_to login_url
        end
    end
end
```

Because the before filter operates on a per-action basis, we’ll put the corresponding tests in the Users controller test. In the `users_controller_test.rb` file, test that edit and update actions enforce the before_action behaviour.

Also add the test that ensures the user is redirected for a login attempt with the wrong user.

```ruby
def setup
    @user = users(:michael)
    @other_user = users(:joshua)
end
.
.
.
test "should redirect edit when not logged in" do
    get edit_user_path(@user)
    assert_not flash.empty?
    assert_redirected_to login_url
end

test "should redirect update when not logged in"
    patch user_path(@user), params: { user: { name: @user.name, 
                                              email: @user.email } }
    assert_not flash.empty?
    assert_redirected_to login_url
end

test "should redirect edit when logged in as wrong user" do
    log_in_as(@other_user)
    get edit_user_path(@user)
    assert flash.empty?
    assert_redirected_to root_url
  end

test "should redirect update when logged in as wrong user" do
    log_in_as(@other_user)
    patch user_path(@user), params: { user: { name: @user.name,
                                              email: @user.email } }
    assert flash.empty?
    assert_redirected_to root_url
end
```

To complete the second part of the above, we add a `correct_user` before action.
```ruby
before_action :correct_user, only: [:edit, :update]
.
.
.
# Confirms the correct user.
def correct_user
    @user = User.find(params[:id])
    redirect_to(root_url) unless current_user?(@user)
end
```

For refactoring, add a `current_user?` boolean helper to the `sessions_helper.rb` that returns true if the given user is the current user. Add this just before the `current_user` method.
```
# Returns true if the given user is the current user.
def current_user?(user)
    user == current_user
end
```

To test for friendly forwarding i.e. to ensure that failed edit attempts due to not being logged in redirect the user to the appropriate page. Refactor the successful edit test in `users_edit_test.rb` by replacing the lines before `name  = "Foo Bar"` with
```ruby
test "successful edit with friendly forwarding" do
    get edit_user_path(@user)
    log_in_as(@user)
    assert_redirected_to edit_user_url(@user)
    .
    .
    .
end
```

To implement friendly forwarding, we add two methods to the `sessions_helper.rb` file:
```ruby
.
.
.
# Redirects to stored location (or to the default).
def redirect_back_or(default)
    redirect_to(session[:forwarding_url] || default)
    session.delete(:forwarding_url)
end

# Stores the URL trying to be accessed.
def store_location
    session[:forwarding_url] = request.original_url if request.get?
end
```

In the `logged_in_user` method of the `users_controller.rb` file, add `store_location` after `unless logged_in?`.

To the `session_controller.rb` create action replace the `redirect_to user` with `redirect_back_or user`.

# Showing All Users
Restrict the access to view all users

In the `users_controller_test.rb`, add the test for this as the first test
```ruby
test "should redirect index when not logged in" do
    get users_path
    assert_redirected_to login_url
end
```

In the `users_controller.rb` file, add the index action:
```ruby
before_action :logged_in_user, only: [:index, :edit, :update]

def index
    @users = User.all
end
```

Now create the `users/index.html.erb` view for the index action:
```html
<% provide(:title, 'All users') %>
<h1>All users</h1>

<ul class="users">
  <% @users.each do |user| %>
    <li>
      <%= gravatar_for user, size: 50 %>
      <%= link_to user.name, user %>
    </li>
  <% end %>
</ul>
```

In the `users_helper.rb` file, update the `gravatar_for` helper with a size attribute that allows our code above specify the size like we did.
```ruby
def gravatar_for(user, options = { size: 80 })
    gravatar_id = Digest::MD5::hexdigest(user.email.downcase)
    size = options[:size]
    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}"
    image_tag(gravatar_url, alt: user.name, class: "gravatar")
end
```

Style the `custom.scss` as follows
```css
.
.
.
/* Users index */

.users {
  list-style: none;
  margin: 0;
  li {
    overflow: auto;
    padding: 10px 0;
    border-bottom: 1px solid $gray-lighter;
  }
}
```

Add the URL to the users link in the site’s navigation header using users_path, in `_header.html.erb` just before the `dropdown` class.
```html
<li><%= link_to "Users", users_path %></li>
```

## Random Users
Add a faker gem to generate random users. Typically we will use the Faker in development mode only, but in this case, we install globally.
```ruby
gem 'faker'

bundle install
```

In the db/seeds.rb file, add 
```ruby
User.create!(name:  "Example User",
             email: "example@railstutorial.org",
             password:              "foobar",
             password_confirmation: "foobar")

99.times do |n|
  name  = Faker::Name.name
  email = "example-#{n+1}@railstutorial.org"
  password = "password"
  User.create!(name:  name,
               email: email,
               password:              password,
               password_confirmation: password)
end
```

Run `rails db:migrate:reset` and `rails db:seed`


# Pagination
Add the gems for this:
```ruby
gem 'will_paginate'
gem 'bootstrap-will_paginate'
```

Add `<%= will_paginate %>` to the outside top and bottom of the `users/index.html.erb` file.

In the `users_controller.rb` file, replace `@user = User.all` with `@users = User.paginate(page: params[:page])`.

## Users Index Test
Create extra dummy users in the `fixtures/users.yml` file
```yml
archer:
  name: Sterling Archer
  email: duchess@example.gov
  password_digest: <%= User.digest('password') %>

lana:
  name: Lana Kane
  email: hands@example.gov
  password_digest: <%= User.digest('password') %>

malory:
  name: Malory Archer
  email: boss@example.gov
  password_digest: <%= User.digest('password') %>

<% 30.times do |n| %>
user_<%= n %>:
  name:  <%= "User #{n}" %>
  email: <%= "user-#{n}@example.com" %>
  password_digest: <%= User.digest('password') %>
<% end %>
```

Generate the integration tests for this by running ` rails generate integration_test users_index`.

In the generated `users_index_test.rb` file, add the tests:
```ruby
def setup
     @user = users(:michael)
end

test "index including pagination" do
    log_in_as(@user)
    get users_path
    assert_template 'users/index'
    assert_select 'div.pagination'
    User.paginate(page: 1).each do |user|
      assert_select 'a[href=?]', user_path(user), text: user.name
    end
end
```

# Refactoring with Partials
Create a `users/_user.html.erb` partial to hold the user `li`.
```html
<li>
  <%= gravatar_for user, size: 50 %>
  <%= link_to user.name, user %>
</li>
```

Replace the `li` and `for_each` in `users/index.html.erb` with `<%= render @user %>`, making a direct call on the @users variable.

# Administrative Users
We will identify privileged administrative users with a boolean admin attribute in the User model, which will lead automatically to an admin? boolean method to test for admin status.

```bash
rails generate migration add_admin_to_users admin:boolean
```

Add `, default: false` to the generated migration file so that in the rails console, `user.admin?` called on `user = User.first` will be false and run `rails db:migrate`.

In the `seeds.rb` file, add `admin: true` after password to the Example user.

Run `rails db:migrate:reset` and `rails db:seed`.

## The Destroy Action
The final step needed to complete the Users resource is to add delete links and a destroy action. The resulting "delete" links will be displayed only if the current user is an admin.

Inside the `li` tag of the `_user.html.erb` partial, add:
```html
<% if current_user.admin? && !current_user?(user) %>
    | <%= link_to "delete", user, method: :delete,
                                  data: { confirm: "You sure?" } %>
<% end %>
```

Add the destroy action to the `users_controller.rb` file:
```ruby
before_action :logged_in_user, only: [:index, :edit, :update, :destroy]
.
.
.
def destroy
    User.find(params[:id]).destroy
    flash[:success] = "User deleted"
    redirect_to users_url
end
```

In the same users controller, add a before action restriction: `before_action :admin_user, only: :destroy`. 

Add also the `admin_user` method as part of the before action methods under private field:
```ruby
# Confirms an admin user.
def admin_user
    redirect_to(root_url) unless current_user.admin?
end
```

To test this, add `admin: true` to one user in the `fixtures/users.yml` file.

Add the test to `users_controller_test.rb`:
```ruby
test "should redirect destroy when not logged in" do
    assert_no_difference 'User.count' do
      delete user_path(@user)
    end
    assert_redirected_to login_url
end

test "should redirect destroy when logged in as a non-admin" do
    log_in_as(@other_user)
    assert_no_difference 'User.count' do
        delete user_path(@user)
    end
    assert_redirected_to root_url
end
```

In the `users_index_test.rb` repplace the contents with:
```ruby
def setup
    # admin user
    @admin = users(:joshua)
    # non-admin user
    @non_admin = users(:michael)
end

test "index as admin including pagination and delete links" do
    log_in_as(@admin)
    get users_path
    assert_template 'users/index'
    assert_select 'div.pagination'
    first_page_of_users = User.paginate(page: 1)
    first_page_of_users.each do |user|
        assert_select 'a[href=?]', user_path(user), text: user.name
        unless user == @admin
        assert_select 'a[href=?]', user_path(user), text: 'delete'
        end
    end
    assert_difference 'User.count', -1 do
        delete user_path(@non_admin)
    end
end

test "index as non-admin" do
    log_in_as(@non_admin)
    get users_path
    assert_select 'a', text: 'delete', count: 0
end
```

Push to Heroku
```bash
rails test
git push heroku
heroku pg:reset DATABASE
heroku run rails db:migrate
heroku run rails db:seed
heroku restart
```

The next session is setting up [Tweets and Followers](help_tweets_followers.md)











