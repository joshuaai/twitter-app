# Implementing Tweets and Followers
In the course of developing this app, we’ve encountered four resources — users, sessions, account activations, and password resets — but only the first of these is backed by an Active Record model with a table in the database. We will add `Tweets` as another such resource.

## The Tweet Model
The `Tweet` model will include data validations and an association with the `User` model. It will be fully tested, and will also have a default ordering and automatic destruction if its parent user is destroyed.
```bash
git checkout -b user-tweets

rails generate model Tweet content:text user:references
```
The biggest difference is the use of references, which automatically adds a user_id column (along with an index and a foreign key reference) for use in the user/tweet association.

In the `[timestamp]_create_tweets.rb` file after the `create_table` function inside the `change` method add:
```ruby
add_index :tweets, [:user_id, :created_at]
```
Run the `rails db:migrate` command.

### Tweet Validations
Because every tweet should have a user id and content of appropriate length, we’ll add a test for a `user_id` presence validation and `content` presence and length.

In the `tweet_test.rb` file, add:
```ruby
def setup
    @user = users(:michael)
    # This code is not idiomatically correct ==> @tweet = Tweet.new(content: "Lorem ipsum", user_id: @user.id)
    @tweet = @user.tweets.build(content: "Lorem Ipsum")
end

test "should be valid" do
    assert @tweet.valid?
end

test "user id should be present" do
    @tweet.user_id = nil
    assert_not @tweet.valid?
end

test "content should be present" do
    @tweet.content = "   "
    assert_not @tweet.valid?
end

test "content should be at most 140 characters" do
    @tweet.content = "a" * 141
    assert_not @tweet.valid?
end
```
As with new, build returns an object in memory but doesn’t modify the database.

In the `tweet.rb` model file, validate that a `user_id` is present:
```ruby
validates :user_id, presence: true
validates :content, presence: true, length: { maximum: 140 }
```
Run the `rails test:models` command to verify that the test passes.

### User/Tweet Associations
In the present case, each tweet is associated with one user, and each user is associated with (potentially) many tweets.

In the `user.rb` model file, to tmake the `@user.tweets.build(content: "Lorem Ipsum")` block in the test to work, add:
```ruby
has_many :tweets
```

### Tweet Refinements
By default, the user.tweets method makes no guarantees about the order of the posts. The **first refinement** is that we want the tweets to come out in reverse order of when they were created so that the most recent post is first. We’ll arrange for this to happen using a default scope.

Add the test for scope to `tweet_test.rb` file:
```ruby
.
.
.
test "order should be most recent first" do
    assert_equal tweets(:most_recent), Tweet.first
end
```

The test above relies on having some tweet fixtures in `fixtures/tweets.yml`:
```yml
orange:
  content: "I just ate an orange!"
  created_at: <%= 10.minutes.ago %>

tau_manifesto:
  content: "Check out the @tauday site by @mhartl: http://tauday.com"
  created_at: <%= 3.years.ago %>

cat_video:
  content: "Sad cats are sad: http://youtu.be/PKffm2uI4dk"
  created_at: <%= 2.hours.ago %>

most_recent:
  content: "Writing a short test"
  created_at: <%= Time.zone.now %>
```

Add the default scope to `tweet.rb` after `belongs_to :user`: `default_scope -> { order(created_at: :desc) }`.

The **second refinement** is ensuring that a user's tweets are destroyed along with the user by the admin. We ensure this by passing an option to the `has_many` association method: `has_many :tweets, dependent: :destroy`.

Here the option `dependent: :destroy` arranges for the dependent tweets to be destroyed when the user itself is destroyed.  This prevents userless tweets from being stranded in the database when admins choose to remove users from the system.

Add a test to `user_test.rb` that verifies that the user's tweets are deleted:
```ruby
test "associated tweets should be destroyed" do
    @user.save
    @user.tweets.create!(content: "Lorem ipsum")
    assert_difference 'Tweet.count', -1 do
        @user.destroy
    end
end
```

### Showing Tweets
Our plan is to display the tweets for each user on their respective profile page (show.html.erb), together with a running count of how many tweets they’ve made.
```bash
rails generate controller Tweets
```
We’ll define an analogous `views/tweets/_tweet.html.erb` partial to display a collection of tweets.
```html
<li id="tweet-<%= tweet.id %>">
  <%= link_to gravatar_for(tweet.user, size: 50), tweet.user %>
  <span class="user"><%= link_to tweet.user.name, tweet.user %></span>
  <span class="content"><%= tweet.content %></span>
  <span class="timestamp">
    Posted <%= time_ago_in_words(tweet.created_at) %> ago.
  </span>
</li>
```
To the `users_controller.rb` show action, add:
```ruby
@tweets = @user.tweets.paginate(page: params[:page])
```
This will paginate the tweets on the user's page.

In the `show.html.erb` file, under the `aside` tag, add the display for the tweets:
```html
<div class="col-md-8">
    <% if @user.tweets.any? %>
        <h3>Tweets (<%= @user.tweets.count %>)</h3>
        <ol class="tweets">
            <%= render @tweets %>
        </ol>
        <%= will_paginate @tweets %>
    <% end %>
</div>
```

Use the `seeds.rb` to give tweets to the first six users using the `take` method:
```ruby
users = User.order(:created_at).take(6)
50.times do
  content = Faker::Lorem.sentence(5)
  users.each { |user| user.tweets.create!(content: content) }
end
```

In the `custom.scss`, add:
```css
/* tweets */

.tweets {
  list-style: none;
  padding: 0;
  li {
    padding: 10px 0;
    border-top: 1px solid #e8e8e8;
  }
  .user {
    margin-top: 5em;
    padding-top: 0;
  }
  .content {
    display: block;
    margin-left: 60px;
    img {
      display: block;
      padding: 5px 0;
    }
  }
  .timestamp {
    color: $gray-light;
    display: block;
    margin-left: 60px;
  }
  .gravatar {
    float: left;
    margin-right: 10px;
    margin-top: 5px;
  }
}

aside {
  textarea {
    height: 100px;
    margin-bottom: 5px;
  }
}

span.picture {
  margin-top: 10px;
  input {
    border: 0;
  }
}
```

#### Profile Tweets Test
```bash
rails generate integration_test users_profile
```
Associalte the fixture tweets with a user by adding `user: michael` to each fixture.

To test tweet pagination, we’ll also generate some additional tweet fixtures using:
```yml
<% 30.times do |n| %>
tweet_<%= n %>:
  content: <%= Faker::Lorem.sentence(5) %>
  created_at: <%= 42.days.ago %>
  user: michael
<% end %>
``` 

In the generated `users_profile_test.rb` file we add the test. 
We visit the user profile page and check for the page title and the user’s name, Gravatar, tweet count, and paginated tweets. Then we use the `full_title` helper from `application_helper.rb` to test the page’s title, which we gain access to by including the Application Helper module, all in the integration class:
```ruby
include ApplicationHelper

def setup
    @user = users(:michael)
end

test "profile display" do
    get user_path(@user)
    assert_template 'users/show'
    assert_select 'title', full_title(@user.name)
    assert_select 'h1', text: @user.name
    assert_select 'hi>img.gravatar'
    assert_match @user.tweets.count.to_s, response.body
    assert_select 'div.pagination'
    @user.tweets.paginate(page: 1).each do |tweet|
        assert_match tweet.content, response.body
    end
end
```

### Manipulating Tweets
The interface to the Tweets resource will run principally through the Profile and Home pages, so we won’t need actions like new or edit in the Tweets controller; we’ll need only create and destroy.

To the `routes.rb` file, add `resources :tweets, only: [:create, :destroy]`

#### Tweet Access Control
Both the `create` and `destroy` actions must require users to be logged in.

To test this, we simply issue the correct request to each action to confirm that the tweet count is unchanged and the result is redirected to the login URL.

In the `tweets_controller_test.rb` file, add:
```ruby
def setup
    @tweet = tweets(:orange)
end

test "should redirect create when not logged in" do
    assert_no_difference 'Tweet.count' do
        post tweets_path, params: { tweet: { content: "Lorem Ipsum" } }
    end
    assert_redirected_to login_url
end

test "should redirect destroy when not logged in" do
    assert_no_difference 'Tweet.count' do
        delete tweet_path(@tweet)
    end
    assert_redirected_to login_url
end
```

Typically, we have enforced login requirements in the users controller using a before filter the called the `logged_in_user` method. Now we need it in the tweets controller, it makes sense to move the method to the `application_controller.rb` file:
```ruby
private

    # Confirms a logged-in user.
    def logged_in_user
        unless logged_in?
            store_location
            flash[:danger] = "Please log in."
            redirect_to login_url
        end
    end
```
To avoid code repetition, remove this method from the `users_controller.rb` file.

In the `tweets_controller.rb` file, add:
```ruby
before_action :logged_in_user, only: [:create, :destroy]

def create
end

def destroy
end
```

#### Creating Tweets
Rather than using a separate page at `/tweets/new`, we will put the form on the homepage.

We update the `tweets_controller.rb` as follows:
```ruby
def create
    @tweet = current_user.tweets.build(tweet_params)
    if @tweet.save
        flash[:success] = "Tweet created!"
        redirect_to root_url
    else
        @feed_items = []
        render 'static_pages/home'
    end
end

private

    def tweet_params
      params.require(:tweet).permit(:content)
    end
```

To build a form for creating tweets, we write code which serves up different HTML based on whether the site visitor is logged in or not. We add this in `static_pages/home.html.erb` as below:
```html
<% if logged_in? %>
  <div class="row">
    <aside class="col-md-4">
      <section class="user_info">
        <%= render 'shared/user_info' %>
      </section>
      <section class="tweet_form">
        <%= render 'shared/tweet_form' %>
      </section>
    </aside>
  </div>
<% else %>
.
.
.
<% end %>
```

To get this working, we create and fill in a couple of partials. Create the `views/shared/_user_info.html.erb` partial and add:
```html
<%= link_to gravatar_for(current_user, size: 50), current_user %>
<h1><%= current_user.name %></h1>
<span><%= link_to "view my profile", current_user %></span>
<span><%= pluralize(current_user.tweets.count, "tweet") %></span>
```

To the `_tweet_form.html.erb` file, add:
```html
<%= form_for(@tweet) do |f| %>
  <%= render 'shared/error_messages', object: f.object %>
  <div class="field">
    <%= f.text_area :content, placeholder: "Compose new tweet..." %>
  </div>
  <%= f.submit "Post", class: "btn btn-primary" %>
<% end %>
```

In the `static_pages_controller.rb` file, we need to add to the home action:
```ruby
def home
    @tweet = current_user.tweets.build if logged_in?
end
```

Next we redefine the the error messages file partial so the code, `<%= render 'shared/error_messages', object: f.object %>`, works. To achieve this, turn the explicit `@user` definitions in the `_error_messages.html.erb` to `object` to allow it accomodate for the @user, @tweet and other objects.

In the generic `_form.html.erb` file, change the `object: @user` definiton to `object: f.object`.

#### Creating a Mini-feed
In the `user.rb` model, add the feed action:
```ruby
def feed
    Tweet.where("user_id = ?", id)
end
```

To use the feed action, we add a `@feed_items` instance variable for the current user's paginated feed, and then add a status feed partial to the Home page.

Change the home action of the `static_pages_controller.rb` file to:
```ruby
def home
    if logged_in?
      @tweet  = current_user.tweets.build
      @feed_items = current_user.feed.paginate(page: params[:page])
    end
end
```

Add the `shared/_feed.html.erb` status feed partial and add:
```html
<% if @feed_items.any? %>
  <ol class="tweets">
    <%= render @feed_items %>
  </ol>
  <%= will_paginate @feed_items %>
<% end %>
```

We can add the feed to the Home page by rendering the feed partial as usual in `static_pages/home.html.erb`:
```html
<div class="col-md-8">
    <h3>Tweet Feed</h3>
    <%= render 'shared/feed' %>
</div>
```

#### Destroying Tweets
The last piece of functionality to add to the Twitters resource is the ability to destroy posts. We add a delete link to the tweet partial in the `_tweet.html.erb` file, inside the `timestamp` class:
```html
<% if current_user?(tweet.user) %>
    <%= link_to "delete", tweet, method: :delete,
                                       data: { confirm: "You sure?" } %>
<% end %>
```

The next step is to define a `destroy` action in the Tweets controller
```ruby
before_action :correct_user,   only: :destroy
.
.
.
def destroy
    @tweet.destroy
    flash[:success] = "Tweet deleted"
    redirect_to request.referrer || root_url
end

private

    .
    .
    .
    def correct_user
      @tweet = current_user.tweets.find_by(id: params[:id])
      redirect_to root_url if @tweet.nil?
    end
```

#### Tweet Tests
We will write a short Tweets controller test to check authorization and tweet integration test to tie it all together.

We start by adding a few tweets to the fixtures:
```yml
ants:
  content: "Oh, is that what you want? Because that's how you get ants!"
  created_at: <%= 2.years.ago %>
  user: archer

zone:
  content: "Danger zone!"
  created_at: <%= 3.days.ago %>
  user: archer

tone:
  content: "I'm sorry. Your words made sense, but your sarcastic tone did not."
  created_at: <%= 10.minutes.ago %>
  user: lana

van:
  content: "Dude, this van's, like, rolling probable cause."
  created_at: <%= 4.hours.ago %>
  user: lana
```

Tests to ensure that one user can't delete the tweets of another and that there is proper redirect, in the `tweets_controller_test.rb` file:
```ruby
.
.
.
test "should redirect destroy for wrong tweet" do
    log_in_as(users(:michael))
    tweet = tweets(:ants)
    assert_no_difference 'Tweet.count' do
        delete tweet_path(tweet)
    end
    assert_redirected_to root_url
end
```

Finally, we write an integration test to log in, check the tweet pagination, make an invalid submission, make a valid submission, make a post and then visit the second user's page to make sure there are no "delete" links.
```bash
rails generate integration_test tweets_interface
```

In the generated `tweets_interface_test.rb` file, add:
```ruby
def setup
    @user = users(:michael)
end

test "tweet interface" do
    log_in_as(@user)
    get root_path
    assert_select 'div.pagination'
    # Invalid submission
    assert_no_difference 'Tweet.count' do
        post tweets_path, params: { tweet: { content: "" } }
    end
    assert_select 'div#error_explanation'
    # Valid submission
    assert_difference 'Tweet.count', 1 do
        post tweets_path, params: { tweet: { content: "This tweet really ties the room together" } }
    end
    assert_redirected_to root_url
    follow redirect!
    assert_match content, response.body
    # Delete post
    assert_select 'a', text: 'delete'
    first_tweet = @user.tweets.paginate(page: 1 ).first
    assert_difference 'Tweet.count', -1 do
        delete tweet_path(first_tweet)
    end
    # Visit different user (no delete links)
    get user_path(users(:archer))
    assert_select 'a', text: 'delete', count: 0
end
```

### Uploading Tweet Images
We'll make it possible for tweets to include images as well as text. This involves two main visible elements: a form field for uploading an image and the tweet images themselves.

Add the in the order below, the following gems to the `Gemfile`
```ruby
# Carrier Wave Image Uploader
gem 'carrierwave'
# Cloudinary image handler and resizer
gem 'cloudinary'
# Carrier Wave image resizers
gem 'mini_magick'
gem 'fog', '1.40.0'
```
Run `bundle install`.

CarrierWave adds a Rails generator for creating an image uploader, which we’ll use to make an uploader for an image called picture:
```bash
rails generate uploader Picture
```

Images uploaded with CarrierWave should be associated with a corresponding attribute in an Active Record model, which simply contains the name of the image file in a string field.

To add the required picture attribute to the Tweet model, we generate a migration and migrate the development database:
```bash
rails generate migration add_picture_to_tweets picture:string
rails db:migrate
```

The way to tell CarrierWave to associate the image with a model is to use the mount_uploader method, which takes as arguments a symbol representing the attribute and the class name of the generated uploader. Just after the `default_scope` in `tweet.rb`, add:
```ruby
mount_uploader :picture, PictureUploader
```

Include a `file_field` tag in the `_tweet_form.html.erb` partial:
```html
<span class="picture">
    <%= f.file_field :picture %>
</span>
```

Add picture as one of the required strong params to the `tweets_controller.rb` file:
```ruby
def tweet_params
    params.require(:tweet).permit(:content, :picture)
end
```

Once the image has been uploaded, we can render it using the `image_tag` helper in the `_tweet.html.erb` partial by adding it inside the `contetn` span, right under `tweet.content`:
```html
<%= image_tag tweet.picture.url if tweet.picture? %>
```

#### Image Validation
The uploader is a good start, but has significant limitations. In particular, it doesn’t enforce any constraints on the uploaded file, which can cause problems if users try to upload large files or invalid file types. To remedy this defect, we’ll add validations for the image size and format, both on the server and on the client (i.e., in the browser).

In the generated `app/uploaders/picture_uploader.rb` file, uncomment the method below:
```ruby
# Add a white list of extensions which are allowed to be uploaded.
def extension_white_list
    %w(jpg jpeg gif png)
end
```

In the `tweet.rb` file, add the validation for the picture size as follows:
```ruby
.
.
.
validate :picture_size

private

    # Validates the size of an uploaded picture.
    def picture_size
      if picture.size > 5.megabytes
        errors.add(:picture, "should be less than 5MB")
      end
    end
```

To support the model validations, we’ll add two client-side checks on the uploaded image.
In the `picture` class in `_tweet_form.html.erb`, we will update the `file_field` to:
```html
<%= f.file_field :picture, accept: 'image/jpeg,image/gif,image/png' %>
```

Next, we’ll include a little JavaScript (or, more specifically, jQuery) in the same file to issue an alert if a user tries to upload an image that’s too big (which prevents accidental time-consuming uploads and lightens the load on the server):
```js
<script type="text/javascript">
  $('#tweet_picture').bind('change', function() {
    var size_in_megabytes = this.files[0].size/1024/1024;
    if (size_in_megabytes > 5) {
      alert('Maximum file size is 5MB. Please choose a smaller file.');
    }
  });
</script>
```

#### Image Resizing
We’ll be uploading images using `CarrierWave` and managing and resizing them using `Cloudinary`.

Add both gems to the `Gemfile`:
```bash
# Carrier Wave Image Uploader
gem 'carrierwave'
# Cloudinary image manager
gem 'cloudinary'
```

In the `picture_uploader.rb` file, simply add to the top:
```ruby
include Cloudinary::CarrierWave
```

In the `_tweet.html.erb` partial, replace the `image_tag` under `tweet.content` with:
```html
<%= cl_image_tag tweet.picture.url, :width => 200, :height => 200, :crop => :center if tweet.picture? %>
```

For uploading to the cloud, add the `cloudinary.yml` file from your cloudinary dashboard to the rails config folder.

Before pushing to Heroku, ensure that the test images do not get uploaded to the server, by adding to the `.gitignore` file:
```
# Ignore uploaded test images.
/public/uploads
```

Push to Git and Heroku
```bash
rails test
git add -A
git commit -m "Add user tweets"
git checkout master
git merge user-tweets
git push

git push heroku
heroku pg:reset DATABASE
heroku run rails db:migrate
heroku run rails db:seed
```

The final part of this program is the [Following Users](help_followers.md).

**-------------------------------------------------------** 

We can alternatively use `ImageMagick` by CarrierWave for manipulating the images to our taste.
```bash
sudo apt-get install imagemagick --fix-missing
``` 
or for Windows
```bash
choco install imagemagick
```
or for Mac
```bash
brew install imagemagick
```

In the `picture_uploader.rb` file, uncomment Carrier Wave's `include CarrierWave::MiniMagick`:
```ruby
include CarrierWave::MiniMagick
process resize_to_limit: [400, 400]

if Rails.env.production?
    storage :fog
else
    storage :file
end
```


