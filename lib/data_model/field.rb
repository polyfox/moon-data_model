require 'data_model/type'
require 'data_model/validators'

module Moon
  module DataModel
    # Object for storing information about a Field on a model
    class Field
      # @return [Symbol] name of the field
      attr_reader :name

      # @return [Array, Hash, Class] type
      attr_reader :type

      # @return [Proc, Object] default
      attr_reader :default

      # @return [Boolean] allow_nil  are nils allowed for the value?
      attr_reader :allow_nil

      # @return [Boolean] coerce_values  should the field coerce its values?
      attr_reader :coerce_values

      # @return [Boolean] is_key  Is this a key field (such as an id)?
      attr_reader :is_key

      # @return [Array<Validator::Base<>>]
      attr_reader :validators

      # @param [Hash<Symbol, Object>] options
      # @option options [Symbol] :name
      #   Name of the field
      # @option options [Object] :type
      #   An object that can be transformed into a DataModel::Type
      # @option options [Boolean] :allow_nil
      #   Does this field allow nil values?
      # @option options [Boolean] :coerce_values
      #   Coerce values, may cause undesirable behaviour with certain types.
      # @option options [Boolean] :is_key
      #   Mark this field as the `key` field
      # @option options [Hash<Symbol, Object>] :validate
      #   Validation parameters, keys are the name of the validator
      #   and their values are the parameters for that validator.
      def initialize(options)
        @name          = options.fetch(:name)
        initialize_type(options.fetch(:type))
        @default       = options.fetch(:default) { ->(_, _) { nil } }
        @allow_nil     = options.fetch(:allow_nil, false)
        @coerce_values = options.fetch(:coerce_values, false)
        @is_key        = options.fetch(:is_key, false)
        initialize_validators(options.fetch(:validate) { {} })
      end

      # Finalizes the type, this will replace the current {Field#type} with the
      # finalized version. see also {Type#finalize}
      #
      # @return [void]
      def finalize
        @type = @type.finalize
      end

      # @param [Object] type
      # @return [void]
      #
      # @api private
      def initialize_type(type)
        @type = Moon::DataModel::Type[type]
      end

      # Creates validators from the given options, also appends a
      # Validators::Type if none is given.
      #
      # @param [Hash<Symbol, Object>] options
      # @return [void]
      #
      # @api private
      def initialize_validators(options)
        @validators = []

        options.each_pair do |key, opts|
          @validators << Validators.fetch(key).new(opts)
        end

        # if the @validators already includes a Type validator, just skip this.
        unless options.find { |v| v.is_a?(Validators::Type) }
          k = Validators.fetch(:type)
          type_validator = k.new(type: @type, allow_nil: @allow_nil,
                                 ctx: { key: @name })
          @validators = [type_validator].concat(@validators)
        end
      end

      # Attempts to convert the provided value to the Field's type
      #
      # @param [Object] value
      # @return [Object] coerced value, may return the value given.
      #
      # @api public
      def coerce(value)
        return value unless @coerce_values
        @type.coerce(value)
      end

      # Returns the default value for the field, a model must be provided
      # if the default is a Proc and not a value.
      #
      # @return [Object]
      #
      # @api public
      def make_default(model = nil)
        @default.call(@type, model)
      end

      # Checks that the given value is valid for the field.
      #
      # @param [Object] value
      # @return [Boolean]
      def valid?(value)
        @validators.all? do |validator|
          validator.valid?(value)
        end
      end

      # Invokes each validator on the provided value, if the value
      # fails validation, the Validator +may+ raise an error.
      #
      # @param [Object] value
      # @return [void]
      #
      # @api public
      def validate(value, quiet = false)
        @validators.each do |validator|
          validator.validate(value)
        end
      end

      # Generic field `default` proc.
      # The best way to use this is to use it as a general field_setting
      #
      # @return [Proc]
      #
      # @example
      #   # as a single line
      #   field :my_model, type: MyModel, default: Moon::DataModel::Field.default_proc
      #   # as a field_setting, all fields inside the block will get the default
      #   field_settings default: Moon::DataModel::Field.default_proc do
      #     field :id, type: String
      #     field :a, type: Integer
      #     field :a_model, type: AModel
      #   end
      def self.default_proc
        lambda do |type, _|
          # Integer, Numeric and Float cannot be created using .new
          if type.model == Integer then 0
          elsif type.model == Numeric then 0
          elsif type.model == Float then 0.0
          else
            type.model.new
          end
        end
      end

      alias :is_key? :is_key
      alias :allow_nil? :allow_nil
    end
  end
end
