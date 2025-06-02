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
                  :filter_patterns,
                  :performance_thresholds

    def initialize
      @enable_method_tracing = true
      @enable_log_filtering = true
      @enable_sql_logging = true
      @enable_lograge = true
      @enable_action_cable_filtering = true
      @debug_mode = false

      @sql_log_file = 'log/enhanced_sql.log'
      @action_cable_log_file = 'log/actioncable.log'

      @filter_patterns = default_filter_patterns
      @performance_thresholds = default_performance_thresholds
    end

    private

    def default_filter_patterns
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
