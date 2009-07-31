require 'rubygems'
require 'ruby-debug'
require 'spec'
require 'flatfoot'

class ResponseTester
  def self.respond_test(klass, method_name)
    describe "#{klass.class.to_s}" do
      it "should respond to #{method_name}" do
        klass.respond_to?(method_name).should == true
      end
    end
  end
end

### Default params

describe Flatfoot, "class" do

  it "should initialize" do
    f = Flatfoot.new
    f.class.to_s.should == "Flatfoot"
  end

  it "should get Dir.pwd" do
    Dir.should_receive(:pwd).and_return "here"
    Flatfoot.sitedir.should == "here"
  end

  it "should have a DATADIR" do
    Flatfoot::DATADIR.should == "data"
  end

  ResponseTester.respond_test(Flatfoot.new, :new_record)
  ResponseTester.respond_test(Flatfoot.new, "new_record=")

  ResponseTester.respond_test(Flatfoot.new, :created_at)
  ResponseTester.respond_test(Flatfoot.new, :updated_at)
  ResponseTester.respond_test(Flatfoot.new, :fn)
  ResponseTester.respond_test(Flatfoot.new, "created_at=")
  ResponseTester.respond_test(Flatfoot.new, "updated_at=")
  ResponseTester.respond_test(Flatfoot.new, "fn=")

  it "should respond to core attributes" do
    @f = Flatfoot.new
    @f.created_at = Time.now
    @f.updated_at = Time.now
    @f.fn = "fn"
    @f.attributes_set.include?("created_at").should == true
    @f.attributes_set.include?("updated_at").should == true
    @f.attributes_set.include?("fn").should == true
  end

  it "should respond to core attributes immediatly" do
    @f = Flatfoot.new
    @f.attributes_set.include?("created_at").should == true
    @f.attributes_set.include?("updated_at").should == true
    @f.attributes_set.include?("fn").should == true
  end

end

### Extends

class FlatFooted < Flatfoot
end

class User < Flatfoot
end

describe FlatFooted, "class" do

  before(:each) do
    Dir.stub!(:pwd).and_return "here"
    Dir.stub!(:mkdir).and_return true
    Dir.stub!(:directory?).and_return true
    @f = FlatFooted.new
    @data_dir = "here/data/flat_footed"
  end

  it "should initialize" do
    @f.class.to_s.should == "FlatFooted"
  end

  it "should have a datadir" do
    FlatFooted.respond_to?(:datadir).should == true
  end

  it "should have a datadir" do
    FlatFooted.datadir.should == @data_dir
  end

  it "should have a datadir" do
    User.datadir.should == "here/data/user"
  end

  it "should check to see if directory exists" do
    File.should_receive(:directory?).once
    FlatFooted.datadir
  end

  it "should create the directory if not exists" do
    File.stub!(:directory?).and_return(false)
    FileUtils.should_receive(:mkdir).once.with(@data_dir)
    FlatFooted.datadir
  end

  it "should return same as datadir" do
    @f.datadir.should == @data_dir
  end

  DATAFILES = [".", "..", "one", "two"]

  it "should glob for files" do
    Dir.should_receive(:entries).with(@data_dir).and_return(DATAFILES)
    FlatFooted.datafiles
  end

  it "should get files and return good ones" do
    Dir.stub!(:entries).and_return(DATAFILES)
    FlatFooted.datafiles.sort.should == ["one", "two"]
  end

  ResponseTester.respond_test(FlatFooted.new, :generate_fn)
  ResponseTester.respond_test(FlatFooted.new, :fn)
  ResponseTester.respond_test(FlatFooted.new, :file_location)
  ResponseTester.respond_test(FlatFooted, :from_file)

  it "should initilize from file" do
    File.stub!(:read).and_return("YAML")
    YAML.stub!(:load).with("YAML").and_return({:hey => "yes"})
    FlatFooted.should_receive(:new).with({:hey => "yes"})
    FlatFooted.from_file("fn")
  end

  ResponseTester.respond_test(FlatFooted, :from_fn)

  it "should use from file to deserialize" do
    FlatFooted.should_receive(:from_file).once
    FlatFooted.from_fn("fn")
  end

  ResponseTester.respond_test(FlatFooted.new, :before_create)
  ResponseTester.respond_test(FlatFooted.new, :before_save)
  ResponseTester.respond_test(FlatFooted.new, :after_create)
  ResponseTester.respond_test(FlatFooted.new, :after_save)
  ResponseTester.respond_test(FlatFooted.new, "new_record?")

  ResponseTester.respond_test(FlatFooted, "attributes")


  it "should return an object" do
    class FlatFooted
      attributes :title

      def serialize
        true
      end
    end

    FlatFooted.create(:title => "title").instance_of?(FlatFooted).should == true
  end

  it "should accept attributes" do
    class FlatFooted < Flatfoot
      attributes :title
    end

    @f = FlatFooted.new
    @f.respond_to?(:title).should == true
    @f.respond_to?("title=").should == true
  end

  it "should respond to attributes" do
    class FlatFooted < Flatfoot
      attributes :title
    end

    @f = FlatFooted.new
    @f.respond_to?(:attributes).should == true

    @f.title = "title"
    @f.attributes_set.include?("title").should == true

    @f.attributes["title"].should == "title"
  end

  it "should respond to core attributes immediatly" do
    @f = FlatFooted.new
    @f.attributes_set.include?("created_at").should == true
    @f.attributes_set.include?("updated_at").should == true
    @f.attributes_set.include?("fn").should == true
  end

  it "should respond to non core attributes immediatly" do
    @f = FlatFooted.new
    @f.attributes_set.include?("title").should == true
  end

  it "should accept params" do
    @f = FlatFooted.new(:title => "TITLE")
    @f.title.should == "TITLE"
  end

  it "should have created_at" do
    @f = FlatFooted.new
    @f.created_at.should_not be_nil
  end

  it "should save if empty" do
    @f = FlatFooted.new
    File.stub!(:open).with("here/data/flat_footed/#{@f.fn}", 'w').and_return 545
    @f.save.should_not == false
  end

  it "should create a new fn" do
    @f = FlatFooted.new(:fn => "FILENAME4")
    @f.fn.should == "FILENAME4"
  end

  it "should create a new fn" do
    class FlatFooted
      def generate_fn
        "FILANE"
      end
    end
    @f = FlatFooted.new
    @f.fn.should == "FILANE"
  end

  it "should accept nil for params" do
    @f = FlatFooted.new(nil)
  end

  it "should accept params" do
    class FlatFooted
      attributes :shrimps
    end
    @f = FlatFooted.new(:shrimps => "woah")
    @f.shrimps.should == "woah"
  end

end

### Attributes

class Seal < Flatfoot
  attributes :name
end

describe Seal, "with name attribute" do

  it "should have a name" do
    Seal.new.respond_to?("name").should == true
  end

  it "should accept a name" do
    @seal = Seal.new
    @seal.respond_to?("name=").should == true
  end

end

class Photo < Flatfoot
  attributes :content_type, :original_filename#, :another_attr

  def photo= attrib
    @content_type = attrib.content_type
    self.original_filename = attrib.original_filename
    # another_attr = attrib.another_attr
  end

end

class Attributes
  def content_type
    "content_type"
  end

  def original_filename
    "original_filename"
  end

  # def another_attr
  #   "another_attr"
  # end
end

describe Seal, "with name attribute" do

  it "should have a name" do
    p = Photo.new
    p.attributes_set.include?("content_type").should == true
    p.attributes_set.include?("original_filename").should == true
    p.photo = Attributes.new
    p.attributes_set.include?("content_type").should == true
    p.attributes_set.include?("original_filename").should == true
    p.attributes["content_type"].should == "content_type"
    p.attributes["original_filename"].should == "original_filename"
    # p.attributes["another_attr"].should == "another_attr"
    p.content_type.should == "content_type"
    p.original_filename.should == "original_filename"
    # p.another_attr.should == "another_attr"
  end

end

### Associations

class Car < Flatfoot
  has_many :wheels
  has_one :horn
end

class Horn < Flatfoot
  belongs_to :car
end

class Wheel < Flatfoot
  belongs_to :car
end

describe Car, "associations" do

  before do
    @car = Car.new
  end

  it "should have accessors for fn" do
    @car.respond_to?("wheel_fns").should == true
    @car.wheel_fns.should == []
    @car.wheels.should == []
    @car.respond_to?("horn_fn").should == true
    @car.horn_fn.should == nil
    @car.horn.should == nil
  end

  it "should get car_fn if it has a belongs_to" do
    @horn = Horn.new
    @car.stub!(:fn).and_return "car-filename"
    @horn.respond_to?(:car_fn).should == true
    @horn.respond_to?(:car_fn=).should == true
    @horn.respond_to?(:car).should == true
    @horn.respond_to?(:car=).should == true
    @horn.should_receive(:car_fn=).with("car-filename")
    @horn.car = @car
  end

end

### Callbacks

class Car < Flatfoot
  before_save :wilma do
    "wowo"
  end

  before_save :print_nono

  def print_nono
    "nonon"
  end
end

describe Car, "can" do

  it "create a callback" do
    %w{ before_save before_create after_create after_save }.each do |m|
      Car.respond_to?(m).should == true
    end
  end

  it "should allow you to declare a save as a block" do
    @car = Car.new
    @car.stub!(:serialize)
    @car.should_receive(:print_nono)
    @car.should_receive(:wilma)
    @car.save
  end

  it "should call callback function" do
    @car = Car.new
    @car.stub!(:serialize)
    @car.should_receive(:before_save)
    @car.should_receive(:after_save)
    @car.should_receive(:before_create)
    @car.should_receive(:after_create)
    @car.save
  end

  it "should call callback function" do
    @car = Car.new
    @car.stub!(:serialize)
    @car.new_record = false
    @car.should_receive(:before_save)
    @car.should_receive(:after_save)
    @car.should_not_receive(:before_create)
    @car.should_not_receive(:after_create)
    @car.save
  end

end



