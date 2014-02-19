require 'nori'
require 'tempfile'
require 'benchmark'

class Problem
  Solution = Struct.new(:objective, :vars, :cmpl_exit_code, :solver_output, :optimization_time) do
    def method_missing(m, *args, &block) 
      self.vars[m.to_s]
    end
  end
  Objective = Struct.new(:name, :value, :status)
  
  class VarHash < Hash
    def[](*args)      
      fetch(args.map(&:to_s))
    rescue KeyError
      puts "getting variable of unknown index #{args.inspect}, falling back with zero"
      0
    end
  end
  
  @@nori = Nori.new(convert_tags_to: ->(tag){ tag.snakecase.to_sym })
  
  attr_accessor :params
  
  def initialize(schema, model_file:'workflow.cmpl', cmpl_opts: ['-s'], debug: false)
    @model_file = model_file
    @cmpl_opts = cmpl_opts
    @schema = schema
    @params = {}
    @debug = debug

    DataGenerator.validate_schema(@schema)
  end
  
  def generate_data
    DataGenerator.generate_data(@schema, @params)
  end
  
  def Problem.parse_results(xml)
    hash = @@nori.parse(xml)
    data = hash[:cmpl_solutions]
    vars = nil
    objective = nil
    
    if data[:solution]
      vars = Hash.new {|h,k| h[k] = VarHash.new { } } 
    
      data[:solution][:variables][:variable].map do |var|
        name_parts = var[:@name].match /^(?<name>[a-zA-Z_][a-zA-Z0-9_]*)(?:\[(?<indexes>.*?)\])?$/
        name = name_parts[:name].snakecase
        value = case var[:@type]
          when "B", "I"
            var[:@activity].to_f.round.to_i
          when "C"
            var[:@activity].to_f
          else
            var[:@activity]
        end
      
        if name_parts[:indexes].nil?
          vars[name] = value
        else
          indexes = name_parts[:indexes].split(',')
          vars[name][indexes] = value
        end      
      end 
      objective = Objective.new(data[:general][:objective_name].to_s, data[:solution][:@value].to_f, data[:solution][:@status])
    else
      objective = Objective.new(data[:general][:objective_name].to_s, nil, data[:general][:solver_msg].to_s)
    end
    
    [objective, vars]
  end

  def run!
    data = self.generate_data        
        
    Dir.mkdir('tmp') unless Dir.exist?('tmp/')
    tmpfile = unless @debug
        'tmp/' + Dir::Tmpname.make_tmpname(['cmpl_',''], nil)
      else
        "tmp/test"
      end
    solution_file = tmpfile + ".sol"
    data_file = tmpfile + ".cdat"

    warn "Writing data to #{data_file}..."
    IO.write(data_file, data)

    args = ['cmpl', @model_file, '-solution', solution_file, '-data', data_file]
    args += @cmpl_opts

    cmpl_output = ""
    warn "Starting CMPL..."
    exec_time = Benchmark::measure do 
      process = IO.popen(args, "r", err: [:child, :out]) do |cmpl|
        while !cmpl.eof?
          data = cmpl.read(1)
          cmpl_output += data
          $stderr.print data
        end
      end
    end
    exit_code = $?
    solution_xml = IO.read(solution_file)
    
    unless @debug
      File.unlink(solution_file)
      File.unlink(data_file)
    else
      warn cmpl_output
    end

    warn "Optimization complete"
    
    objective, vars = Problem.parse_results(solution_xml)
    Solution.new(objective, vars, exit_code, cmpl_output, exec_time)
  end
  
  def generate_offline_problem(dir)
    Dir.mkdir(dir) unless Dir.exist?(dir)
    
    data = self.generate_data
    IO.write(dir + "/data.cdat", data)
    File.open(dir + "/run.sh", 'w', 755) do |script|
      script.puts "#!/bin/sh"

      args = ['cmpl', @model_file, '-solution', dir + "/solution.xml", '-data', dir + "/data.cdat", '-alias', dir+'/cmpltemp']
      args += @cmpl_opts      
      script.puts Shellwords.shelljoin(args) + " 2>&1 > #{dir}/out.txt"
      
      script.puts "exit_code = $?"
      script.puts "echo $exit_code > #{dir}/exit_code.txt"
      script.puts "exit $exit_code"      
    end
    IO.write(dir + "/data.yml", YAML.dump(@params))
  end

end