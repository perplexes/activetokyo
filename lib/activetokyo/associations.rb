module ActiveTokyo
  class Associations
    def included(base)
      base.include(ClassMethods)
    end
    
    class AssociationProxy
      def initialize(name, options)
        @name, @options = name, options
      end
    end
    
    class BelongsToAssociation < AssociationProxy; end
    class HasOneAssociation < AssociationProxy; end
    class AssociationCollection < AssociationProxy; end
    class HasAndBelongsToManyAssocication < AssociationCollection; end
    class HasManyAssociation < AssociationCollection; end
    
    class ClassMethods
      ASSOCIATION_TYPES = %w(belongs_to has_and_belongs_to_many has_one has_many)
      ASSOCIATION_CLASS_MAP = ASSOCIATION_TYPES.inject({}) do | hash, type |
        hash[type] = "#{type}_association".camelize.constantize; hash
      end
      
      ASSOCIATION_TYPES.each do | assoc_type |
        eval <<-"end_eval", __FILE__, __LINE__
          def #{assoc_type}(*args)
            options = args.last.is_a?(Hash) ? args.pop : {}
            self.associations += args.map do |arg| 
              #{ASSOCIATION_CLASS_MAP[assoc_type]}.new(arg, options)
            end
          end
        end_eval
      end#ASSOCIATION_TYPES.each
    end#ClassMethods
  end#Associations
end#ActiveTokyo