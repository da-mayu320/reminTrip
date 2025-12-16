class TravelInfo < ApplicationRecord
  belongs_to :user
  validates :provider, :snippet, presence: true
end
