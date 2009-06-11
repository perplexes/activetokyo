module ActiveTokyo
  class ClassMethods
    def create(hash, options={})
      o = self.new(hash, options, true)
      o.save
      o
    end

    def instantiate(hash, options={})
      self.new(hash, options, false)
    end

    def belongs_to(*args)
      args.flatten.each{|a| self.associations[a] = :belongs_to}
    end

    def has_many(*args)
      args.flatten.each{|a| self.associations[a] = :has_many}
    end

    def find(*args)
      options = args.extract_options!

      case args.first
        when :first then find_initial(options)
        when :last  then find_last(options)
        when :all   then find_every(options)
        else             find_from_ids(args, options)
      end
    end

    def find_last(options)
      order = options[:order]

      if order
        order = reverse_sql_order(order)
      else
        order = "id DESC"
      end

      # if scoped?(:find, :order)
      #   scope = scope(:find)
      #   original_scoped_order = scope[:order]
      #   scope[:order] = reverse_sql_order(original_scoped_order)
      # end

      begin
        find_initial(options.merge({ :order => order }))
      ensure
        #scope[:order] = original_scoped_order if original_scoped_order
      end
    end

    def reverse_sql_order(order_query)
      reversed_query = order_query.to_s.split(/,/).each { |s|
        if s.match(/\s(asc|ASC)$/)
          s.gsub!(/\s(asc|ASC)$/, ' DESC')
        elsif s.match(/\s(desc|DESC)$/)
          s.gsub!(/\s(desc|DESC)$/, ' ASC')
        elsif !s.match(/\s(asc|ASC|desc|DESC)$/)
          s.concat(' DESC')
        end
      }.join(',')
    end

    # A convenience wrapper for <tt>find(:first, *args)</tt>. You can pass in all the
    # same arguments to this method as you can to <tt>find(:first)</tt>.
    def first(*args)
      find(:first, *args)
    end

    # A convenience wrapper for <tt>find(:last, *args)</tt>. You can pass in all the
    # same arguments to this method as you can to <tt>find(:last)</tt>.
    def last(*args)
      find(:last, *args)
    end

    # This is an alias for find(:all).  You can pass in all the same arguments to this method as you can
    # to find(:all)
    def all(*args)
      find(:all, *args)
    end

    def find_every(options)
      #include_associations = merge_includes(scope(:find, :include), options[:include])

      #if include_associations.any? && references_eager_loaded_tables?(options)
      #  records = find_with_associations(options)
      #else
        records = find_by_objects(options)
      #  if include_associations.any?
      #    preload_associations(records, include_associations)
      #  end
      #end

      records.each { |record| record.readonly! } if options[:readonly]

      records
    end

    def find_initial(options)
      options.update(:limit => 1)
      find_every(options).first
    end

    def find_one(id, options)
      options[:conditions] ||= {}
      options[:conditions][:id] = id
      result = find_by_objects(options)
      raise RecordNotFound unless result.size == 1
      result.first
    end

    def find_some(ids, options)
      options[:conditions] ||= {}
      options[:conditions][:id] = ids

      result = find_every(options)

      # Determine expected size from limit and offset, not just ids.size.
      expected_size =
        if options[:limit] && ids.size > options[:limit]
          options[:limit]
        else
          ids.size
        end

      # 11 ids with limit 3, offset 9 should give 2 results.
      if options[:offset] && (ids.size - options[:offset] < expected_size)
        expected_size = ids.size - options[:offset]
      end

      if result.size == expected_size
        result
      else
        raise RecordNotFound, "Couldn't find all #{name.pluralize} with IDs (#{ids_list})#{conditions} (found #{result.size} results, but was looking for #{expected_size})"
      end
    end

    def find_from_ids(ids, options)
      expects_array = ids.first.kind_of?(Array)
      return ids.first if expects_array && ids.first.empty?

      ids = ids.flatten.compact.uniq

      case ids.size
        when 0
          raise RecordNotFound, "Couldn't find #{name} without an ID"
        when 1
          result = find_one(ids.first, options)
          expects_array ? [ result ] : result
        else
          find_some(ids, options)
      end
    end

    def find_by_objects(options = {})
      conditions = options[:conditions] || {}
      if conditions.is_a?(String)
        return []
      end

      if id_or_ids = conditions.delete(:id)
        return [connection.get(id_or_ids)].flatten
      end

      results = connection.query do | q |
        conditions.each do | key, value |
          q.add_condition key, :eql, value
        end
        if order = options[:order]
          column, str_dir = order.split
          q.order_by column, str_dir.downcase.intern
        end
        if limit = options[:limit]
          q.limit limit
        end
      end

      results.map{|r| instantiate(r)}
    end

    def query(*a, &b)
      self.connection.query(*a, &b).map{|r| find_create(r)}
    end
  end
end