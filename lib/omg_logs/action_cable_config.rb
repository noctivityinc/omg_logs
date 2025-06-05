module OmgLogs
  module ActionCableConfig
    def self.setup!
      return unless Rails.env.development?

      configure_action_cable_logging
      enhance_turbo_streams_channel_logging
      suppress_connection_logging
    end

    private

    def self.configure_action_cable_logging
      Rails.application.configure do
        config.lograge.keep_original_rails_log = false

        if defined?(ActionCable)
          log_file_path = Rails.root.join(OmgLogs.configuration.action_cable_log_file)
          ActionCable.server.config.logger = Logger.new(log_file_path)
        end
      end
    end

    def self.enhance_turbo_streams_channel_logging
      return unless defined?(Turbo::StreamsChannel)

      # Enhance Turbo::StreamsChannel to log stream names
      Turbo::StreamsChannel.class_eval do
        def subscribed
          if stream_name = verified_stream_name_from_params
            # Log the actual stream name being subscribed to
            Rails.logger.info "🔗 Turbo::StreamsChannel subscribing to: #{stream_name.colorize(:light_green)}"

            # Store stream name for potential use in other logging
            @omg_stream_name = stream_name

            stream_from stream_name
          else
            Rails.logger.warn "❌ Turbo::StreamsChannel subscription rejected - invalid stream name"
            reject
          end
        end

        def unsubscribed
          if @omg_stream_name
            Rails.logger.info "🔌 Turbo::StreamsChannel unsubscribed from: #{@omg_stream_name.colorize(:light_red)}"
          else
            Rails.logger.info "🔌 Turbo::StreamsChannel unsubscribed"
          end
        end

        # Override perform to show what actions are being performed
        def perform(action, data = {})
          stream_info = @omg_stream_name ? " [#{@omg_stream_name}]" : ""
          Rails.logger.info "⚡ Turbo::StreamsChannel##{action}#{stream_info} with data: #{data.inspect}"
          super
        end
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
