require 'rails/generators'

module OmgLogs
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Install OMG Logs configuration"

      def self.source_root
        @source_root ||= File.expand_path('templates', __dir__)
      end

      def create_initializer
        create_file "config/initializers/omg_logs.rb", initializer_content
      end

      def create_log_directory
        empty_directory "log"
      end

      def show_readme
        say ""
        say "🎉 OMG Logs has been installed!", :green
        say ""
        say "✅ Created config/initializers/omg_logs.rb", :green
        say "✅ Ensured log directory exists", :green
        say ""
        say "🚀 OMG Logs will automatically configure your development logging!", :cyan
        say ""
        say "📋 Features enabled:", :yellow
        say "  • Enhanced method tracing"
        say "  • Beautiful SQL logging with performance indicators"
        say "  • Filtered console output (removes font/ActionCable noise)"
        say "  • Colorized Lograge formatting"
        say "  • Template rendering tracking"
        say ""
        say "⚙️  To customize configuration, edit config/initializers/omg_logs.rb", :blue
        say ""
        say "📝 Log files created in development:", :magenta
        say "  • log/enhanced_sql.log - Enhanced SQL queries"
        say "  • log/actioncable.log - ActionCable logs (separated)"
        say "  • log/sql.log - Standard SQL logs"
        say ""
      end

      private

      def initializer_content
        <<~RUBY
          # OMG Logs Configuration
          # This gem enhances Rails development logging with beautiful formatting,
          # method tracing, and noise filtering.

          if Rails.env.development?
          OmgLogs.configure do |config|
            # Enable/disable specific features
            config.enable_method_tracing = true
            config.enable_log_filtering = true
            config.enable_sql_logging = true
            config.enable_lograge = true
            config.enable_action_cable_filtering = true

            # Log file locations (relative to Rails.root)
            config.sql_log_file = 'log/enhanced_sql.log'
            config.action_cable_log_file = 'log/actioncable.log'

            # Performance thresholds for SQL query indicators
            # config.performance_thresholds = {
            #   fast: 5.0,      # < 5ms = ⚡ (green/fast)
            #   medium: 20.0,   # 5-20ms = 🟡 (yellow/medium)
            #   slow: 100.0,    # 20-100ms = 🟠 (orange/slow)
            #   # > 100ms = 🔴 (red/very slow)
            # }

            # Add custom noise filter patterns (regex)
            # config.filter_patterns += [
            #   /your_custom_pattern/,
            #   /another_pattern/
            # ]
          end
          end

          # The gem automatically configures Rails settings equivalent to:
          #
          # Rails.application.configure do
          #   config.web_console.whiny_requests = false if defined?(WebConsole)
          #   config.log_level = :info
          #   config.action_view.logger = nil
          # end
          #
          # If you need to override any of these, you can do so in your
          # config/environments/development.rb file.
        RUBY
      end
    end
  end
end
