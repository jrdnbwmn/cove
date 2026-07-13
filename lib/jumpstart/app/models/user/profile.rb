module User::Profile
  extend ActiveSupport::Concern

  included do
    has_prefix_id :user

    has_one_attached :avatar
    has_person_name

    validates :avatar, resizable_image: true
    validates :name, presence: true
  end
end
