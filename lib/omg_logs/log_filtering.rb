module OmgLogs
  module LogFiltering
    def self.setup!
      return unless Rails.env.development?

      # Apply STDOUT filtering immediately
      setup_stdout_filtering

      Rails.application.config.after_initialize do
        apply_filtering_to_rails_logger
      end
    end

    private

    def self.setup_stdout_filtering
      original_stdout = $stdout

      filtering_stdout = Class.new do
        def initialize(original)
          @original = original
        end

        def write(message)
          return 0 if message.nil? || message.to_s.strip.empty?
          @original.write(message)
        end

        def puts(*messages)
          filtered_messages = messages.reject { |msg| msg.nil? || msg.to_s.strip.empty? }
          return if filtered_messages.empty?
          @original.puts(*filtered_messages)
        end

        def print(*messages)
          filtered_messages = messages.reject { |msg| msg.nil? || msg.to_s.strip.empty? }
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
    end

    def self.apply_filtering_to_rails_logger
      return unless Rails.logger

      if Rails.logger.is_a?(ActiveSupport::BroadcastLogger)
        apply_broadcast_logger_filtering(Rails.logger)
      else
        apply_standard_logger_filtering(Rails.logger)
      end
    end

    def self.apply_broadcast_logger_filtering(broadcast_logger)
      # BroadcastLogger broadcasts to multiple loggers, so we need to filter each one
      broadcast_logger.broadcasts.each do |logger|
        # Override the add method on each broadcast logger
        original_add = logger.method(:add)
        logger.define_singleton_method(:add) do |severity, message = nil, progname = nil, &block|
          return if should_filter_blank_message?(message)
          original_add.call(severity, message, progname, &block)
        end

        # Override write method if it exists
        if logger.respond_to?(:write)
          original_write = logger.method(:write)
          logger.define_singleton_method(:write) do |message|
            return if should_filter_blank_message?(message)
            original_write.call(message)
          end
        end

        # Add the filtering method to each logger
        logger.define_singleton_method(:should_filter_blank_message?) do |message|
          message.nil? || message.to_s.strip.empty?
        end
      end
    end

    def self.apply_standard_logger_filtering(logger)
      # For regular loggers, use the extend approach
      quiet_logger_module = Module.new do
        def add(severity, message = nil, progname = nil)
          return if should_filter_blank_message?(message)
          super
        end

        def write(message)
          return if should_filter_blank_message?(message)
          super
        end

        private

        def should_filter_blank_message?(message)
          message.nil? || message.to_s.strip.empty?
        end
      end

      logger.extend(quiet_logger_module)
    end

    # Helper method for broadcast logger filtering
    def self.should_filter_blank_message?(message)
      message.nil? || message.to_s.strip.empty?
    end
  end
end
