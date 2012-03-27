require 'dalli'
require 'json'

module ActiveStore
  class Connection
    attr_accessor :connection_string, :namespace, :default_ttl

    def initialize(connection_string, namespace, default_ttl)
      @connection_string = connection_string
      @namespace = namespace
      @default_ttl = default_ttl
    end

    class ::Dalli::Client
      # Monkey patch to avoid having a separate branch
      def validate_key (key)
        raise ArgumentError, "key cannot be blank" if key.nil? || key.strip.size == 0
        raise ArgumentError, "key too long #{key.inspect}" if key.length > 250
      end
    end

    attr_writer :store

    def flush_all
      store.flush_all
    end

    def incr(*args)
      store.incr(*args)
    end

    def delete(*args)
      store.delete(*args)
    end

    def get (key)
      load(get_raw(key))
    end

    def set (key, value, ttl=default_ttl)
      set_raw(key, dump(value), ttl)
    end

    def add (key, value, ttl=default_ttl)
      add_raw(key, dump(value), ttl)
    end

    def cas (key, ttl=default_ttl)
      store.cas(key, ttl, :raw => true) do |value|
        raw_output = yield load(value)
        dump(raw_output)
      end
    end

    def get_raw(key)
      store.get(key)
    end

    def set_raw(key, value, ttl=default_ttl)
      store.set(key, value, ttl, :raw => true)
    end

    def add_raw(key, value, ttl=default_ttl)
      store.add(key, value, ttl, :raw => true)
    end

    def store
      unless @store
        @store = Dalli::Client.new(connection_string, :namespace => namespace, :expires_in => default_ttl, :socket_timeout => 1)
        begin
          @store.get('test')
        rescue Dalli::RingError => e
          @store = nil
          raise e
        end
      end
      @store
    end

    private

    # Ugly tricks to fool parsers that don't allow literals
    def dump (value)
      JSON.dump([value])[1...-1]
    end

    def load (value)
      JSON.load("[#{value}]").first
    end
  end
end
