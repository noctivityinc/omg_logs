require 'colorize'

module OmgLogs
  module EnhancedSqlLogger
    def self.setup!
      return unless Rails.env.development?

      define_sql_writer_class
      setup_sql_logging
      configure_active_record_logger
    end

    private

    def self.define_sql_writer_class
      Object.const_set(:EnhancedSQLWriter, Class.new do
        def initialize(log_file_path)
          @log_file = File.open(log_file_path, 'a')
          @log_file.sync = true
          @current_request_id = nil
        end

        def write_sql(message, payload = {})
          return unless sql_query?(message)

          request_id = Thread.current[:current_request_id]

          if request_id && request_id != @current_request_id
            @current_request_id = request_id
            show_request_header
          end

          formatted_sql = format_sql_message(message, payload)
          @log_file.puts(formatted_sql)
          @log_file.flush
        end

        private

        def sql_query?(message)
          (message.include?('ms)') || message.include?('CACHE')) &&
            (message.include?('SELECT') || message.include?('INSERT') ||
             message.include?('UPDATE') || message.include?('DELETE') ||
             message.include?('Load') || message.include?('Count') ||
             message.include?('Create') || message.include?('Destroy') ||
             message.include?('TRANSACTION') || message.include?('Exists'))
        end

        def show_request_header
          request_info = Thread.current[:request_info] || {}
          return unless request_info.any?

          @log_file.puts ""
          header = "🚀 " + "=" * 95 + " 🚀"
          @log_file.puts(header.colorize(:light_cyan))

          format_info = request_info[:format] ? " (#{request_info[:format]})" : ""
          main_info = "#{request_info[:method]} #{request_info[:path]}#{format_info} | #{request_info[:controller]}##{request_info[:action]}"
          @log_file.puts("📋 #{main_info}".colorize(:light_green))

          separator = "─" * 100
          @log_file.puts(separator.colorize(:light_cyan))
          @log_file.flush
        end

        def format_sql_message(message, payload)
          timing_match = message.match(/\((\d+\.\d+)ms\)/)
          timing = timing_match ? timing_match[1].to_f : 0

          thresholds = OmgLogs.configuration.performance_thresholds
          performance_indicator = case timing
                                  when 0...thresholds[:fast] then "⚡"
                                  when thresholds[:fast]...thresholds[:medium] then "🟡"
                                  when thresholds[:medium]...thresholds[:slow] then "🟠"
                                  else "🔴"
                                  end

          if message.include?('CACHE')
            color = :light_magenta
            icon = "💰"
          elsif message.include?('TRANSACTION')
            if message.include?('BEGIN')
              color = :cyan
              icon = "🚀"
            elsif message.include?('COMMIT')
              color = :green
              icon = "✅"
            elsif message.include?('ROLLBACK')
              color = :red
              icon = "❌"
            else
              color = :cyan
              icon = "🔄"
            end
          elsif message.include?('SELECT') || message.include?('Load') || message.include?('Count') || message.include?('Exists')
            color = :light_blue
            icon = "🔍"
          elsif message.include?('INSERT') || message.include?('Create')
            color = :light_green
            icon = "➕"
          elsif message.include?('UPDATE')
            color = :light_yellow
            icon = "✏️"
          elsif message.include?('DELETE') || message.include?('Destroy')
            color = :light_red
            icon = "🗑️"
          else
            color = :white
            icon = "💾"
          end

          method_context = get_method_context(payload)
          clean_message = message.strip.gsub(/\s+/, ' ')
          formatted = "  #{performance_indicator} #{icon} #{clean_message} #{method_context}"
          formatted.colorize(color)
        end

        def get_method_context(payload)
          caller_info = caller_locations(0, 20)

          relevant_calls = caller_info.select do |location|
            path = location.path
            path.include?('app/controllers') ||
              path.include?('app/models') ||
              path.include?('app/views') ||
              path.include?('app/helpers')
          end

          if relevant_calls.any?
            call = relevant_calls.first
            file_path = call.path.gsub(Rails.root.to_s, '').gsub(%r{^/}, '')
            method_name = call.label
            line_number = call.lineno

            if file_path.include?('app/controllers')
              class_name = file_path.gsub('app/controllers/', '').gsub('.rb', '').camelize.gsub('/', '::')
              return "[#{class_name}##{method_name}:#{line_number}]"
            elsif file_path.include?('app/models')
              class_name = file_path.gsub('app/models/', '').gsub('.rb', '').camelize.gsub('/', '::')
              return "[#{class_name}##{method_name}:#{line_number}]"
            elsif file_path.include?('app/views')
              view_name = file_path.gsub('app/views/', '')
              return "[View: #{view_name}:#{line_number}]"
            elsif file_path.include?('app/helpers')
              helper_name = file_path.gsub('app/helpers/', '').gsub('.rb', '').camelize
              return "[#{helper_name}##{method_name}:#{line_number}]"
            end
          end

          thread_method = Thread.current[:current_method]
          thread_method ? "[#{thread_method}]" : "[Unknown]"
        end
      end)
    end

    def self.setup_sql_logging
      log_file_path = Rails.root.join(OmgLogs.configuration.sql_log_file)
      sql_writer = EnhancedSQLWriter.new(log_file_path)

      ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        next if payload[:name] == 'SCHEMA'
        next if payload[:sql].nil?

        duration = finish - start
        formatted_message = "#{payload[:name]} (#{duration.round(1)}ms) #{payload[:sql]}"
        sql_writer.write_sql(formatted_message, payload)
      end
    end

    def self.configure_active_record_logger
      Rails.application.configure do
        config.active_record.logger = Logger.new(Rails.root.join('log', 'sql.log'))
        config.active_record.verbose_query_logs = true
      end
    end
  end
end
