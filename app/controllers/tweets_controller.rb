class TweetsController < ApplicationController
    before_action :logged_in_user, only: [:create, :destroy]
    before_action :correct_user,   only: :destroy

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

    def destroy
      @tweet.destroy
      flash[:success] = "Tweet deleted"
      redirect_to request.referrer || root_url
    end

    private

    def tweet_params
      params.require(:tweet).permit(:content, :picture)
    end

    def correct_user
      @tweet = current_user.tweets.find_by(id: params[:id])
      redirect_to root_url if @tweet.nil?
    end
end
