require 'test_helper'

class TweetsInterfaceTest < ActionDispatch::IntegrationTest
  
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
    content = "This tweet really ties the room together"
    assert_difference 'Tweet.count', 1 do
      post tweets_path, params: { tweet: { content: content } }
    end
    assert_redirected_to root_url
    follow_redirect!
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

end
