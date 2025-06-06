module OmgLogs
  module ActionCableConfig
    def self.setup!
      return unless Rails.env.development?

      puts "🔍 [DEBUG] OmgLogs::ActionCableConfig.setup! called"

      configure_action_cable_logging
      enhance_turbo_streams_channel_logging
      suppress_connection_logging

      # Schedule delayed enhancement for after Rails is fully loaded
      schedule_delayed_enhancement
    end

    private

    def self.configure_action_cable_logging
      Rails.application.configure do
        config.lograge.keep_original_rails_log = false

        if defined?(ActionCable)
          # TEMPORARILY DISABLED: Don't redirect ActionCable logs so we can see them in Lograge
          # log_file_path = Rails.root.join(OmgLogs.configuration.action_cable_log_file)
          # ActionCable.server.config.logger = Logger.new(log_file_path)
          puts "🔍 [DEBUG] ActionCable logs staying in main Rails log (redirection disabled)"
        else
          puts "🔍 [DEBUG] ActionCable not defined"
        end
      end
    end

    def self.enhance_turbo_streams_channel_logging
      puts "🔍 [DEBUG] Attempting to enhance Turbo::StreamsChannel"

      if defined?(Turbo::StreamsChannel)
        puts "🔍 [DEBUG] Turbo::StreamsChannel found, enhancing..."
        apply_turbo_streams_enhancement
        puts "🔍 [DEBUG] Turbo::StreamsChannel enhancement complete"
      else
        puts "🔍 [DEBUG] Turbo::StreamsChannel not defined yet"
      end
    end

    def self.schedule_delayed_enhancement
      # Try to enhance after Rails is fully initialized
      Rails.application.config.after_initialize do
        puts "🔍 [DEBUG] After initialize - checking for Turbo::StreamsChannel again"

        if defined?(Turbo::StreamsChannel)
          puts "🔍 [DEBUG] Found Turbo::StreamsChannel after initialize, enhancing..."
          apply_turbo_streams_enhancement
          puts "🔍 [DEBUG] Delayed Turbo::StreamsChannel enhancement complete"
        else
          puts "🔍 [DEBUG] Turbo::StreamsChannel still not found after initialize"
          # Last resort - try when the first ActionCable connection happens
          schedule_connection_time_enhancement
        end
      end
    end

    def self.schedule_connection_time_enhancement
      # Hook into ActionCable connection to enhance when it's definitely loaded
      if defined?(ActionCable::Connection::Base)
        ActionCable::Connection::Base.class_eval do
          alias_method :handle_open_original_omg, :handle_open

          def handle_open
            # Try to enhance Turbo::StreamsChannel on first connection
            if defined?(Turbo::StreamsChannel) && !Turbo::StreamsChannel.instance_variable_get(:@omg_enhanced)
              puts "🔍 [DEBUG] Enhancing Turbo::StreamsChannel at connection time"
              OmgLogs::ActionCableConfig.apply_turbo_streams_enhancement
              Turbo::StreamsChannel.instance_variable_set(:@omg_enhanced, true)
            end

            handle_open_original_omg
          end
        end
      end
    end

    def self.apply_turbo_streams_enhancement
      return unless defined?(Turbo::StreamsChannel)

      begin
        # Enhance the instance methods (for subscriptions)
        Turbo::StreamsChannel.class_eval do
          def subscribed
            puts "🔍 [DEBUG] Enhanced Turbo::StreamsChannel#subscribed called"

            begin
              if stream_name = verified_stream_name_from_params
                puts "🔍 [DEBUG] Stream name: #{stream_name}"

                # Store the stream name for lograge to use
                Thread.current[:turbo_stream_name] = stream_name

                # Log to Rails logger
                Rails.logger.info "🔗 [ActionCable] Turbo::StreamsChannel subscribing to: #{stream_name}"

                # Store stream name for other logging
                @omg_stream_name = stream_name

                stream_from stream_name
              else
                puts "🔍 [DEBUG] Stream name verification failed"
                Rails.logger.warn "❌ [ActionCable] Turbo::StreamsChannel subscription rejected"
                reject
              end
            rescue StandardError => e
              error_msg = "❌ [ERROR] Turbo::StreamsChannel#subscribed failed: #{e.class}: #{e.message}"
              Rails.logger.error(error_msg)
              puts error_msg
              $stderr.puts "#{error_msg}\n#{e.backtrace.join("\n")}"
              reject
            end
          end

          def unsubscribed
            puts "🔍 [DEBUG] Enhanced Turbo::StreamsChannel#unsubscribed called"

            begin
              if @omg_stream_name
                Rails.logger.info "🔌 [ActionCable] Turbo::StreamsChannel unsubscribed from: #{@omg_stream_name}"
              end

              Thread.current[:turbo_stream_name] = nil
            rescue StandardError => e
              error_msg = "❌ [ERROR] Turbo::StreamsChannel#unsubscribed failed: #{e.class}: #{e.message}"
              Rails.logger.error(error_msg)
              puts error_msg
              $stderr.puts "#{error_msg}\n#{e.backtrace.join("\n")}"
            end
          end

          # Override perform to show what actions are being performed
          def perform(action, data = {})
            puts "🔍 [DEBUG] Enhanced Turbo::StreamsChannel#perform called with action: #{action}"

            begin
              stream_info = @omg_stream_name ? " [#{@omg_stream_name}]" : ""
              Rails.logger.info "⚡ [ActionCable] Turbo::StreamsChannel##{action}#{stream_info} with data: #{data.inspect}"
              super
            rescue StandardError => e
              error_msg = "❌ [ERROR] Turbo::StreamsChannel#perform(#{action}) failed: #{e.class}: #{e.message}"
              Rails.logger.error(error_msg)
              puts error_msg
              $stderr.puts "#{error_msg}\n#{e.backtrace.join("\n")}"
              raise e
            end
          end
        end

        # Enhance the class methods (for broadcasts)
        enhance_broadcast_methods

        # Enhance the broadcast job to log actual execution
        enhance_broadcast_job

      rescue StandardError => e
        error_msg = "❌ [CRITICAL ERROR] Failed to enhance Turbo::StreamsChannel: #{e.class}: #{e.message}"
        Rails.logger.error(error_msg) if defined?(Rails.logger)
        puts error_msg
        $stderr.puts "#{error_msg}\n#{e.backtrace.join("\n")}"
      end
    end

    def self.enhance_broadcast_methods
      return unless defined?(Turbo::StreamsChannel)

      # Create a shared broadcast logger
      broadcast_logger = create_broadcast_logger

      # Get all the broadcast methods
      broadcast_methods = [
        :broadcast_replace_later_to, :broadcast_replace_to,
        :broadcast_update_later_to, :broadcast_update_to,
        :broadcast_append_later_to, :broadcast_append_to,
        :broadcast_prepend_later_to, :broadcast_prepend_to,
        :broadcast_remove_later_to, :broadcast_remove_to,
        :broadcast_action_later_to, :broadcast_action_to
      ]

      broadcast_methods.each do |method_name|
        next unless Turbo::StreamsChannel.respond_to?(method_name)

        # Store the original method
        original_method = Turbo::StreamsChannel.method(method_name)

        # Define the enhanced method
        Turbo::StreamsChannel.define_singleton_method(method_name) do |stream_name, **options|
          # Log the broadcast attempt
          is_async = method_name.to_s.include?('_later_')
          action = method_name.to_s.gsub(/_later|_to/, '').gsub(/broadcast_/, '')

          log_message = if is_async
            "📡 [QUEUED] #{method_name} to stream '#{stream_name}'"
          else
            "📡 [BROADCAST] #{method_name} to stream '#{stream_name}'"
          end

          if options[:target]
            log_message += " (target: #{options[:target]})"
          end

          if options[:partial]
            log_message += " (partial: #{options[:partial]})"
          end

          # Log to multiple destinations
          OmgLogs::ActionCableConfig.log_broadcast_message(broadcast_logger, log_message)

          # Call the original method
          original_method.call(stream_name, **options)
        end
      end

      puts "🔍 [DEBUG] Enhanced #{broadcast_methods.size} broadcast methods"
    end

    def self.enhance_broadcast_job
      # Try to enhance the ActionBroadcastJob to log actual execution
      if defined?(Turbo::Streams::ActionBroadcastJob)
        puts "🔍 [DEBUG] Enhancing Turbo::Streams::ActionBroadcastJob"

        Turbo::Streams::ActionBroadcastJob.class_eval do
          # Store the original perform method if it exists
          unless method_defined?(:perform_original_omg)
            if method_defined?(:perform)
              alias_method :perform_original_omg, :perform
            end

            def perform(stream, action:, target:, **rendering)
              execution_message = "🚀 [EXECUTING] Broadcasting #{action} to stream '#{stream}' (target: #{target})"

              # Log execution start
              OmgLogs::ActionCableConfig.log_broadcast_message(
                OmgLogs::ActionCableConfig.create_broadcast_logger,
                execution_message
              )

              begin
                # Call the original method if it exists, otherwise use the basic broadcast logic
                if respond_to?(:perform_original_omg)
                  perform_original_omg(stream, action: action, target: target, **rendering)
                else
                  # Fallback to basic ActionCable broadcast if original method doesn't exist
                  ActionCable.server.broadcast(stream, {
                    action: action,
                    target: target,
                    **rendering
                  })
                end

                # Log successful completion
                completion_message = "✅ [COMPLETED] Broadcast #{action} to stream '#{stream}' completed"
                OmgLogs::ActionCableConfig.log_broadcast_message(
                  OmgLogs::ActionCableConfig.create_broadcast_logger,
                  completion_message
                )
              rescue StandardError => e
                # CRITICAL: Log errors prominently with full details
                error_message = "❌ [FAILED] Broadcast #{action} to stream '#{stream}' FAILED!"
                error_details = "💥 ERROR: #{e.class}: #{e.message}"
                error_backtrace = "🔍 BACKTRACE:\n#{e.backtrace.join("\n")}"

                # Log to multiple destinations to ensure visibility
                [error_message, error_details, error_backtrace].each do |msg|
                  OmgLogs::ActionCableConfig.log_broadcast_message(
                    OmgLogs::ActionCableConfig.create_broadcast_logger,
                    msg
                  )
                end

                # Also ensure it goes to Rails error logging
                Rails.logger.error("#{error_message}\n#{error_details}\n#{error_backtrace}") if defined?(Rails.logger)

                # Re-raise the error so it still gets handled by the job queue
                raise e
              end
            end
          end
        end
      else
        puts "🔍 [DEBUG] Turbo::Streams::ActionBroadcastJob not found"
      end
    end

    def self.create_broadcast_logger
      log_file_path = Rails.root.join(OmgLogs.configuration.turbo_broadcast_log_file)
      Logger.new(log_file_path).tap do |logger|
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} #{msg}\n"
        end
      end
    end

    def self.log_broadcast_message(broadcast_logger, message)
      # Handle error messages with special prominence
      is_error = message.include?('❌') || message.include?('💥') || message.include?('ERROR') || message.include?('FAILED')

      if is_error
        # ERRORS get maximum visibility
        error_banner = "=" * 100
        puts error_banner
        puts message
        puts error_banner

        # Log to file with timestamp
        broadcast_logger.error(message)

        # Force to Rails logger with high priority
        begin
          Rails.logger.error(message) if defined?(Rails.logger)
        rescue StandardError
          # If Rails.logger fails, use STDERR
          $stderr.puts message
        end

        # Also to STDERR for maximum visibility
        $stderr.puts message
      else
        # Normal messages get standard logging

        # 1. Dedicated broadcast log file
        broadcast_logger.info(message)

        # 2. STDOUT (visible in all processes)
        puts message

        # 3. Rails logger (if available)
        begin
          Rails.logger.info(message) if defined?(Rails.logger)
        rescue StandardError
          # Ignore if Rails.logger not available (e.g., in worker)
        end

        # 4. Debug output (only if debug mode)
        puts "🔍 [DEBUG] #{message}" if OmgLogs.configuration.debug_mode
      end
    end

    def self.suppress_connection_logging
      return unless defined?(ActionCable)

      # Override ActionCable connection logging to reduce noise
      ActionCable::Connection::Base.class_eval do
        private

        def handle_open_with_quiet_logging
          # Suppress the noisy connection logs in development
          handle_open_without_quiet_logging
        end

        if method_defined?(:handle_open) && !method_defined?(:handle_open_without_quiet_logging)
          alias_method :handle_open_without_quiet_logging, :handle_open
          alias_method :handle_open, :handle_open_with_quiet_logging
        end
      end
    end
  end
end
