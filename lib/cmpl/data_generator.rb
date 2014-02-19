module DataGenerator
  Tuple = Struct.new(:sets)
  Vector = Struct.new(:sets)
  class Set; end
  
  def DataGenerator.validate_schema(schema)
    schema.each do |k,v|
      if v.is_a? Class
        unless [Numeric, Range, Set, Symbol].include? v
          raise "Bad schema for key #{k}: #{v}"
        end
      elsif v.is_a? Hash
        v.each do |param,type|
          unless type == Numeric or type.is_a? Tuple
            raise "Bad schema for key #{k}.#{param}: #{type}"
          end
        end
      elsif v.is_a? Tuple or v.is_a? Vector
        # OK
      else
        raise "Bad schema for key #{k}: #{v}"
      end
    end
  end
  
  
  def DataGenerator.generate_data(schema, params)
    output = {sets: [], params: []}
    flat_params = []
    sets = []
    relations = []
    flat_relations = {}
    flat_vectors = {}
    
    schema.each do |k,v|
      if v.is_a? Class
        if v == Numeric
          flat_params << k
        elsif v == Symbol
          flat_params << k.to_s
        elsif v == Range
          sets << k
        elsif v == Set
          sets << k
        else
          raise "Bad schema for key #{k}: #{v} expected Numeric or Set"
        end
      elsif v.is_a? Tuple
        flat_relations[k] = v
      elsif v.is_a? Vector
        flat_vectors[k] = v
      elsif v.is_a? Hash
        sets << k
      end
    end
    
    flat_params.each do |param|
      output[:params] << "%#{param} < #{params[param.to_s]} >"
    end    

    flat_relations.each do |param, relation|
      entries = params[param.to_s].map {|items| items.join " "}
      output[:params] << "%#{param.to_s} set[#{relation.sets.length}] <\n  #{entries.join("\n  ")}\n>"
    end
    
    flat_vectors.each do |param, vector|
      entries = params[param.to_s].map {|items| items.join " "}
      output[:params] << "%#{param.to_s}[#{vector.sets.join(',')}] indices <\n  #{entries.join("\n  ")}\n>"
    end    
    
    sets.each do |set|
      if schema[set].is_a? Hash
        output[:sets] << "%#{set} set < #{params[set.to_s].keys.join(' ')} >"
        schema[set].each do |param, type|
          if type == Numeric
            # raise "Parameter #{param} for #{set} not found!" unless @params[set.to_s][param.to_s]
            output[:params] << "%#{param}[#{set}] < #{params[set.to_s].map{|k,v| v.fetch(param.to_s, Float::NAN)}.join(' ')} >"
          elsif type.is_a? Tuple
            entries = params[set.to_s].map{|k,v| 
              v.fetch(param.to_s, []).map { |item|
                [k, item].join(" ")
              }
            }
            output[:params] << "%#{set}_#{param} set[#{type.sets.length + 1}] <\n  #{entries.join("\n  ")}\n>"
          else
            raise "Bad data!"
          end
        end
      elsif schema[set] == Range
        output[:sets] << "%#{set} set < #{params[set.to_s].min}..#{params[set.to_s].max} >"
      elsif schema[set] == Set
        output[:sets] << "%#{set} set < #{params[set.to_s].join(' ')} >"
      end
    end
    
    
    [output[:sets] + output[:params]].join("\n").strip
  end
end
