module OmgLogs
  module ActionCableConfig
    def self.setup!
      return unless Rails.env.development?

      configure_action_cable_logging
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
