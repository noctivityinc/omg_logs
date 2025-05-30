module OmgLogs
  module LogFiltering
    def self.setup!
      return unless Rails.env.development?

      define_quiet_logger_module
      apply_filtering_to_rails_logger
    end

    private

    def self.define_quiet_logger_module
      Object.const_set(:QuietLogger, Module.new do
        def add(severity, message = nil, progname = nil)
          return if should_filter_message?(message)
          super
        end

        private

        def should_filter_message?(message)
          return false unless message.is_a?(String)

          filter_patterns = OmgLogs.configuration.filter_patterns
          filter_patterns.any? { |pattern| message.match?(pattern) }
        end
      end)
    end

    def self.apply_filtering_to_rails_logger
      Rails.logger.extend(QuietLogger)
    end
  end
end
