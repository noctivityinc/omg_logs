module OmgLogs
  class Configuration
    attr_accessor :enable_method_tracing,
                  :enable_log_filtering,
                  :enable_sql_logging,
                  :enable_lograge,
                  :enable_action_cable_filtering,
                  :debug_mode,
                  :sql_log_file,
                  :action_cable_log_file,
                  :turbo_broadcast_log_file,
                  :filter_patterns,
                  :performance_thresholds,
                  :current_user_method,
                  :current_user_label

    def initialize
      @enable_method_tracing = true
      @enable_log_filtering = true
      @enable_sql_logging = true
      @enable_lograge = true
      @enable_action_cable_filtering = true
      @debug_mode = false

      @sql_log_file = 'log/enhanced_sql.log'
      @action_cable_log_file = 'log/actioncable.log'
      @turbo_broadcast_log_file = 'log/turbo_broadcasts.log'
      @current_user_method = nil  # Will use Current.professional.id if set to 'Current.professional'
      @current_user_label = 'Account'  # Label to show in logs (e.g., 'Professional', 'Account', 'User')

      # Start with empty filter patterns - consumer has full control
      @filter_patterns = []
      @performance_thresholds = default_performance_thresholds
    end

    # Helper method to get commonly used filter patterns that consumers can optionally include
    def self.common_filter_patterns
      [
        # Console render messages
        /Cannot render console from.*Allowed networks/,

        # Font and asset related
        /webfonts/,
        /\.woff2?\b/,
        /\.ttf\b/,
        /\.eot\b/,
        /ActionController::RoutingError.*webfonts/,
        /ActionController::RoutingError.*fonts/,
        /ActionController::RoutingError.*fa-.*\.(woff|ttf|eot)/,
        /No route matches.*webfonts/,
        /No route matches.*fonts/,
        /No route matches.*fa-.*\.(woff|ttf|eot)/,

        # Turbo and ActionCable
        /Turbo::StreamsChannel/,
        /StreamsChannel#subscribe/,
        /StreamsChannel#unsubscribe/,
        /ActionCable/,
        /Connection#connect/,
        /\| \s*\| Turbo::/,
        /\|\s+\|\s+Turbo::/,

        # Lograge output patterns for ActionCable
        /\s+\|\s+\|\s+\w+\s+\|\s+\d+\s+\|\s+[\d.]+ms.*StreamsChannel/,
        /===.*\n.*StreamsChannel/m
      ]
    end

    # Helper method to get asset-related filter patterns
    def self.asset_filter_patterns
      [
        /webfonts/,
        /\.woff2?\b/,
        /\.ttf\b/,
        /\.eot\b/,
        /ActionController::RoutingError.*webfonts/,
        /ActionController::RoutingError.*fonts/,
        /ActionController::RoutingError.*fa-.*\.(woff|ttf|eot)/,
        /No route matches.*webfonts/,
        /No route matches.*fonts/,
        /No route matches.*fa-.*\.(woff|ttf|eot)/
      ]
    end

    # Helper method to get ActionCable/Turbo filter patterns
    def self.actioncable_filter_patterns
      [
        /Turbo::StreamsChannel/,
        /StreamsChannel#subscribe/,
        /StreamsChannel#unsubscribe/,
        /ActionCable/,
        /Connection#connect/,
        /\| \s*\| Turbo::/,
        /\|\s+\|\s+Turbo::/,
        /\s+\|\s+\|\s+\w+\s+\|\s+\d+\s+\|\s+[\d.]+ms.*StreamsChannel/,
        /===.*\n.*StreamsChannel/m
      ]
    end

    # Helper method to get console-related filter patterns
    def self.console_filter_patterns
      [
        /Cannot render console from.*Allowed networks/
      ]
    end

    private

    def default_performance_thresholds
      {
        fast: 5.0,      # < 5ms = ⚡
        medium: 20.0,   # 5-20ms = 🟡
        slow: 100.0,    # 20-100ms = 🟠
        # > 100ms = 🔴
      }
    end
  end
end
