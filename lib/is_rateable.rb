module IsRateable
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    # Add this method to your model
    #
    #   is_rateable
    #
    # which specifies the maximum allowed units to be 5. To specify anything else do the following:
    #
    #   is_rateable :upto => 10
    #
    # you can also specify categories for ratings
    #
    #   is_rateable :categories => [:strength, :intelligence, :wisdom]
    #
    def is_rateable(options={})
      include InstanceMethods
      has_many :ratings, :as => :rateable
      
      cattr_accessor :minimum_rating_allowed, :maximum_rating_allowed, :rating_categories
      self.minimum_rating_allowed = options[:from] || 1
      self.maximum_rating_allowed = options[:upto] || 5
      self.rating_categories = options[:categories]
    end
  end

  module InstanceMethods
    def rating(category = nil)
      options = {}
      options[:conditions] = ["category = ?", category.to_s] unless category.nil?
      if (rating = ratings.average(:value, options))
        rating.round
      else
        0
      end
    end

    def user_rating(user_or_ip, category = nil)
      options = {}
      if attributes.include?('user_id')
        options[:conditions] = ["user_id = ?", user_or_ip.id]
      else
        options[:conditions] = ["ip = ?", user_or_ip]
      end

      unless category.nil?
        options[:conditions][0] += " AND category = ?"
        options[:conditions] << category.to_s
      end

      if (rating = ratings.average(:value, options))
        rating.round
      else
        0
      end
    end

    def rating_range
      minimum_rating_allowed..maximum_rating_allowed
    end
    
    def rate(value, options={})
      ratings.create({ :value => value }.merge(options))
    end
    
    def rating_in_words(category = nil)
      case rating(category)
      when 0
        "no"
      when 1
        "one"
      when 2
        "two"
      when 3
        "three"
      when 4
        "four"
      when 5
        "five"
      else
        rating(category).to_s
      end      
    end
  end

  module ViewMethods
    # polymorphic url sucks big time. unfortunately I ended up having to create a method to do this.
    def rating_url(record, value, category = nil)
      url_options = { :controller => record.class.to_s.downcase.pluralize, 
                      :id => record.to_param, 
                      :action => "rate", 
                      :rating => value }
      url_options[:category] = category unless category.nil?
      url_for url_options
    end

    def render_rating(record, *args)
      options = args.extract_options!
      type = options[:type] || :simple
      units = options[:units] || 'star'
      category = options[:category]

      case type
      when :simple
        "#{record.rating(category)}/#{record.maximum_rating_allowed} #{pluralize(record.rating(category), units)}"
      when :interactive_stars
        content_tag(:ul, :class =>  "rating #{record.rating_in_words(category)}star") do
          (record.minimum_rating_allowed..record.maximum_rating_allowed).map do |i|
            content_tag(:li, link_to(i, rating_url(record, i, category), :title => "Rate this #{pluralize(i, units)} out of #{record.maximum_rating_allowed}", :method => :put), :class => "rating-#{i}")
          end.join("\n")
        end
      end
    end
  end
end
