class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true, optional: true
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  validates :body, presence: true, length: { maximum: 1000 }

  scope :oldest, -> { order(created_at: :asc) }
  scope :roots,  -> { where(parent_id: nil) }
end
