require 'amazing_print'
require 'colorize'

module OmgLogs
  module LogrageConfig
    def self.setup!
      return unless Rails.env.development?

      configure_amazing_print
      configure_lograge
    end

    private

    def self.configure_amazing_print
      AmazingPrint.defaults = {
        indent: 2,
        sort_keys: true,
        color: {
          hash: :blue,
          class: :yellow,
          method: :purple,
          string: :green,
          symbol: :cyan
        }
      }
    end

    def self.configure_lograge
      formatter_class = create_formatter_class
      custom_options_proc = create_custom_options_proc
      ignore_proc = create_ignore_proc

      Rails.application.configure do
        config.lograge.enabled = true
        config.lograge.logger = ActiveSupport::Logger.new(STDOUT)
        config.lograge.base_controller_class = ['ActionController::Base', 'ActionController::API']

        config.lograge.formatter = formatter_class.new
        config.lograge.custom_options = custom_options_proc
        config.lograge.ignore_custom = ignore_proc
      end
    end

    def self.create_formatter_class
      Class.new do
        def call(data)
          controller = data[:controller] || ''
          action = data[:action] || ''

          # Use configured filter patterns instead of hardcoded ones
          return '' if should_skip_based_on_filter_patterns?(controller, action)

          format_request_log(data)
        end

        private

        def should_skip_based_on_filter_patterns?(controller, action)
          # Use the configured filter patterns from OmgLogs.configuration
          filter_patterns = OmgLogs.configuration.filter_patterns || []

          combined_text = "#{controller} #{action}"

          filter_patterns.any? do |pattern|
            case pattern
            when Regexp
              combined_text.match?(pattern)
            when String
              combined_text.include?(pattern)
            else
              false
            end
          end
        end

        def format_request_log(data)
          status_color = case data[:status].to_i
                        when 200..299 then :light_green
                        when 300..399 then :light_yellow
                        when 400..499 then :light_red
                        when 500..599 then :light_magenta
                        else :white
                        end

          separator = "=" * 100
          end_separator = "-" * 100

          output = []
          output << separator.colorize(:light_cyan)

          # Main request line - use total_duration if available, fallback to duration
          duration_to_show = data[:total_duration] || data[:duration]
          formatted_duration = duration_to_show ? "%.2f" % duration_to_show : "0.00"
          format_info = data[:format] ? " (#{data[:format]})" : ""

          # For Turbo::StreamsChannel, extract and show the stream name
          stream_info = extract_stream_info(data)

          main_line = "#{data[:method]} #{data[:path]}#{format_info} | #{data[:controller]}##{data[:action]}#{stream_info} | #{data[:status]} | #{formatted_duration}ms (TOTAL)"
          output << main_line.colorize(status_color)

          # Performance details - show breakdown
          perf_details = []
          perf_details << "Controller: #{'%.2f' % data[:duration]}ms" if data[:duration] # Original controller time
          perf_details << "View: #{'%.2f' % data[:view]}ms" if data[:view]
          perf_details << "DB: #{'%.2f' % data[:db]}ms" if data[:db]
          perf_details << "Allocations: #{data[:allocations]}" if data[:allocations]
          output << perf_details.join(" | ").colorize(:light_blue) if perf_details.any?

          # Parameters
          if data[:params] && !data[:params].empty?
            output << "Params:".colorize(:light_yellow)
            if data[:params].to_s.length > 150
              output << data[:params].ai(plain: false, indent: 4)
            else
              output << "  #{data[:params]}".colorize(:white)
            end
          end

          # Redirects - Display prominently if any occurred
          if data[:redirects] && data[:redirects].any?
            output << "Redirects:".colorize(:light_magenta)
            data[:redirects].each do |redirect|
              timestamp = redirect[:timestamp] ? redirect[:timestamp].strftime('%H:%M:%S.%L') : 'unknown'
              status_info = redirect[:status] ? " (#{redirect[:status]})" : ""
              redirect_line = "  🔄 #{timestamp} - #{redirect[:called_from]} → #{redirect[:method]} → #{redirect[:destination]}#{status_info}"
              output << redirect_line.colorize(:yellow)
            end
          end

          # Before Actions (if any were called)
          if data[:before_actions_called] && data[:before_actions_called].any?
            if OmgLogs.configuration.debug_mode
              puts "🔍 [DEBUG] data[:before_actions_called]: #{data[:before_actions_called]}"
            end
            output << "Before Actions:".colorize(:light_cyan)
            data[:before_actions_called].each do |action|
              output << "  → #{action}".colorize(:cyan)
            end
          end

          # Method calls
          if data[:method_calls] && data[:method_calls].any?
            output << "Methods Called:".colorize(:light_magenta)
            data[:method_calls].each do |call|
              if call.include?('🔄 REDIRECT')
                # Highlight redirects in method calls too
                output << "  #{call}".colorize(:yellow)
              else
                output << "  #{call}".colorize(:cyan)
              end
            end
          end

          # Rendered templates (reverse order to show actual rendering sequence)
          if data[:rendered_templates] && data[:rendered_templates].any?
            output << "Templates Rendered:".colorize(:light_magenta)
            data[:rendered_templates].reverse.each do |template|
              output << "  📄 #{template}".colorize(:light_green)
            end
          end

          # Additional info
          extras = []
          extras << "Time: #{data[:time]}" if data[:time]
          if data[:current_user_info]
            user_label = data[:current_user_info][:label] || 'User'
            user_id = data[:current_user_info][:id]
            extras << "#{user_label}: #{user_id}" if user_id
          end
          extras << "IP: #{data[:remote_ip]}" if data[:remote_ip]
          output << extras.join(" | ").colorize(:light_black) if extras.any?

          output << end_separator.colorize(:light_cyan)

          output.join("\n")
        end

        # Extract stream information for ActionCable/Turbo channels
        def extract_stream_info(data)
          return "" unless data[:controller]&.include?('StreamsChannel')

          # Look for stream name in params
          if data[:params]
            if data[:params]['signed_stream_name']
              # Decode the signed stream name to show what stream this is
              begin
                decoded = Rails.application.message_verifier(:signed_stream_name).verify(data[:params]['signed_stream_name'])
                return " [Stream: #{decoded.colorize(:light_cyan)}]"
              rescue StandardError
                return " [Stream: #{data[:params]['signed_stream_name'][0..20]}...]"
              end
            elsif data[:params]['stream_name']
              return " [Stream: #{data[:params]['stream_name'].colorize(:light_cyan)}]"
            elsif data[:params]['channel']
              return " [Channel: #{data[:params]['channel'].colorize(:light_cyan)}]"
            end
          end

          ""
        end
      end
    end

    def self.create_custom_options_proc
      lambda do |event|
        params = event.payload[:params]

        # For ActionCable channels, preserve the stream-related params
        if event.payload[:controller]&.include?('StreamsChannel')
          clean_params = params ? params.except('controller', 'action', 'format').presence : nil
        else
          clean_params = params ? params.except('controller', 'action', 'format').presence : nil
        end

        # Calculate total duration (controller + view + any other processing)
        total_duration = event.duration

        # Get current user info using configured method
        current_user_info = extract_current_user_info(event.payload[:request])

        # Get data from request env (stored there before Thread cleanup)
        request_env = event.payload[:request]&.env || {}
        before_actions = request_env['omg_logs.before_actions_called'] || Thread.current[:before_actions_called] || []
        method_calls = request_env['omg_logs.method_calls'] || Thread.current[:method_calls] || []
        redirects = request_env['omg_logs.redirects'] || Thread.current[:redirects] || []

        if OmgLogs.configuration.debug_mode
          puts "🔍 [DEBUG] custom_options_proc - before_actions: #{before_actions}"
          puts "🔍 [DEBUG] custom_options_proc - method_calls: #{method_calls}"
          puts "🔍 [DEBUG] total_duration: #{total_duration}ms"
          puts "🔍 [DEBUG] current_user_info: #{current_user_info}"
        end

        {
          time: Time.current.strftime('%H:%M:%S'),
          format: event.payload[:format],
          params: clean_params,
          current_user_info: current_user_info,
          remote_ip: event.payload[:remote_ip],
          before_actions_called: before_actions,
          method_calls: method_calls,
          rendered_templates: Thread.current[:rendered_templates] || [],
          redirects: redirects,
          total_duration: total_duration
        }.compact
      end
    end

    def self.extract_current_user_info(request)
      return nil unless OmgLogs.configuration.current_user_method
      return nil unless request

      begin
        # Try to get the controller instance from the request
        controller = request.env['action_controller.instance']
        return nil unless controller

        # Split the method path (e.g., "Current.professional" -> ["Current", "professional"])
        method_path = OmgLogs.configuration.current_user_method.split('.')

        current_object = nil

        # Handle different starting points
        case method_path.first
        when 'Current'
          # For Current.professional, Current.account, etc.
          current_object = Current if defined?(Current)
        when 'current_user'
          # For current_user.account, etc.
          current_object = controller.current_user if controller.respond_to?(:current_user)
        else
          # Direct method call on controller (e.g., "current_professional")
          if method_path.length == 1 && controller.respond_to?(method_path.first)
            user_object = controller.send(method_path.first)
            return {
              id: user_object&.id,
              label: OmgLogs.configuration.current_user_label || 'User'
            }
          end
        end

        return nil unless current_object

        # Navigate through the method path
        method_path[1..-1].each do |method_name|
          break unless current_object.respond_to?(method_name)
          current_object = current_object.send(method_name)
          break if current_object.nil?
        end

        if current_object&.respond_to?(:id)
          {
            id: current_object.id,
            label: OmgLogs.configuration.current_user_label || 'User'
          }
        end
      rescue StandardError => e
        if OmgLogs.configuration.debug_mode
          puts "🔍 [DEBUG] Failed to extract current user: #{e.message}"
        end
        nil
      end
    end

    def self.create_ignore_proc
      lambda do |event|
        controller = event.payload[:controller_class] || event.payload[:controller] || ''
        controller_str = controller.to_s
        action = event.payload[:action] || ''

        # Use configured filter patterns instead of hardcoded ones
        filter_patterns = OmgLogs.configuration.filter_patterns || []

        combined_text = "#{controller_str} #{action}"

        filter_patterns.any? do |pattern|
          case pattern
          when Regexp
            combined_text.match?(pattern)
          when String
            combined_text.include?(pattern)
          else
            false
          end
        end
      end
    end
  end
end
