module OmgLogs
  class Railtie < Rails::Railtie
    railtie_name :omg_logs

    # Make sure generators are loaded
    generators do
      require "generators/omg_logs/install_generator"
    end

    # Configure Rails settings EARLY, before other initializers
    config.before_configuration do
      if Rails.env.development?
        # Ensure our gems are loaded
        begin
          require 'lograge'
          require 'colorize'
          require 'amazing_print'
        rescue LoadError => e
          Rails.logger&.warn "OMG Logs: Missing dependency - #{e.message}"
        end

        # Apply Rails configuration settings immediately
        Rails.application.configure do
          config.web_console.whiny_requests = false if defined?(WebConsole)
          config.log_level = :info
          config.action_view.logger = nil
        end
      end
    end

    # Set up OMG Logs components early but after configuration
    initializer "omg_logs.setup", before: :initialize_logger do
      OmgLogs.setup! if Rails.env.development?
    end
  end
end
