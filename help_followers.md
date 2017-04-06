# Following Users
We will complete the app by adding a social layer that allows users to follow (and unfollow) other users, resulting in each user’s Home page displaying a status feed of the followed users’ tweets. We will do this by modelling relationships between users.

## The Relationship Model
Our first step in implementing following users is to construct a data model, which is not as straight forward as it seems.
```bash
git checkout -b following-users
rails generate model Relationship follower_id:integer followed_id:integer
```

Because we will be finding relationships by `follower_id` and by `followed_id`, we should add an index on each column of the `[timestamp]_create_relationships.rb` file for efficiency. Add this under the `create_table` method:
```ruby
add_index :relationships, :follower_id
add_index :relationships, :followed_id
add_index :relationships, [:follower_id, :followed_id], unique: true
```
This also includes a multiple-key index that enforces uniqueness on `(follower_id, followed_id)` pairs, so that a user can’t follow another user more than once.

To create the relationships table, we migrate the database as usual:
```bash
rails db:migrate
```

Add to the `user.rb` relationships:
```ruby
has_many :active_relationships, class_name: "Relationship",
                               foreign_key: "follower_id",
                                 dependent: :destroy
```
(Since destroying a user should also destroy that user’s relationships, we’ve added dependent: :destroy to the association.)

To the `relationship.rb` model relationships, add:
```ruby
belongs_to :follower, class_name: "User"
belongs_to :followed, class_name: "User"
```

### Relationship Validations
Add the following tests to the `relationship_test.rb` file:
```ruby
def setup
    @relationship = Relationship.new(follower_id: users(:michael).id,
                                     followed_id: users(:archer).id)
end

test "should be valid" do
    assert @relationship.valid?
end

test "should require a follower id" do
    @relationship.follower_id = nil
    assert_not @relationship.valid?
end

test "should require a followed id" do
    @relationship.followed_id = nil
    assert_not @relationship.valid?
end

```

Add to the `relationship.rb` model validation:
```ruby
validates :follower_id, presence: true
validates :followed_id, presence: true
```

Remove the contents of the `relationships.yml` file and run `rails test`.

### Followed/Following Users

Add to the `user.rb` validations:
```ruby
has_many :following, through: :active_relationships, source: :followed
```
Rails allows us to override the default, in this case using the `source` parameter, which explicitly tells Rails that the source of the following array is the set of followed ids.

To manipulate following relationships, we’ll introduce follow and unfollow utility methods so that we can write, e.g., `user.follow(other_user)`. We’ll also add an associated `following?` boolean method to test if one user is following another.

We will write a short test for the User model. In the `user_test.rb` file, add:
```ruby
test "should follow and unfollow a user" do
    michael = users(:michael)
    archer = users(:archer)
    assert_not michael.following?(archer)
    michael.follow(archer)
    assert michael.following?(archer)
    michael.unfollow(archer)
    assert_not michael.following?(archer)
end
```

Add the above methods we tested for in the the `user.rb` model file just below the `feed` method:
```ruby
.
.
.
# Follows a user.
def follow(other_user)
    following << other_user
end

# Unfollows a user.
def unfollow(other_user)
    following.delete(other_user)
end

# Returns true if the current user is following the other user.
def following?(other_user)
    following.include?(other_user)
end
```

### Followers
The final piece of the relationships puzzle is to add a `user.followers` method to go with `user.following`. 
All the information needed to extract an array of followers is already present in the `relationships` table (which we are treating as the `active_relationships` table). The technique is exactly the same as for followed users, with the roles of `follower_id` and `followed_id` reversed and with `passive_relationships` in the place of `active_relationships`.

Add to the `user.rb` file:
```ruby
has_many :passive_relationships, class_name:  "Relationship",
                                 foreign_key: "followed_id",
                                 dependent:   :destroy
.
has_many :followers, through: :passive_relationships, source: :follower
```

To the test `"should follow and unfollow a user"` in `user_test.rb`, add after `assert michael.following?(archer)`:
```ruby
assert archer.followers.include?(michael)
```

## A web interface for following users
We will user `rails db:seed` to fill the database with sample relationships.

To the `seeds.rb` file, add:
```ruby
# Following relationships
users = User.all
user  = users.first
following = users[2..50]
followers = users[3..40]
following.each { |followed| user.follow(followed) }
followers.each { |follower| follower.follow(user) }
```
Here we somewhat arbitrarily arrange for the first user to follow users 3 through 51, and then have users 4 through 41 follow that user back. The resulting relationships will be sufficient for developing the application interface.

```bash
rails db:migrate:reset
rails db:seed
```

### Stats and a follow form
We'll start by making a partial to display the following and follower statistics on the profile and home pages. We’ll next add a follow/unfollow form, and then make dedicated pages for showing “following” (followed users) and “followers”.

In the `routes.rb` file, update the users resource to have members thus:
```ruby
resources :users do
    member do
        get :following, :followers
    end
end
```
The `member` method arranges for the routes to respond to URLs containing the user id such as `/users/1/following `. The other possibility, `collection`, works without the id, and would give `/users/following`.

With the routes defined, we are now in a position to define the stats partial, which involves a couple of links inside a div. Add the `shared/_stats.html.erb` file:
```html
<% @user ||= current_user %>
<div class="stats">
    <a href="<%= following_user_path(@user) %>">
        <strong id="following" class="stat"><%= @user.following.count %></strong>
        following
    </a>
    <a href="<%= followers_user_path(@user) %>">
        <strong id="followers" class="stat"><%= @user.followers.count %></strong>
        followers
    </a>
</div>
```

Add the partial to the `home.html.erb` file just under the `user_info` class:
```html
<section class="stats">
    <%= render 'shared/stats' %>
</section>
```

In the `custom.scss` add to the `/* sidebar */`:
```css
.stats {
  overflow: auto;
  margin-top: 0;
  padding: 0;
  a {
    float: left;
    padding: 0 10px;
    border-left: 1px solid $gray-lighter;
    color: gray;
    &:first-child {
      padding-left: 0;
      border: 0;
    }
    &:hover {
      text-decoration: none;
      color: blue;
    }
  }
  strong {
    display: block;
  }
}

.user_avatars {
  overflow: auto;
  margin-top: 10px;
  .gravatar {
    margin: 1px 1px;
  }
  a {
    padding: 0;
  }
}

.users.follow {
  padding: 0;
}
```

We’ll render the stats partial on the profile page in a moment, but first let’s make a partial for the follow/unfollow button as `users/_follow_form.html.erb`:
```html
<% unless current_user(@user) %>
    <div id="follow_form">
        <% if current_user.following?(@user) %>
            <%= render 'unfollow' %>
        <% else %>
            <%= render 'follow' %>
        <% end %>
    </div>
<% end %>
```
This does nothing but defer the real work to `follow` and `unfollow` partials, which need new routes for the Relationships resource. Add the resource to the `routes.rb` file:
```ruby
resources :relationships,       only: [:create, :destroy]
```

Create the follow partial, `users/_follow.html.erb`:
```html
<%= form_for(current_user.active_relationships.build) do |f| %>
  <div><%= hidden_field_tag :followed_id, @user.id %></div>
  <%= f.submit "Follow", class: "btn btn-primary" %>
<% end %>
```

Create the unfollow partial, `users/_unfollow.html.erb`:
```html
<%= form_for(current_user.active_relationships.find_by(followed_id: @user.id),
             html: { method: :delete }) do |f| %>
  <%= f.submit "Unfollow", class: "btn" %>
<% end %>
```

These two forms above both use `form_for` to manipulate a Relationship model object; the main difference between the two is that `_follow.html` builds a new relationship, whereas `_unfollow.html.erb` finds the existing relationship. Naturally, the former sends a POST request to the Relationships controller to create a relationship, while the latter sends a DELETE request to destroy a relationship. Finally, you’ll note that the follow form doesn’t have any content other than the button, but it still needs to send the `followed_id` to the controller. We accomplish this with the `hidden_field_tag` method.

We can now include the follow form and the following statistics on the user profile page simply by rendering the partials, in the `show.html.erb` file:
```html
.
.
.
<!-- After the gravatar section -->
<section class="stats">
    <%= render 'shared/stats' %>
</section>
.
<!-- Inside the class="col-md-8" -->
<%= render 'follow_form' if logged_in? %>
```

### Following and followers pages
Pages to display followed users and followers will resemble a hybrid of the user profile page and the user index page, with a sidebar of user information (including the following stats) and a list of users. In addition, we’ll include a raster of smaller user profile image links in the sidebar.

Our first step is to get the following and followers links to work. We’ll follow Twitter’s lead and have both pages require user login. Write redirect tests for thses in `users_controllers_test.rb` file:
```ruby
def setup
    @user = users(:michael)
    @other_user = users(:archer)
end
.
.
.
test "should redirect following when not logged in" do
    get following_user_path(@user)
    assert_redirected_to login_url
end

test "should redirect followers when not logged in" do
    get followers_user_path(@user)
    assert_redirected_to login_url
end
```

We need to add two new actions to the Users controller. Based on the routes defined, we need to call them `following` and `followers`. Each action needs to set a title, find the user, retrieve either `@user.following` or `@user.followers` (in paginated form), and then render the page.

Add the methods in the `users_controller.rb` file just before the `private` declaration:
```ruby
before_action :logged_in_user, only: [:index, :edit, :update, :destroy, :following, :followers]

def following
    @title = "Following"
    @user = User.find(params[:id])
    @users = @user.following.paginate(page: params[:page])
    render 'show_follow'
end
  
def followers
    @title = "Followers"
    @user = User.find(params[:id])
    @users = @user.followers.paginate(page: params[:page])
    render 'show_follow'
end
```

Create the `users/show_follow.html.erb` file:
```html
<% provide(:title, @title) %>
<div class="row">
    <aside class="col-md-4">
        <section class="user-info">
            <%= gravatar_for @user %>
            <h1><%= @user.name %></h1>
            <span><%= link_to "view my profile", @user %></span>
            <span><b>Tweets: </b><%= @user.tweets.count %></span>
        </section>
        <section class="stats">
            <%= render 'shared/stats' %>
            <% if @users.any? %>
                <div class="user_avatars">
                    <% @users.each do |user| %>
                        <%= link_to gravatar_for(user, size: 30), user %>
                    <% end %>
                </div>
            <% end %>
        </section>
    <aside>
    <div class="col-md-8">
        <h3><%= @title %></h3>
        <% if @users.any? %>
            <ul class="users follow">
                <%= render @users %>
            </ul>
            <%= will_paginate %>
        <% end %>
    </div>
</div>
```

To test the show_follow rendering, we’ll write a couple of short integration tests that verify the presence of working following and followers pages. Our plan in the case of following/followers pages is to check the number is correctly displayed and that links with the right URLs appear on the page.

```bash
rails generate integration_test following
```

Next, we need to assemble some test data, which we can do by adding some relationships fixtures to create following/follower relationships in `relationships.yml`:
```yml
one:
  follower: michael
  followed: lana

two:
  follower: michael
  followed: malory

three:
  follower: lana
  followed: michael

four:
  follower: archer
  followed: michael
```

The fixtures arrange for Michael to follow Lana and Malory, and then arrange for Michael to be followed by Lana and Archer. To test for the right count, we can use the `assert_match` method to test for the display of the number of tweets on the user profile page. 
In the `integration/following_test.rb` just created, add:
```ruby
def setup
    @user = users(:michael)
    log_in_as(@user)
end

test "following page" do
    get following_user_path(@user)
    assert_not @user.following.empty?
    assert_match @user.following.count.to_s, response.body
    @user.following.each do |user|
        assert_select "a[href=?]", user_path(user)
    end
end

test "followers page" do
    get followers_user_path(@user)
    assert_not @user.followers.empty?
    assert_match @user.followers.count.to_s, response.body
    @user.followers.each do |user|
        assert_select "a[href=?]", user_path(user)
    end
end
```

### A working follow button the standard way
```bash
rails generate controller Relationships
```

We will write a test to check that attempts to access actions in the Relationships controller require a logged-in user (and thus get redirected to the login page), while also not changing the Relationship count in `relationships_controller_test.rb`:
```bash
test "create should require logged-in user" do
    assert_no_difference 'Relationship.count' do
        post relationships_path
    end
    assert_redirected_to login_url
end
  
test "destroy should require logged-in users" do
    assert_no_difference 'Relationship.count' do
        delete relationship_path(relationships(:one))
    end
    assert_redirected_to login_url
end
```

We then define the create and destroy actions in the `relationships_controller.rb` and a `logged_in_user` before action:
```ruby
before_action :logged_in_user

def create
    user = User.find(params[:followed_id])
    current_user.follow(user)
    redirect_to user
end

def destroy
    user = Relationship.find(params[:id]).followed
    current_user.unfollow(user)
    redirect_to user
end
```

### A working follow button with Ajax
Ajax allows web pages to send requests asynchronously to the server without leaving the page.

In `_follow.html.erb`, add `, remote: true` to `form_for`:
```html
<%= form_for(current_user.active_relationships.build, remote: true) do |f| %>
```

In the `form_for` tag for the `_unfollow.html.erb` partial, add `, remote: true`:
```html
<%= form_for(current_user.active_relationships.find_by(followed_id: @user.id),
             html: { method: :delete },
             remote: true) do |f| %>
```

This sets the variable data-remote="true" inside the form tag, which tells Rails to allow the form to be handled by JavaScript. By using a simple HTML property instead of inserting the full JavaScript code (as in previous versions of Rails), Rails follows the philosophy of unobtrusive JavaScript.

Having updated the form, we now need to arrange for the Relationships controller to respond to Ajax requests. We can do this using the `respond_to` method, responding appropriately depending on the type of request.

To the create and destroy actions of the `relationships_controller.rb` file:
```ruby
def create
    @user = User.find(params[:followed_id])
    current_user.follow(@user)
    respond_to do |format|
      format.html { redirect_to @user }
      format.js
    end
end

def destroy
    @user = Relationship.find(params[:id]).followed
    current_user.unfollow(@user)
    respond_to do |format|
        format.html { redirect_to @user }
        format.js
    end
end
```
Note the change from the local variable `user` to the instance variable `@user` due to the implicit nature of Ajax requests.

In `application.rb`, to handle requests fine in browsers that have Javacript disabled:
```ruby
# Include the authenticity token in remote forms.
config.action_view.embed_authenticity_token_in_remote_forms = true
```

On the other hand, we have yet to respond properly when JavaScript is enabled. In the case of an Ajax request, Rails automatically calls a JavaScript embedded Ruby (.js.erb) file with the same name as the action, i.e., `create.js.erb` or `destroy.js.erb`.

In the `views/relationships/create.js.erb` file, add:
```js
$("#follow_form").html("<%= escape_javascript(render('users/unfollow')) %>");
$("#followers").html('<%= @user.followers.count %>');
```

In the `views/relationships/destroy.js` file, add:
```js
$("#follow_form").html("<%= escape_javascript(render('users/follow')) %>");
$("#followers").html('<%= @user.followers.count %>');
```
The `escape_javascript` method, is needed to escape out the result when inserting HTML in a JavaScript file.

## Following Tests
To follow a user, we post to the relationships path and verify that the number of followed users increases by 1. The same parallel structure applies to deleting users, with `delete` instead of `post`. Here we check that the followed user count goes down by 1 and include the relationship and followed user’s id.

In `following_test.rb` file add:
```ruby
def setup
    .
    @other = users(:archer)
    .
end
.
.
.
test "should follow a user the standard way" do
    assert_difference '@user.following.count', 1 do
        post relationships_path, params: { followed_id: @other.id }
    end
end
  
test "should follow a user with Ajax" do
    assert_difference '@user.following.count', 1 do
        post relationships_path, xhr: true, params: { followed_id: @other.id }
    end
end
  
test "should unfollow a user in the standard way" do
    @user.follow(@other)
    relationship = @user.active_relationships.find_by(followed_id: @other.id)
    assert_difference '@user.following.count', -1 do
        delete relationship_path(relationship)
    end
end
  
test "should unfollow a user with Ajax" do
    @user.follow(@other)
    relationship = @user.active_relationships.find_by(followed_id: @other.id)
    assert_difference '@user.following.count', -1 do
        delete relationship_path(relationship), xhr: true
    end
end
```
`xhr` here stands for XMLHttpRequest; setting the `xhr` option to `true` issues an Ajax request in the test, which causes the `respond_to` block in `relationships_controller.rb` to execute the proper JavaScript method.

## The Status Feed
The full status feed builds on the proto-feed by assembling an array of the microposts from the users being followed by the current user, along with the current user’s own tweets. The purpose of a feed is to pull out the tweets whose user ids correspond to the users being followed by the current user (and the current user itself).

We will write the tests to check the implementation of this feed in `user_test.rb` file:
```ruby
test "feed should have the right posts" do
    michael = users(:michael)
    archer  = users(:archer)
    lana    = users(:lana)
    # Posts from followed user
    lana.tweets.each do |post_following|
        assert michael.feed.include?(post_following)
    end
    # Posts from self
    michael.tweets.each do |post_self|
        assert michael.feed.include(post_self)
    end
    # Posts from unfollowed user
    archer.tweets.each do |post_unfollowed|
        assert_not michael.feed.include?(post_unfollowed)
    end
end
```

### A first feed implementation
In the `user.rb` file, redefine the `feed` and `follow` methods as below:
```ruby
.
.
.
# Returns a user's status feed.
def feed
    Tweet.where("user_id IN (?) OR user_id = ?", following_ids, id)
end

# Follows a user.
def follow(other_user)
    active_relationships.create(followed_id: other_user.id)
end
.
.
.
```

### Subselects
As hinted at in the last section, the feed implementation above doesn’t scale well when the number of tweets in the feed is large, as would likely happen if a user were following, say, 5000 other users. The problem with the code is that following_ids pulls all the followed users’ ids into memory, and creates an array the full length of the followed users array.

Since the condition in the code actually just checks inclusion in a set, there must be a more efficient way to do this, and indeed SQL is optimized for just such set operations. The solution involves pushing the finding of followed user ids into the database using a subselect.

We’ll start by refactoring the feed with the slightly modified code in `user.rb`:
```ruby
# Returns a user's status feed.
def feed
    following_ids = "SELECT followed_id FROM relationships
                     WHERE  follower_id = :user_id"
    Tweet.where("user_id IN (#{following_ids}) OR user_id = :user_id", user_id: id)
end
```

To conclude, push to both git and heroku:
```bash
