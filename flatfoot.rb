%w{ rubygems set yaml activesupport }.each do |g|
  require g
end

class String
  def self.random_string(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    str = ""
    1.upto(len) { |i| str << chars[rand(chars.size-1)] }
    return str
  end
end

class Flatfoot

  attr_accessor :new_record, :attributes_set

  def attributes_set
    if @attributes_set.nil?
      a = ["created_at", "updated_at", "fn"]
      @attributes_set = Set.new(a)
    end
    @attributes_set
  end

  # test, defaults = {},
  def self.attributes *args
    args.each do |arg|
      class_eval %{
        attr_accessor :#{arg}

        def #{arg}= value
          attributes_set << "#{arg.to_s}" #TODO:refactor
          @#{arg} = value
        end
      }
    end
  end

  attributes :created_at, :updated_at, :fn

  def attributes
    ret = {}
    return ret if attributes_set.nil? || attributes_set.empty?
    attributes_set.each do |a|
      ret[a] = send(a.to_s)
    end
    ret
  end

  SKIP_NAMES = %w{ . .. }

  def self.datafiles
    Dir.entries(datadir).reject{|x| SKIP_NAMES.include? x}
  rescue
    []
  end

  DATADIR = "data"

  def self.sitedir
    @@sitedir ||= Dir.pwd
  end

  def self.datadir
    datadir = File.join(sitedir, DATADIR, self.to_s.underscore)
    FileUtils.mkdir(datadir) unless File.directory?(datadir)
    datadir
  end

  def datadir; self.class.datadir; end

  def self.from_fn(fn)
    return nil unless fn
    self.from_file(File.join(datadir, fn.to_s))
  end

  def self.from_file(f)
    b = {}
    YAML.load(File.read(f)).each{|k,v| b[k.to_sym] = v }
    self.new(b)
  end

  def file_location
    File.join(datadir, fn)
  end

  def generate_fn
    # Digest::SHA1.hexdigest(self.class.to_s + @created_at.to_s)
    # String::random_string(40)
    String::random_string(6)
  end

  def new_record?; @new_record == true end

  def initialize(params = {})
    params ||= {}
    params.each do |k,v|
      send("#{k}=", v)
    end

    @created_at = params[:created_at] if params[:created_at]
    @created_at ||= Time.now.utc

    if params[:fn]
      @fn = params[:fn]
      @new_record = false
    else
      @fn = generate_fn
      @new_record = true
    end
  end

  def self.create(params = {})
    object = self.new(params)
    object.save
  end

  def send_callback(name)
    self.send(name)
    callbacks[name].each do |m|
      self.send(m)
    end
  end

  def save
    @updated_at = Time.now.utc
    
    send_callback(:before_save)
    send_callback(:before_create) if new_record?
    status = serialize
    send_callback(:after_create) if new_record?
    send_callback(:after_save)

    @new_record = false
    status
  end

  def serialize
    File.open(file_location, 'w') {|f| f.write attributes.to_yaml }
  end

  # http://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html
  # def validate
  #   before_validation
  #   before_validation_on_create if new_record?
  #   after_validation
  #   after_validation_on_create if new_record?
  # end

  def before_create; end
  def before_save; end
  def after_create; end
  def after_save; end

### SELECTORS

  def self.first
    created_first
  end

  def self.all
    datafiles.map{|x| self.from_fn(x)}.sort{|x,y| x.created_at <=> y.created_at }
  end

  def self.find(fn)
    self.from_fn(fn)
  end

### RELATIONAL STUFF

  def self.belongs_to klass, options = {}
    klass = klass.to_s
    class_eval %{
      attributes :#{klass}_fn

      def #{klass}
        @#{klass} ||= #{klass.classify}.from_fn(#{klass}_fn)
      end

      def #{klass}= #{klass}
        self.#{klass}_fn = #{klass}.fn
      end
    }

    if options[:polymorphic] == true
       class_eval %{
        attributes :#{klass}_type

        # TODO, remove eval
        def #{klass}
          @#{klass} = eval("\#{#{klass}_type}.from_fn(#{klass}_fn)")
        end

        def #{klass}= #{klass}
          self.#{klass}_fn = #{klass}.fn
          self.#{klass}_type = #{klass}.class.to_s
        end
      }
    end
  end

  def self.has_many klass, options = {}
    klass = klass.to_s
    singular = klass.to_s.singularize
    key = self.to_s.foreign_key.gsub('_id', '_fn')
    class_eval %{
      def #{singular}_fns
        self.#{klass}.map(&:fn)
      end

      def #{klass}
        @#{klass} ||= #{klass.classify}.all.select{|x| x.#{key} == self.fn }
      end

      # def after_save
      #   #{klass}.each{|x| x.#{key} = self.fn; x.save }
      # end
    }
  end

  def self.has_one klass, options = {}
    klass = klass.to_s
    singular = klass.to_s.singularize
    key = self.to_s.foreign_key.gsub('_id', '_fn')
    class_eval %{
      def #{singular}_fn
        return #{klass}.fn if @#{klass}
        nil
      end

      def #{klass}
        @#{klass} ||= #{klass.classify}.all.select{|x| x.#{key} == x.fn }
        @#{klass} = nil if @#{klass} == []
      end

      def #{klass}= #{klass}
        @#{klass} = #{klass}
      end
    }
  end

### Callbacks

  def self.initialize_callback(name)
    self.instance_eval %{
      @callbacks ||= {}
      @callbacks[:#{name}] ||= []
    }
  end

  def self.callbacks
    initialize_callback(:before_save)
    initialize_callback(:before_create)
    initialize_callback(:after_create)
    initialize_callback(:after_save)
    self.instance_eval('@callbacks')
  end

  def callbacks; self.class.callbacks; end

  def self.before_save(method, &block)
    self.initialize_callback(:before_save)
    self.instance_eval("@callbacks[:before_save] << \"#{method}\"")
    define_method(method, block) if block_given?
  end

  def self.before_create(method, &block)
    self.initialize_callback(:before_create)
    self.instance_eval("@callbacks[:before_create] << \"#{method}\"")
    define_method(method, block) if block_given?
  end

  def self.after_save(method, &block)
    self.initialize_callback(:after_save)
    self.instance_eval("@callbacks[:after_save] << \"#{method}\"")
    define_method(method, block) if block_given?
  end

  def self.after_create(method, &block)
    self.initialize_callback(:after_create)
    self.instance_eval("@callbacks[:after_create] << \"#{method}\"")
    define_method(method, block) if block_given?
  end

end

