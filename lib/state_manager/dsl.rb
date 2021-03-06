require 'active_support/all'

module StateManager
  module DSL

    module State
      # Specifies a state that is a child of the current state
      def state(name, klass=nil, &block)
        # If no base class is specified we look for a class inside the current
        # state's class which has the same name as the state
        const_name = name.to_s.classify
        klass ||= if const_defined?(const_name, false)
          self.const_get(const_name)
        else
          Class.new(StateManager::State)
        end
        klass = Class.new(klass, &block) if block_given?

        remove_const const_name if const_defined?(const_name, false)
        const_set(const_name, klass)

        specification.states[name.to_sym] = klass
      end

      # Specifies an event on the current state
      def event(name, options={}, &block)
        name = name.to_sym
        event = options.dup
        event[:name] = name
        specification.events[name] = event
        define_method name, &block if block_given?
      end

      # The initial state
      def initial_state(value)
        specification.initial_state = value
      end
    end

    module Base
      def resource_class(value)
        self._resource_class = value
      end

      def resource_name(value)
        self._resource_name = value
        create_resource_accessor!(_resource_name)
      end

      def state_property(value)
        self._state_property = value
      end
    end
    
  end

  class State
    extend DSL::State
  end

  class Base
    extend DSL::Base
  end

end