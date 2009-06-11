module ActiveTokyo
  class Base
    cattr_accessor :connection
    @@connection = FakeTokyoCabinet.new
    class_inheritable_accessor :associations
    self.associations = {}.with_indifferent_access

    attr_accessor :attributes

    def initialize(attributes, options={}, new_record = true)
      @new_record = new_record
      @attributes = attributes.with_indifferent_access
      unless @attributes.key?(:type)
        @attributes.merge!(:type => self.class.name)
      end
      @new_attributes = {}
      @association_cache = {}

      if options[:include]
        (self.class.associations & [options[:include]].flatten).each do | key |
          load_association(key)
        end
      end

      @attributes.each do | key, value |
        case value
        when /2009-06-01T12:54:42Z/
          @attributes[key] = Time.parse(value)
        when /2009-06-01/
          @attributes[key] = Date.parse(value)
        end
      end
    end

    def reload
      self.class.find(self.id)
    end

    def id
      self[:id]
    end

    def id=(value)
      raise "Don't do this."
    end

    def [](key)
      case self.class.associations[key]
      when :belongs_to
        load_belongs_to_association(key)
      when :has_many
        load_has_many_association(key)
      else
        @attributes[key]
      end
    end

    def []=(key, value)
      @attributes[key] = value
      @new_attributes[key] = value
    end

    def update_attribute(key, value)
      self[key] = value
      save
    end

    def update_attributes(hash)
      hash.each do | key, value |
        self[key] = value
      end
      save
    end

    def load_belongs_to_association(key)
      return @association_cache[key] if @association_cache.key?(key)
      return @association_cache[key] = nil unless @attributes.key?(key)

      record = self.class.connection[@attributes[key]]
      @association_cache[key] = record[:type].constantize.instantiate(record)
    end

    def load_has_many_association(key)
      return @association_cache[key] if @association_cache.key?(key)
      return @association_cache[key] = [] unless @attributes.key?(key)

      raise "Attribute type mismatch: expected array." unless @attributes[key].is_a?(Array)
      return @attributes[key] if @attributes[key].empty?
      return @attributes[key] if @attributes[key].all?{|o| o.is_a?(ActiveTokyo)}

      @association_cache[key] = @attributes[key].map do | record_or_id |
        if record_or_id.is_a?(ActiveTokyo)
          record_or_id
        else
          record = self.class.connection[record_or_id]
          record[:type].constantize.instantiate(record)
        end
      end
    end

    def unique_id
      begin
        id = `uuidgen`.chomp
      end while self.class.connection[id]
      id
    end

    def save
      @attributes[:id] ||= unique_id

      @association_cache.each do | key, value |
        case self.class.associations[key]
        when :belongs_to, :has_one
          if value.is_a?(ActiveTokyo)
            value.save if value.new_record?
            @attributes[key] = value.id
          end
        when :has_many
          @attributes[key] = value.map do | record_or_id |
            if record_or_id.is_a?(ActiveTokyo)
              record_or_id.save if record_or_id.new_record?
              record_or_id.id
            else
              record_or_id
            end
          end
        end
      end

      @attributes.each do | key, value |
        case value
        when Time, DateTime
          @attributes[key] = value.to_time.iso8601
        when Date
          @attributes[key] = value.strftime("%Y-%m-%d")
        end
      end

      now = Time.now

      @attributes[:created_at] = now if new_record?
      @attributes[:updated_at] = now

      self.class.connection[@attributes[:id]] = @attributes
      @new_attributes = {}
      @new_record = false
      true
    end

    def new_record?
      @new_record
    end

    # Dynamic attributes!
    def method_missing(m, *args)
      case m.to_s
      # record.active? => record.active
      when /^(.*)\?$/
        self[$1]
      # record.active=false => "record['active'] = false"
      when /^(.*)=$/
        @attributes[$1] = args.first
      # record.active => record[:active]
      else
        self[m]
      end
    end
  end
end