module OmgLogs
  module MethodTracer
    def self.setup!
      return unless Rails.env.development?

      # Define the RequestTracer module
      define_request_tracer_module

      # Include it in controller base classes
      include_in_controllers
    end

    private

    def self.define_request_tracer_module
      Object.const_set(:RequestTracer, Module.new do
        extend ActiveSupport::Concern

        included do
          around_action :trace_request_methods
        end

        private

        def trace_request_methods
          request_id = SecureRandom.hex(8)
          Thread.current[:current_request_id] = request_id
          Thread.current[:rendered_templates] = []
          Thread.current[:method_calls] = []
          Thread.current[:tracked_methods] = Set.new
          Thread.current[:before_action_methods] = Set.new

          Thread.current[:request_info] = {
            method: request.method,
            path: request.path,
            controller: self.class.name,
            action: params[:action],
            format: request.format.symbol,
            request_id: request_id,
            current_method: "#{self.class.name}##{params[:action]}"
          }

          Thread.current[:current_method] = "#{self.class.name}##{params[:action]}"

          # Track before_actions first
          self.class._process_action_callbacks.each do |callback|
            next unless callback.kind == :before && callback.filter.is_a?(Symbol)

            method_name = callback.filter
            source_class = find_method_source_class(method_name)
            method_sig = "#{source_class}##{method_name} (before_action)"

            next if Thread.current[:tracked_methods].include?(method_sig)

            Thread.current[:method_calls] << method_sig
            Thread.current[:tracked_methods].add(method_sig)
            Thread.current[:before_action_methods].add(method_name)
          end

          # Subscribe to template rendering
          template_subscriber = ActiveSupport::Notifications.subscribe('render_template.action_view') do |name, start, finish, id, payload|
            if payload[:identifier]
              template_path = payload[:identifier].gsub(Rails.root.to_s, '').gsub(%r{^/}, '')
              Thread.current[:rendered_templates] ||= []
              Thread.current[:rendered_templates] << template_path unless Thread.current[:rendered_templates].include?(template_path)

              template_name = File.basename(template_path)
              Thread.current[:current_method] = "Rendering: #{template_name}"
              Thread.current[:request_info][:current_method] = "Rendering: #{template_name}"
            end
          end

          partial_subscriber = ActiveSupport::Notifications.subscribe('render_partial.action_view') do |name, start, finish, id, payload|
            if payload[:identifier]
              template_path = payload[:identifier].gsub(Rails.root.to_s, '').gsub(%r{^/}, '')
              Thread.current[:rendered_templates] ||= []
              Thread.current[:rendered_templates] << template_path unless Thread.current[:rendered_templates].include?(template_path)

              partial_name = File.basename(template_path)
              Thread.current[:current_method] = "Rendering: #{partial_name}"
              Thread.current[:request_info][:current_method] = "Rendering: #{partial_name}"
            end
          end

          # Track the main action
          action_name = params[:action]
          controller_name = self.class.name
          main_action = "#{controller_name}##{action_name}"
          unless Thread.current[:tracked_methods].include?(main_action)
            Thread.current[:method_calls] << main_action
            Thread.current[:tracked_methods].add(main_action)
          end

          # Set up method tracking
          setup_nested_method_tracking

          yield
        ensure
          ActiveSupport::Notifications.unsubscribe(template_subscriber) if template_subscriber
          ActiveSupport::Notifications.unsubscribe(partial_subscriber) if partial_subscriber
          Thread.current[:current_request_id] = nil
          Thread.current[:request_info] = nil
          Thread.current[:current_method] = nil
          Thread.current[:tracked_methods] = nil
          Thread.current[:before_action_methods] = nil
        end

        def setup_nested_method_tracking
          return if @nested_tracking_setup

          @nested_tracking_setup = true

          controller_methods = self.class.instance_methods(false) + self.class.private_instance_methods(false)

          controller_methods.each do |method_name|
            next if method_name.to_s.include?('_original')
            next if [:trace_request_methods, :setup_nested_method_tracking].include?(method_name)
            next if method_name.to_s.start_with?('_')

            begin
              original_method = method(method_name)

              define_singleton_method("#{method_name}_original") do |*args, &block|
                original_method.call(*args, &block)
              end

              define_singleton_method(method_name) do |*args, &block|
                if Thread.current[:method_calls] && Thread.current[:current_request_id] && !Thread.current[:before_action_methods]&.include?(method_name)
                  method_sig = "  → #{self.class.name}##{method_name}"
                  unless Thread.current[:tracked_methods].include?(method_sig)
                    Thread.current[:method_calls] << method_sig
                    Thread.current[:tracked_methods].add(method_sig)
                    Thread.current[:current_method] = "#{self.class.name}##{method_name}"
                    Thread.current[:request_info][:current_method] = "#{self.class.name}##{method_name}"
                  end
                end

                send("#{method_name}_original", *args, &block)
              end
            rescue StandardError => e
              next
            end
          end
        end

        def find_method_source_class(method_name)
          current_class = self.class

          while current_class
            if current_class.instance_methods(false).include?(method_name) ||
               current_class.private_instance_methods(false).include?(method_name) ||
               current_class.protected_instance_methods(false).include?(method_name)
              return current_class.name
            end

            current_class = current_class.superclass
            break if current_class == Object || current_class.nil?
          end

          self.class.name
        end
      end)
    end

    def self.include_in_controllers
      ActionController::Base.include(RequestTracer)

      if defined?(ActionController::API)
        ActionController::API.include(RequestTracer)
      end
    end
  end
end
