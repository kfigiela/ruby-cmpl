require_relative 'spec_helper.rb'
require_relative '../lib/cmpl.rb'

describe DataGenerator do
  it "should translate array sets" do
    schema = {setA: DataGenerator::Set}
    params = {"setA" => [:a, :b, :c]}
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < a b c >
    EOF
  end

  it "should translate hash sets" do
    schema = {setA: {}}
    params = {"setA" => {"a" => {}, "b" => {}, "c" => {}}}
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < a b c >
    EOF
  end

  it "should translate range sets" do
    schema = {setA: Range}
    params = {"setA" => 1..10}
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < 1..10 >
    EOF
  end
  
  it "should translate top level params" do
    schema = {paramA: Numeric}
    params = {"paramA" => 5}
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %paramA < 5 >
    EOF
  end

  it "should translate sets with params" do
    schema = {setA: {paramA: Numeric}}
    params = {"setA" => {"a" => {"paramA" => "4"}, "b" => {"paramA" => 1}, "c" => {"paramA" => 9}}}

    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < a b c >\n%paramA[setA] < 4 1 9 >
    EOF
  end

  it "should translate nested tuples" do
    schema = {setA: {relationAB: DataGenerator::Tuple.new([:setB])}, setB: DataGenerator::Set}
    params = {
        "setA" => {
            "a" => {"relationAB" => ['x', 'y']},
            "b" => {"relationAB" => ['z', 'y']},
            "c" => {"relationAB" => ['z']},
        },
        "setB" => ['x', 'y', 'z']
      }
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < a b c >
      %setB set < x y z >
      %setA_relationAB set[2] <
        a x
        a y
        b z
        b y
        c z
      >
    EOF
  end

  it "should translate top level tuples" do
    schema = {setA: DataGenerator::Set, setB: DataGenerator::Set, relationAB: DataGenerator::Tuple.new([:setA, :setB])}
    params = {
        "setA" => ['a', 'b', 'c'],
        "setB" => ['x', 'y', 'z'],
        "relationAB" => [
          ['a', 'x'],
          ['a', 'y'],
          ['b', 'z'],
          ['b', 'y'],
          ['c', 'z']
        ]
      }
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < a b c >
      %setB set < x y z >
      %relationAB set[2] <
        a x
        a y
        b z
        b y
        c z
      >
    EOF
  end
  
  it "should translate top level vector params" do
    schema = {setA: DataGenerator::Set, setB: DataGenerator::Set, paramAB: DataGenerator::Vector.new([:setA, :setB])}
    params = {
        "setA" => ['a', 'b'],
        "setB" => ['x', 'y'],
        "paramAB" => [
          ['a', 'x', 1],
          ['a', 'y', 2],
          ['b', 'x', 3],
          ['b', 'y', 4]
        ]
      }
    DataGenerator.generate_data(schema, params).should eql <<-EOF.unindent.strip
      %setA set < a b >
      %setB set < x y >
      %paramAB[setA,setB] indices <
        a x 1
        a y 2
        b x 3
        b y 4
      >
    EOF
  end
end