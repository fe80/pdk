require 'pdk'
require 'pdk/cli/exec'
require 'pdk/validators/base_validator'
require 'pdk/util/bundler'
require 'pathname'

module PDK
  module Validate
    class Metadata < BaseValidator
      # Validate each metadata file separately, as metadata-json-lint does not
      # support multiple targets.
      INVOKE_STYLE = :per_target

      def self.name
        'metadata'
      end

      def self.cmd
        'metadata-json-lint'
      end

      def self.spinner_text(targets = nil)
        _('Checking metadata (%{targets})') % {
          targets: targets.map { |t| Pathname.new(t).absolute? ? Pathname.new(t).relative_path_from(Pathname.pwd) : t }.join(' '),
        }
      end

      def self.pattern
        'metadata.json'
      end

      def self.parse_options(_options, targets)
        cmd_options = ['--format', 'json']

        cmd_options.concat(targets)
      end

      def self.parse_output(report, result, targets)
        begin
          json_data = JSON.parse(result[:stdout])
        rescue JSON::ParserError
          json_data = []
        end

        raise ArgumentError, 'More that 1 target provided to PDK::Validate::Metadata' if targets.count > 1

        if json_data.empty?
          report.add_event(
            file:     targets.first,
            source:   cmd,
            state:    :passed,
            severity: :ok,
          )
        else
          json_data.delete('result')
          json_data.keys.each do |type|
            json_data[type].each do |offense|
              # metadata-json-lint groups the offenses by type, so the type ends
              # up being `warnings` or `errors`. We want to convert that to the
              # singular noun for the event.
              event_type = type[%r{\A(.+?)s?\Z}, 1]

              report.add_event(
                file:     targets.first,
                source:   cmd,
                message:  offense['msg'],
                test:     offense['check'],
                severity: event_type,
                state:    :failure,
              )
            end
          end
        end
      end
    end
  end
end
