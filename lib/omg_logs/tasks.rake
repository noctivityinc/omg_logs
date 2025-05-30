namespace :omg_logs do
  desc "Clear all OMG Logs log files"
  task :clear do
    log_files = [
      Rails.root.join('log', 'enhanced_sql.log'),
      Rails.root.join('log', 'actioncable.log'),
      Rails.root.join('log', 'sql.log')
    ]

    log_files.each do |file|
      if File.exist?(file)
        File.truncate(file, 0)
        puts "✅ Cleared #{file}"
      end
    end

    puts "🎉 All OMG Logs files cleared!"
  end

  desc "Show OMG Logs status and configuration"
  task :status => :environment do
    puts ""
    puts "🚀 OMG Logs Status".colorize(:light_cyan)
    puts "=" * 50

    puts ""
    puts "Environment: #{Rails.env}".colorize(:yellow)
    puts "Active: #{Rails.env.development? ? 'YES'.colorize(:green) : 'NO'.colorize(:red)}"

    if Rails.env.development?
      config = OmgLogs.configuration

      puts ""
      puts "Features:".colorize(:light_blue)
      puts "  Method Tracing: #{status_icon(config.enable_method_tracing)}"
      puts "  Log Filtering: #{status_icon(config.enable_log_filtering)}"
      puts "  SQL Logging: #{status_icon(config.enable_sql_logging)}"
      puts "  Lograge: #{status_icon(config.enable_lograge)}"
      puts "  ActionCable Filtering: #{status_icon(config.enable_action_cable_filtering)}"

      puts ""
      puts "Log Files:".colorize(:light_magenta)
      puts "  Enhanced SQL: #{config.sql_log_file}"
      puts "  ActionCable: #{config.action_cable_log_file}"

      puts ""
      puts "Performance Thresholds:".colorize(:light_yellow)
      thresholds = config.performance_thresholds
      puts "  ⚡ Fast: < #{thresholds[:fast]}ms"
      puts "  🟡 Medium: #{thresholds[:fast]}-#{thresholds[:medium]}ms"
      puts "  🟠 Slow: #{thresholds[:medium]}-#{thresholds[:slow]}ms"
      puts "  🔴 Very Slow: > #{thresholds[:slow]}ms"
    end

    puts ""
  end

  desc "Tail the enhanced SQL log"
  task :tail_sql do
    log_file = Rails.root.join('log', 'enhanced_sql.log')

    if File.exist?(log_file)
      puts "📋 Tailing #{log_file}..."
      puts "Press Ctrl+C to stop"
      puts ""
      exec "tail -f #{log_file}"
    else
      puts "❌ Log file not found: #{log_file}"
      puts "Make sure your Rails app is running in development mode."
    end
  end

  def status_icon(enabled)
    enabled ? "✅ Enabled".colorize(:green) : "❌ Disabled".colorize(:red)
  end
end
