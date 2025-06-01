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

          # Filter out ActionCable/Turbo
          return '' if should_skip_controller?(controller, action)

          format_request_log(data)
        end

        private

        def should_skip_controller?(controller, action)
          skip_patterns = [
            'Turbo::', 'StreamsChannel', 'ActionCable',
            'ApplicationCable', 'Connection'
          ]

          skip_actions = ['subscribe', 'unsubscribe', 'connect']

          skip_patterns.any? { |pattern| controller.include?(pattern) } ||
            skip_actions.any? { |action_name| action.include?(action_name) }
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

          # Main request line
          format_info = data[:format] ? " (#{data[:format]})" : ""
          main_line = "#{data[:method]} #{data[:path]}#{format_info} | #{data[:controller]}##{data[:action]} | #{data[:status]} | #{data[:duration]}ms"
          output << main_line.colorize(status_color)

          # Performance details
          perf_details = []
          perf_details << "View: #{data[:view]}ms" if data[:view]
          perf_details << "DB: #{data[:db]}ms" if data[:db]
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

          # Method calls
          if data[:method_calls] && data[:method_calls].any?
            output << "Methods Called:".colorize(:light_magenta)
            data[:method_calls].each do |call|
              if call.include?('🔄 REDIRECT')
                # Highlight redirects in method calls too
                output << "  #{call}".colorize(:yellow)
              else
                output << "  → #{call}".colorize(:cyan)
              end
            end
          end

          # Rendered templates
          if data[:rendered_templates] && data[:rendered_templates].any?
            output << "Templates Rendered:".colorize(:light_magenta)
            data[:rendered_templates].each do |template|
              output << "  📄 #{template}".colorize(:light_green)
            end
          end

          # Additional info
          extras = []
          extras << "Time: #{data[:time]}" if data[:time]
          extras << "User: #{data[:user_id]}" if data[:user_id]
          extras << "IP: #{data[:remote_ip]}" if data[:remote_ip]
          output << extras.join(" | ").colorize(:light_black) if extras.any?

          output << end_separator.colorize(:light_cyan)

          output.join("\n")
        end


      end
    end

    def self.create_custom_options_proc
      lambda do |event|
        params = event.payload[:params]
        clean_params = params ? params.except('controller', 'action', 'format').presence : nil

        {
          time: Time.current.strftime('%H:%M:%S'),
          format: event.payload[:format],
          params: clean_params,
          user_id: event.payload[:user_id],
          remote_ip: event.payload[:remote_ip],
          method_calls: Thread.current[:method_calls] || [],
          rendered_templates: Thread.current[:rendered_templates] || [],
          redirects: Thread.current[:redirects] || []
        }.compact
      end
    end

    def self.create_ignore_proc
      lambda do |event|
        controller = event.payload[:controller_class] || event.payload[:controller] || ''
        controller_str = controller.to_s

        ignore_patterns = [
          'Turbo::', 'StreamsChannel', 'ActionCable',
          'ApplicationCable', 'Connection'
        ]

        ignore_patterns.any? { |pattern| controller_str.include?(pattern) }
      end
    end
  end
end
