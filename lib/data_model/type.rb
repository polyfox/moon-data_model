require 'data_model/err'

module Moon
  module DataModel
    # Class for representing Object types
    class Type
      @@types = {}

      # Class representing the Type
      # @!attribute [r] model
      #   @return [Module] the main class of the type
      attr_reader :model

      # Object representing the model's content, if any.
      # @!attribute [r] content
      #   @return [Hash, Array, nil] depending on the model
      attr_reader :content

      # @param [Module] model
      # @param [Object] content
      # @param [Hash] options
      # @option options [Boolean] :array
      # @option options [Boolean] :hash
      # @option options [Boolean] :incomplete
      # @api private
      def initialize(model, content = nil, options = {})
        @model = model
        @content = content.presence
        @array = options.fetch(:array, false)
        @hash = options.fetch(:hash, false)
        @incomplete = options.fetch(:incomplete, false)
      end

      # Attempts to complete the Type, returns self if the type is already
      # complete, else returns a new Type.
      #
      # @return [Type, self]
      def finalize
        if @incomplete
          new_model = Object.const_get(@model)
          return Type[new_model]
        end
        self
      end

      # Checks if the Type has been completed, if not raises an IncompleteType
      # error.
      # @api private
      def check_complete
        raise IncompleteType, "incomplete type #{@model}" if @incomplete
      end

      # Is this Type an Array?
      #
      # @return [Boolean]
      def array?
        @array
      end

      # Is this Type a Hash/Map/Dict?
      #
      # @return [Boolean]
      def hash?
        @hash
      end

      # Is this Type incomplete?
      #
      # @return [Boolean]
      def incomplete?
        @incomplete
      end

      # @param [Object] obj
      # @return [Array, nil]
      private def coerce_array(obj)
        return nil if obj.nil?
        if @content
          # TODO, maybe enforce one content type?
          klass = @content.first
          t = Type[klass]
          obj.map { |o| t.coerce(o) }
        else
          return obj if obj.is_a?(Array)
          Array[obj]
        end
      end

      # @param [Object] obj
      # @return [Hash, nil]
      private def coerce_hash(obj)
        return nil if obj.nil?
        if @content
          # TODO, maybe enforce one content type?
          k, v = *@content.first
          k, v = Type[k], Type[v]
          obj.each_with_object({}) do |p, r|
            pk = k.coerce(p[0])
            pv = v.coerce(p[1])
            r[pk] = pv
          end
        else
          return obj if obj.is_a?(Hash)
          Hash[obj]
        end
      end

      # Attempts to convert the given object to the Type's model and content
      #
      # @param [Object] obj
      # @return [Object]
      def coerce(obj)
        check_complete
        # Does the type define its own coerce method?
        if @model.respond_to?(:coerce)
          @model.coerce(obj)
        # is the type an Array
        elsif @array
          coerce_array(obj)
        # is the type a Hash
        elsif @hash
          coerce_hash(obj)
        else
          obj
        end
      end

      # @return [Hash<Object, Type>]
      def self.types
        @@types
      end

      def self.make_type_for(type)
        case type
        when Array
          new Array, type, array: true
        when Hash
          new Hash, type, hash: true
        when Module
          if type == Array
            new type, nil, array: true
          elsif type == Hash
            new type, nil, hash: true
          else
            new type
          end
        else
          raise InvalidModelType, "cannot create Type from #{type}"
        end
      end

      # Returns a complete Type from the given params
      #
      # @param [Object] type  an object that can be converted to a Type
      # @return [Type]
      def self.get_complete_type(type)
        types[type] ||= make_type_for(type)
      end

      # Returns a incomplete or complete Type based on the given parameters
      #
      # (see #get_complete_type)
      def self.[](type)
        if type.is_a?(String)
          # incomplete types are never cached
          new type, nil, incomplete: true
        else
          get_complete_type(type)
        end
      end
    end
  end
end
