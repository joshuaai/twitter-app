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

```
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
```
def setup
    @user = User.new(name: "Example User", email: "user@example.com")
end

test "should be valid" do
    assert @user.valid?
end
```

Create a test that validates the presence of certain elements in `user_test.rb` file.

To the user.rb file, add 
```
validates :name, presence: true
VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }
```

Add database indicies for email uniqueness validation at the database level.
This is because the Active Record uniqueness validation does not guarantee uniqueness at the database level.
```
rails generate migration add_index_to_users_email

In the migration file, add to the change method
add_index :users, :email, unique: true

rails db:migrate
rails db:reset if rails test fails.
```

### Secure Password
The method is to require each user to have a password (with a password confirmation), and then store a hashed 
version of the password in the database.

`rails generate migration add_password_digest_to_users password_digest:string`

Add the `gem 'bcrypt'` and run `bundle install` to hash the passwords in the database.

Add `has_secure_password` to user.rb

Add `password: "foobar", password_confirmation: "foobar"` to setup method in user_test.rb

Enforcing minimum password standards
```
To the user.rb model add
validates :password, presence: true, length: { minimum: 6 }
```