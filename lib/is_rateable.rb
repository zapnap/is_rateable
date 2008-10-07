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
      self.rating_categories = (options[:categories] || []).map { |c| c.to_s }
    end
  end

  module InstanceMethods
    def rating(*args)
      options = args.extract_options!
      category = options.delete(:category)
      user_or_ip = options.delete(:user) || options.delete(:ip)

      if user_or_ip && Rating.instance_methods.include?('user')
        options[:conditions] = ["user_id = ?", user_or_ip.id]
      elsif user_or_ip
        options[:conditions] = ["ip = ?", user_or_ip]
      end

      unless category.nil?
        if options[:conditions]
          options[:conditions][0] += " AND category = ?"
          options[:conditions] << category.to_s
        else
          options[:conditions] = ["category = ?", category.to_s]
        end
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
    
    def rating_in_words(*args)
      options = args.extract_options!
      case rating(options)
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
        rating(options).to_s
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
      user = options[:user] || options[:ip]

      case type
      when :simple
        "#{record.rating(:category => category, :user => user)}/#{record.maximum_rating_allowed} #{pluralize(record.rating(:category => category, :user => user), units)}"
      when :interactive_stars
        content_tag(:ul, :class =>  "rating #{record.rating_in_words(:category => category, :user => user)}star") do
          (record.minimum_rating_allowed..record.maximum_rating_allowed).map do |i|
            content_tag(:li, link_to(i, rating_url(record, i, category), :title => "Rate this #{pluralize(i, units)} out of #{record.maximum_rating_allowed}", :method => :put), :class => "rating-#{i}")
          end.join("\n")
        end
      end
    end
  end
end
