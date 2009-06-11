# Really more like TokyoTable...
class FakeTokyoCabinet < Hash
  
  class FakeQuery
    attr_reader :order, :conditions, :limit_value
    
    def initialize
      @conditions = []
    end
    
    def add_condition(key, op, value)
      @conditions << [key, op, value]
    end
    
    def order_by(column, direction = :asc)
      @order = [column, direction]
    end
    
    def limit(limit)
      @limit_value = limit
    end
  end
  
  def get(id)
    if id.is_a?(Array)
      id.map{|i| get(id)}
    else
      self[id]
    end
  end

  OP_MAP = {:eql => :==}
  def query
    fq = FakeQuery.new
    yield fq
    results = []
    self.each do | key, record |
      fq.conditions.each do | key, op, value |
        puts "#{key.inspect}:#{op}:#{value.inspect}"
        puts record.inspect
        if record[key.to_s]
          puts "exist"
          if record[key.to_s].send(OP_MAP[op], value)
            puts "answer"
            results << record
          end
        end
      end
    end
    
    
    results.uniq!
    
    if fq.order
      results = results.order_by{|r| r[fq.order[0]]}
      if fq.order[1] == :desc
        results.reverse!
      end
    end
    
    if fq.limit_value
      results = results[0..(fq.limit_value - 1)]
    end
  end
  
end