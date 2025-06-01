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
          Thread.current[:redirects] = []

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

          # Set up method tracking and redirect intercepting
          setup_nested_method_tracking
          setup_redirect_tracking

          yield
        ensure
          ActiveSupport::Notifications.unsubscribe(template_subscriber) if template_subscriber
          ActiveSupport::Notifications.unsubscribe(partial_subscriber) if partial_subscriber
          Thread.current[:current_request_id] = nil
          Thread.current[:request_info] = nil
          Thread.current[:current_method] = nil
          Thread.current[:tracked_methods] = nil
          Thread.current[:before_action_methods] = nil
          Thread.current[:redirects] = nil
        end

        def setup_redirect_tracking
          return if @redirect_tracking_setup

          @redirect_tracking_setup = true

          # Track various redirect methods
          redirect_methods = [
            :redirect_to, :redirect_back, :redirect_back_or_to,
            :redirect_to_back_or_default, :redirect_back_or_default
          ]

          redirect_methods.each do |method_name|
            next unless respond_to?(method_name, true)

            begin
              original_method = method(method_name)

              define_singleton_method("#{method_name}_original_omg") do |*args, &block|
                original_method.call(*args, &block)
              end

              define_singleton_method(method_name) do |*args, &block|
                if Thread.current[:current_request_id]
                  redirect_info = extract_redirect_info(method_name, args)
                  current_method = Thread.current[:current_method] || "#{self.class.name}##{params[:action]}"

                  redirect_entry = {
                    method: method_name,
                    destination: redirect_info[:destination],
                    status: redirect_info[:status],
                    called_from: current_method,
                    timestamp: Time.current
                  }

                  Thread.current[:redirects] ||= []
                  Thread.current[:redirects] << redirect_entry

                  # Add to method calls for immediate visibility
                  redirect_msg = "  🔄 REDIRECT: #{method_name} → #{redirect_info[:destination]}"
                  redirect_msg += " (#{redirect_info[:status]})" if redirect_info[:status]
                  Thread.current[:method_calls] << redirect_msg
                end

                send("#{method_name}_original_omg", *args, &block)
              end
            rescue StandardError => e
              # Skip if method can't be tracked
              next
            end
          end
        end

        def extract_redirect_info(method_name, args)
          info = { destination: 'unknown', status: nil }

          case method_name
          when :redirect_to
            if args.first.is_a?(Hash)
              # Handle options hash
              options = args.first
              if options[:action]
                info[:destination] = "#{options[:controller] || params[:controller]}##{options[:action]}"
              elsif options[:controller]
                info[:destination] = "#{options[:controller]}#index"
              else
                # Try to extract path/url
                info[:destination] = extract_path_from_options(options)
              end
              info[:status] = options[:status] if options[:status]
            elsif args.first.is_a?(String)
              info[:destination] = args.first
            elsif args.first.respond_to?(:to_s)
              info[:destination] = args.first.to_s
            end

            # Check for status in second argument
            if args[1].is_a?(Hash) && args[1][:status]
              info[:status] = args[1][:status]
            end

          when :redirect_back
            fallback = args.find { |arg| arg.is_a?(Hash) && arg[:fallback_location] }
            if fallback
              info[:destination] = "back (fallback: #{fallback[:fallback_location]})"
            else
              info[:destination] = "back"
            end

          when :redirect_back_or_to, :redirect_back_or_default
            if args.first
              info[:destination] = "back or #{args.first}"
            else
              info[:destination] = "back or default"
            end

          else
            info[:destination] = args.first.to_s if args.first
          end

          info
        end

        def extract_path_from_options(options)
          # Handle common Rails routing options
          if options[:id] && options[:action]
            "#{options[:action]}/#{options[:id]}"
          elsif options[:path]
            options[:path]
          elsif options[:url]
            options[:url]
          else
            options.inspect
          end
        end

        def setup_nested_method_tracking
          return if @nested_tracking_setup

          @nested_tracking_setup = true

          controller_methods = self.class.instance_methods(false) + self.class.private_instance_methods(false)

          controller_methods.each do |method_name|
            next if method_name.to_s.include?('_original')
            next if [:trace_request_methods, :setup_nested_method_tracking, :setup_redirect_tracking].include?(method_name)
            next if method_name.to_s.start_with?('_')
            next if method_name.to_s.end_with?('_original_omg')

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
