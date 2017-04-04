class AddPictureToTweets < ActiveRecord::Migration[5.0]
  def change
    add_column :tweets, :picture, :string
  end
end
