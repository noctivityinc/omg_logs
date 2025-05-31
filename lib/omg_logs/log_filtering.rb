module OmgLogs
  module LogFiltering
    def self.setup!
      puts "🔍 [DEBUG] LogFiltering.setup! called - Rails.env: #{Rails.env}"
      return unless Rails.env.development?

      puts "🔍 [DEBUG] LogFiltering proceeding with setup in development"

      # Apply STDOUT filtering immediately
      setup_stdout_filtering

      Rails.application.config.after_initialize do
        puts "🔍 [DEBUG] LogFiltering after_initialize callback running"
        apply_filtering_to_rails_logger
      end
    end

    private

    def self.setup_stdout_filtering
      puts "🔍 [DEBUG] Setting up STDOUT filtering"

      original_stdout = $stdout

      filtering_stdout = Class.new do
        def initialize(original)
          @original = original
        end

        def write(message)
          if message.nil? || message.to_s.strip.empty?
            @original.write("🔍 [DEBUG] FILTERED STDOUT write - message: #{message.inspect}\n")
            return 0  # Don't write the blank line
          end
          @original.write(message)
        end

        def puts(*messages)
          filtered_messages = messages.reject do |msg|
            is_blank = msg.nil? || msg.to_s.strip.empty?
            if is_blank
              @original.write("🔍 [DEBUG] FILTERED STDOUT puts - message: #{msg.inspect}\n")
            end
            is_blank
          end

          return if filtered_messages.empty?
          @original.puts(*filtered_messages)
        end

        def print(*messages)
          filtered_messages = messages.reject do |msg|
            is_blank = msg.nil? || msg.to_s.strip.empty?
            if is_blank
              @original.write("🔍 [DEBUG] FILTERED STDOUT print - message: #{msg.inspect}\n")
            end
            is_blank
          end

          return if filtered_messages.empty?
          @original.print(*filtered_messages)
        end

        # Forward all other methods to original stdout
        def method_missing(method_name, *args, &block)
          @original.send(method_name, *args, &block)
        end

        def respond_to_missing?(method_name, include_private = false)
          @original.respond_to?(method_name, include_private)
        end
      end.new(original_stdout)

      $stdout = filtering_stdout
      puts "🔍 [DEBUG] STDOUT filtering applied"
    end

    def self.apply_filtering_to_rails_logger
      puts "🔍 [DEBUG] apply_filtering_to_rails_logger called"
      puts "🔍 [DEBUG] Rails.logger present: #{!!Rails.logger}"
      puts "🔍 [DEBUG] Rails.logger class: #{Rails.logger.class}" if Rails.logger

      return unless Rails.logger

      if Rails.logger.is_a?(ActiveSupport::BroadcastLogger)
        puts "🔍 [DEBUG] Detected BroadcastLogger - applying special handling"
        apply_broadcast_logger_filtering(Rails.logger)
      else
        puts "🔍 [DEBUG] Regular logger - applying standard filtering"
        apply_standard_logger_filtering(Rails.logger)
      end
    end

    def self.apply_broadcast_logger_filtering(broadcast_logger)
      # BroadcastLogger broadcasts to multiple loggers, so we need to filter each one
      broadcast_logger.broadcasts.each_with_index do |logger, index|
        puts "🔍 [DEBUG] Filtering broadcast logger ##{index}: #{logger.class}"

        # Override the add method on each broadcast logger
        original_add = logger.method(:add)
        logger.define_singleton_method(:add) do |severity, message = nil, progname = nil, &block|
          if should_filter_blank_message?(message)
            puts "🔍 [DEBUG] FILTERED broadcast logger ##{index} - message: #{message.inspect}"
            return
          end
          original_add.call(severity, message, progname, &block)
        end

        # Override write method if it exists
        if logger.respond_to?(:write)
          original_write = logger.method(:write)
          logger.define_singleton_method(:write) do |message|
            if should_filter_blank_message?(message)
              puts "🔍 [DEBUG] FILTERED write on broadcast logger ##{index} - message: #{message.inspect}"
              return
            end
            original_write.call(message)
          end
        end

        # Add the filtering method to each logger
        logger.define_singleton_method(:should_filter_blank_message?) do |message|
          message.nil? || message.to_s.strip.empty?
        end

        puts "🔍 [DEBUG] Applied filtering to broadcast logger ##{index}"
      end
    end

    def self.apply_standard_logger_filtering(logger)
      # For regular loggers, use the extend approach
      quiet_logger_module = Module.new do
        def add(severity, message = nil, progname = nil)
          if should_filter_blank_message?(message)
            puts "🔍 [DEBUG] FILTERED standard logger - message: #{message.inspect}"
            return
          end
          super
        end

        def write(message)
          if should_filter_blank_message?(message)
            puts "🔍 [DEBUG] FILTERED write on standard logger - message: #{message.inspect}"
            return
          end
          super
        end

        private

        def should_filter_blank_message?(message)
          message.nil? || message.to_s.strip.empty?
        end
      end

      logger.extend(quiet_logger_module)
      puts "🔍 [DEBUG] Extended standard logger with filtering"
    end

    # Helper method for broadcast logger filtering
    def self.should_filter_blank_message?(message)
      message.nil? || message.to_s.strip.empty?
    end
  end
end
