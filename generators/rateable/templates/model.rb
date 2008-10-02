# == Schema Information
#
# Table name: ratings
#
#  id            :integer(11)     not null, primary key
#  value         :integer(11)     default(0)
<% if options[:categories] %>#  category      :string<% end %>
<% if options[:by_user] %>#  user_id       :integer(11)<% else %>#  ip            :string(255)<% end %>
#  rateable_id   :integer(11)
#  rateable_type :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#
class Rating < ActiveRecord::Base
  belongs_to                :rateable, :polymorphic => true
  <% if options[:by_user] %>belongs_to                :user<% end %>

  validates_presence_of     :rateable_type, :rateable_id
  validates_numericality_of :value
  <% if options[:by_user] %>validates_presence_of     :user<% end %>
  <% if options[:categories] %>validates_presence_of     :category<% end %>
  validate                  :maximum_value_is_not_breached<% if options[:categories] %>, :category_is_allowed<% end %>
    
  def maximum_value_is_not_breached
    errors.add('value', 'is not in the range') unless rateable.rating_range.include?(value)
  end

  <% if options[:categories] %>
  def category_is_allowed
    if category.blank?
      errors.add('category', 'must be supplied')
    else
      errors.add('category', 'is not allowed') unless rateable.rating_categories.include?(category)
    end
  end
  <% end %>
  
  before_save               :delete_last_rating
  
  def delete_last_rating
    if (rating = Rating.find_similar(self))
      rating.destroy
    end
  end
  
  def self.find_similar(rating)
    Rating.find(:first, :conditions => { <% if options[:by_user] %>:user_id => rating.user_id<% else %>:ip => rating.ip<% end %>,
                                         <% if options[:categories] %>:category => rating.category,<% end %>
                                         :rateable_id => rating.rateable_id, :rateable_type => rating.rateable_type })
  end
end
