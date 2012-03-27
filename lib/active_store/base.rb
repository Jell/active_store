module ActiveStore
  class Base

    def initialize(params = {})
      set_attributes(params)
      @created_at ||= Time.now
    end

    def ==(another_object)
      (self.class.attributes - ["created_at"]).all? do |attribute|
        self.send(attribute) == another_object.send(attribute)
      end
    end

    def attributes
      self.class.attributes.inject({}) do |accu, attribute|
        send(attribute).nil? ? accu : accu.merge({attribute => send(attribute)})
      end
    end

    def set_attributes(params = {})
      params = Hash[ params.map {|key, value| [key.to_s, value]} ]
      self.class.attributes.each do |attribute|
        write_attribute(attribute, params[attribute])
      end
    end

    def update_attribute(attribute, value)
      self.send "#{attribute}=", value
      save
    end

    def update_attributes(params)
      params.each do |key, value|
        send("#{key}=", value)
      end
      save
    end

    def reload
      raise NoIdError.new("Could not reload without id.") if (id.nil? || id.empty?)
      set_attributes(connection.get(id))
      self
    end

    def save(ttl = self.class.default_ttl)
      return false if (id.nil? || id.empty?)
      connection.set(id, self.attributes, ttl)
      true
    end

    def save!(ttl = self.class.default_ttl)
      save(ttl) or raise NoIdError.new("Could not save without id.")
    end

    def connection
      self.class.connection
    end

    protected

    def write_attribute (attribute, value)
      instance_variable_set("@#{attribute}", value)
    end

    def read_attribute (attribute)
      instance_variable_get("@#{attribute}")
    end

    class << self
      attr_reader :attributes

      def define_attributes(*args)
        @attributes ||= []
        @attributes += args.map(&:to_s)
        @attributes |= ["id", "created_at"]
        attr_accessor *@attributes
      end

      def create(params = {})
        obj = new(params)
        obj.save!
        obj
      end

      # Allows you to update an ActiveStore object within a
      # CAS "transaction"
      #
      # Example:
      #   Model.cas_update(3) do |instance|
      #     instance.value += 5
      #   end
      #
      # Returns nil if the object could not be found.
      # Returns false if the CAS operation failed due to
      # the object being modified in the background.
      def cas_update(id, ttl = default_ttl, &block)
        block = attributes_block_wrapper(&block)
        connection.cas(id, ttl, &block)
      end

      # Like cas_update, but also creates a new object if none could be
      # found. The given block is guaranteed to be executed at most once.
      #
      # Example:
      #   Model.cas_update_or_create(3) do |instance|
      #     instance.value ||= 0
      #     instance.value += 5
      #   end
      #
      # Returns false if the CAS operation failed due to
      # the object having been modified by another process, or if
      # someone managed to create an object between the CAS and ADD
      # operations
      def cas_update_or_create(id, ttl = default_ttl, &block)
        res = cas_update(id, ttl, &block)
        res.nil? ? create_with_block(id, ttl, &block) : res
      end

      def stm_update_or_create (id, ttl = default_ttl, &block)
        begin
          success = cas_update_or_create(id, ttl = default_ttl, &block)
        end until success
        true
      end

      def create_with_block(id, ttl = default_ttl, &block)
        block = attributes_block_wrapper(&block)
        connection.add(id, block.call({"id" => id}), ttl)
      end

      def find(id)
        return nil if (id.nil? || id.empty?)
        params = connection.get(id)
        params ? new(params) : nil
      end

      def find_or_initialize_by_id(id)
        find(id) || new(:id => id)
      end

      def connection
        @connection ||= Connection.new(connection_string, namespace, default_ttl)
      end

      def connection_string= (connection_string)
        @connection = nil
        @connection_string = connection_string
      end

      def connection_string
        @connection_string ||= (superclass.connection_string unless self == Base)
      end

      def namespace= (namespace)
        @connection = nil
        @namespace = namespace
      end

      def namespace
        @namespace ||= self.name
      end

      def default_ttl= (default_ttl)
        @connection = nil
        @default_ttl = default_ttl
      end

      def default_ttl
        @default_ttl ||= 30 * 24 * 3600
      end

      private
      def attributes_block_wrapper(&block)
        lambda do |attrs|
          instance = new(attrs)
          block.call(instance)
          instance.attributes
        end
      end
    end

    class NoIdError < StandardError
    end
  end
end
