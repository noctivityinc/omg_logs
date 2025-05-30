require "omg_logs/version"
require "omg_logs/configuration"

module OmgLogs
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.setup!
    return unless Rails.env.development?
    return if @setup_complete

    @setup_complete = true

    # Configure Rails settings
    configure_rails_settings

    # Load and setup all components
    require_components
    setup_components
  end

  private

  def self.configure_rails_settings
    Rails.application.configure do
      # Web console settings
      config.web_console.whiny_requests = false if defined?(WebConsole)

      # Reduce log level for cleaner output
      config.log_level = :info

      # Enable template rendering notifications
      config.action_view.logger = nil
    end
  end

  def self.require_components
    require "omg_logs/method_tracer"
    require "omg_logs/log_filtering"
    require "omg_logs/enhanced_sql_logger"
    require "omg_logs/lograge_config"
    require "omg_logs/action_cable_config"
  end

  def self.setup_components
    OmgLogs::MethodTracer.setup! if configuration.enable_method_tracing
    OmgLogs::LogFiltering.setup! if configuration.enable_log_filtering
    OmgLogs::EnhancedSqlLogger.setup! if configuration.enable_sql_logging
    OmgLogs::LogrageConfig.setup! if configuration.enable_lograge
    OmgLogs::ActionCableConfig.setup! if configuration.enable_action_cable_filtering
  end
end

# Auto-require railtie if we're in a Rails environment
require "omg_logs/railtie" if defined?(Rails)
